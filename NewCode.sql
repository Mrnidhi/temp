/* ============================================================================
   Diagnosed & Treated Patients - ATC vs Non-ATC Split

   Business question:
       For metastatic melanoma patients diagnosed and treated with Yervoy or
       Opdualag from 2021 to 2025, what share were treated at an Authorized
       Treatment Center versus a non-ATC site of care?

   Outputs:

   BASE TABLES
       ATC_CLASSIFIED_FINAL    one row per patient, hybrid classification
       ATC_PATIENT_HCO_YEAR    patient x HCO x year (trend, overlap)
       ATC_TREATMENT_CLAIMS    claim level with dates and drug (journey, timing)
       STATE_REGION_MAP        state to region lookup (6 regions)

   DECK ALIGNMENT (ATC Network vs Non-ATC Site of Care Analysis, 9-slide deck,
   corrected July 2026). Each slide and the query that feeds it:

       Slide 2  Methodology            Steps 1 to 4 (the classification logic)
       Slide 3  Market structure       Insight 1  (headline), Insight 2 (confidence)
       Slide 4  Patient journey        Insight 8  (first vs last), Insight 9 (persistence)
       Slide 5  Regional penetration   Insight 10 (by region)
       Slide 6  State scatter          Insight 10b (by state)      <- added for the deck
       Slide 7  Non-ATC by region      Insight 5  (by account) + region
       Slide 8  Non-ATC by state       Insight 5b (by state)       <- added for the deck
       Slide 9  Appendix               Insight 3 (year trend), 9 (claims intensity),
                                       11 (dx-to-tx timing), 6a/6b (sample journeys)

   The four-organisation roster gap correction (City of Hope, NYU Langone, Ohio
   State Wexner, Hoag; +566 patients, 42.7% -> 46.2%) is applied in Steps 1, 2 AND
   3 as of 2026-07-17. Before that Step 3 was NPI-only, so Slide 4 sat on the old
   definition while Slide 3 showed the corrected one. Re-run Slide 4 after this.

   INSIGHTS (grouped by slide above; listed here in build order)
       1   Headline split (ATC vs Non-ATC)                      -> Slide 3
       2   Classification confidence                            -> Slide 3
       3   ATC share by treatment year                          -> Slide 9
       4   ATC-assigned patients with non-ATC activity          context
       5   Leakage concentration by account                     -> Slide 7
      5b   Leakage concentration by state                       -> Slide 8
      6a   Migration cohort: start non-ATC, classified ATC      -> Slide 9
      6b   Time spent in each setting (migration cohort)        -> Slide 9
       7   Community network share of leakage                   context
       8   Patient journey (first vs last treatment site)       -> Slide 4
       9   Treatment persistence by starting site               -> Slide 4
      10   Regional ATC penetration                             -> Slide 5
     10b   State ATC penetration and untapped volume            -> Slide 6
      11   Time from diagnosis to first treatment               -> Slide 9
      12   Drug mix (Yervoy vs Opdualag)                        context
      13   ATC performance profile                              context
   ============================================================================ */


-- Controls how many states an ATC parent can span before we treat it as a
-- broad hospital system rather than a single authorized center. 2 is current.
SET fallback_state_limit = 2;


-- Step 1: classify every patient as ATC or non-ATC. One row per patient.
CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL AS
WITH auth_npi AS (
    SELECT DISTINCT TRIM("NPI") AS NPI
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status")) = 'AUTHORIZED'
      AND "NPI" IS NOT NULL
      AND TRIM("NPI") NOT IN ('0', '', 'NPI')
),
auth_parent AS (
    SELECT DISTINCT UPPER(TRIM("ATC HCO Parent Name (McKesson Claims)")) AS PARENT
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status")) = 'AUTHORIZED'
      AND "ATC HCO Parent Name (McKesson Claims)" IS NOT NULL
      AND TRIM("ATC HCO Parent Name (McKesson Claims)") NOT IN ('', 'null')
),
classified AS (
    SELECT
        p.*,
        CASE
            WHEN p.HCO_COMMUNITY_NETWORK IN (
                    'THE US ONCOLOGY NETWORK',
                    'ONE ONCOLOGY',
                    'AMERICAN ONCOLOGY NETWORK')
                THEN 'Non-ATC: Community Network'
            WHEN n.NPI IS NOT NULL
                THEN 'ATC: NPI confirmed'
            -- Roster gap correction (2026-07-16, matching reworked 07-16).
            -- CTAM_ATC_ALIGNMENT_2026 is missing these four organisations, so their
            -- patients were scored Non-ATC. Each was confirmed against Infinity's
            -- authoritative ATC master (file_Veeva_Komodo_ATC_Mapping, 93 accounts):
            -- City of Hope = Duarte and Chicago, NYU Langone = Perlmutter,
            -- Ohio State = Wexner, Hoag = Hoag Memorial in Newport Beach.
            --   Effect: +566 patients move to ATC. 6,935 to 7,501, i.e. 42.7% to 46.2%.
            -- Matched on a pattern, NOT an exact string. The first version of this
            -- joined hardcoded literals against UPPER(TRIM(HCO_PARENT_NAME)); any
            -- suffix or stray space made the join return NULL, the branch never
            -- fired, and nothing errored. Pattern matching removes that failure mode
            -- and picks up the satellites at the same time.
            -- These bypass the fallback_state_limit guard below on purpose: they are
            -- confirmed authorized, not inferred from a fuzzy name match.
            -- THESE FOUR PATTERNS ALSO APPEAR IN STEPS 2 AND 3. Keep all three in
            -- sync, and delete all three once the source roster carries these four.
            -- DELIBERATELY EXCLUDED: Kaiser, Providence, Mayo, Intermountain, Avera,
            -- Northwell, AdventHealth, Advocate, St Luke's, Baylor (449 patients). All
            -- are multi-site systems where only ONE site is authorized (e.g. Kaiser
            -- Vallejo, Providence Portland), so promoting the whole parent would
            -- overstate ATC.
            WHEN UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%CITY OF HOPE%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%NYU LANGONE%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%WEXNER%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%HOAG%'
                THEN 'ATC: roster gap corrected'
            WHEN ap.PARENT IS NOT NULL
                THEN 'ATC: name fallback'
            WHEN EXISTS (
                    SELECT 1 FROM auth_parent x
                    WHERE UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%' || x.PARENT || '%'
                       OR x.PARENT LIKE '%' || UPPER(TRIM(p.HCO_PARENT_NAME)) || '%')
                THEN 'Needs Review'
            WHEN p.HCO_PARENT_NAME IS NULL
                THEN 'Non-ATC: Unknown'
            ELSE 'Non-ATC'
        END AS CLASS_HYBRID
    FROM COMPILE_DEV.PUBLIC.ATC_SOC_PATIENT_CLASSIFIED_2021_2025 p
    LEFT JOIN auth_npi    n  ON TRIM(p.D_PRIMARY_HCO_NPI) = n.NPI
    LEFT JOIN auth_parent ap ON UPPER(TRIM(p.HCO_PARENT_NAME)) = ap.PARENT
),
fallback_footprint AS (
    SELECT HCO_PARENT_NAME,
           COUNT(DISTINCT PRIMARY_HCO_NPI_STATE) AS PARENT_STATES
    FROM classified
    WHERE CLASS_HYBRID = 'ATC: name fallback'
    GROUP BY 1
)
SELECT
    c.*,
    f.PARENT_STATES,
    CASE
        WHEN c.CLASS_HYBRID = 'ATC: NPI confirmed'                                              THEN 'ATC'
        WHEN c.CLASS_HYBRID = 'ATC: roster gap corrected'                                       THEN 'ATC'
        WHEN c.CLASS_HYBRID = 'ATC: name fallback' AND f.PARENT_STATES <= $fallback_state_limit THEN 'ATC'
        WHEN c.CLASS_HYBRID = 'ATC: name fallback' AND f.PARENT_STATES >  $fallback_state_limit THEN 'Non-ATC: System sweep'
        WHEN c.CLASS_HYBRID = 'Needs Review'                                                    THEN 'Needs Review'
        ELSE c.CLASS_HYBRID
    END AS CLASS_FINAL
FROM classified c
LEFT JOIN fallback_footprint f
    ON c.HCO_PARENT_NAME = f.HCO_PARENT_NAME;


-- Step 2: one row per patient, site and year. Used for the trend and overlap views.
CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_PATIENT_HCO_YEAR AS
WITH auth_npi AS (
    SELECT DISTINCT TRIM("NPI") AS NPI
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status")) = 'AUTHORIZED'
      AND "NPI" IS NOT NULL
      AND TRIM("NPI") NOT IN ('0', '', 'NPI')
),
diagnosed AS (
    SELECT DISTINCT D_PATIENT_ID
    FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
    WHERE D_PATIENT_ID <> 'XXX - HIDDEN'
      AND DATE_OF_SERVICE >= DATE '2021-01-01'
      AND D_DIAGNOSIS_CODE_ALL ILIKE '%C43%'
      AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%C77%', '%C78%', '%C79%')
),
treated AS (
    SELECT
        D_PATIENT_ID,
        D_PRIMARY_HCO_NPI,
        D_PRIMARY_HCO_COMPILE_ID,
        HCO_PARENT_NAME,
        YEAR(DATE_OF_SERVICE) AS TX_YEAR
    FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
    WHERE D_PATIENT_ID <> 'XXX - HIDDEN'
      AND DATE_OF_SERVICE >= DATE '2021-01-01'
      AND DATE_OF_SERVICE <  DATE '2026-01-01'
      AND (D_NDC_CODE IN ('00003232711', '00003232822', '00003712511')
           OR D_PROCEDURE_CODE IN ('J9228', 'J9298'))
)
SELECT
    t.D_PATIENT_ID,
    t.TX_YEAR,
    t.D_PRIMARY_HCO_COMPILE_ID,
    -- Roster gap correction. Keep in sync with the patterns in Steps 1 and 3.
    -- Before 2026-07-16 this was the NPI match alone, so the year trend silently
    -- ignored the four missing organisations no matter how often Step 1 was
    -- rebuilt. This step never reads ATC_CLASSIFIED_FINAL, it classifies its own.
    MAX(CASE
            WHEN n.NPI IS NOT NULL THEN 1
            WHEN UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%CITY OF HOPE%'
              OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%NYU LANGONE%'
              OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%WEXNER%'
              OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%HOAG%' THEN 1
            ELSE 0
        END) AS IS_ATC_HCO,
    COUNT(*) AS CLAIMS
FROM treated t
INNER JOIN diagnosed d ON t.D_PATIENT_ID = d.D_PATIENT_ID
LEFT JOIN auth_npi   n ON TRIM(t.D_PRIMARY_HCO_NPI) = n.NPI
GROUP BY 1, 2, 3;


-- Step 3: one row per treatment claim, with dates and drug.
-- Used for the journey and timing views. Drug is read from procedure and NDC codes.
CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS AS
WITH auth_npi AS (
    SELECT DISTINCT TRIM("NPI") AS NPI
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status")) = 'AUTHORIZED'
      AND "NPI" IS NOT NULL
      AND TRIM("NPI") NOT IN ('0', '', 'NPI')
),
diagnosed AS (
    SELECT D_PATIENT_ID, MIN(DATE_OF_SERVICE) AS FIRST_DX_DATE
    FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
    WHERE D_PATIENT_ID <> 'XXX - HIDDEN'
      AND DATE_OF_SERVICE >= DATE '2021-01-01'
      AND D_DIAGNOSIS_CODE_ALL ILIKE '%C43%'
      AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%C77%', '%C78%', '%C79%')
    GROUP BY 1
),
treated AS (
    SELECT
        D_PATIENT_ID,
        DATE_OF_SERVICE,
        D_PRIMARY_HCO_NPI,
        D_PRIMARY_HCO_COMPILE_ID,
        HCO_PARENT_NAME,
        CASE
            WHEN D_PROCEDURE_CODE = 'J9228'
                 OR D_NDC_CODE IN ('00003232711', '00003232822') THEN 'Yervoy'
            WHEN D_PROCEDURE_CODE = 'J9298'
                 OR D_NDC_CODE = '00003712511'                    THEN 'Opdualag'
            ELSE 'Other'
        END AS DRUG
    FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
    WHERE D_PATIENT_ID <> 'XXX - HIDDEN'
      AND DATE_OF_SERVICE >= DATE '2021-01-01'
      AND DATE_OF_SERVICE <  DATE '2026-01-01'
      AND (D_NDC_CODE IN ('00003232711', '00003232822', '00003712511')
           OR D_PROCEDURE_CODE IN ('J9228', 'J9298'))
)
SELECT
    t.D_PATIENT_ID,
    t.DATE_OF_SERVICE,
    t.D_PRIMARY_HCO_COMPILE_ID,
    t.HCO_PARENT_NAME,
    t.DRUG,
    d.FIRST_DX_DATE,
    -- Roster gap correction. Keep in sync with the patterns in Steps 1 and 2.
    -- Before 2026-07-17 this was the NPI match alone, so the journey, persistence,
    -- timing and drug-mix views (Insights 8, 9, 11, 12 -> Slides 4 and 9) scored
    -- City of Hope, NYU Langone, Ohio State Wexner and Hoag patients as Non-ATC.
    -- That is why Slide 4 disagreed with the corrected headline on Slide 3. Adding
    -- the four patterns here reconciles the journey with the 46.2% headline.
    CASE
        WHEN n.NPI IS NOT NULL THEN 1
        WHEN UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%CITY OF HOPE%'
          OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%NYU LANGONE%'
          OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%WEXNER%'
          OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%HOAG%' THEN 1
        ELSE 0
    END AS IS_ATC_HCO
FROM treated t
INNER JOIN diagnosed d ON t.D_PATIENT_ID = d.D_PATIENT_ID
LEFT JOIN auth_npi n ON TRIM(t.D_PRIMARY_HCO_NPI) = n.NPI;


-- Step 4: state to region lookup. Six regions. VA, MD, DC, DE sit in Northeast.
-- Hawaii and Alaska are left unmapped on purpose.
CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.STATE_REGION_MAP AS
SELECT * FROM VALUES
    ('CA','West'),('WA','West'),('OR','West'),('NV','West'),('AZ','West'),
    ('UT','West'),('CO','West'),('ID','West'),('MT','West'),('WY','West'),
    ('NM','West'),
    ('TX','Central'),('OK','Central'),('KS','Central'),('NE','Central'),
    ('SD','Central'),('ND','Central'),('AR','Central'),
    ('IL','Great Lakes'),('MI','Great Lakes'),('WI','Great Lakes'),
    ('MN','Great Lakes'),('IA','Great Lakes'),('MO','Great Lakes'),
    ('OH','Ohio Valley'),('IN','Ohio Valley'),('KY','Ohio Valley'),
    ('TN','Ohio Valley'),('WV','Ohio Valley'),
    ('FL','Southeast'),('GA','Southeast'),('SC','Southeast'),
    ('NC','Southeast'),('AL','Southeast'),('MS','Southeast'),('LA','Southeast'),
    ('NY','Northeast'),('NJ','Northeast'),('PA','Northeast'),
    ('MA','Northeast'),('CT','Northeast'),('RI','Northeast'),
    ('NH','Northeast'),('ME','Northeast'),('VT','Northeast'),
    ('VA','Northeast'),('MD','Northeast'),('DC','Northeast'),('DE','Northeast')
AS T(STATE, REGION);


-- Insight 8 (Slide 4): where each patient started treatment versus where they ended.
-- The four cells are the Slide 4 quadrants: started/ended x ATC/non-ATC.
WITH ranked AS (
    SELECT
        D_PATIENT_ID,
        IS_ATC_HCO,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE ASC,  D_PRIMARY_HCO_COMPILE_ID) AS RN_FIRST,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE DESC, D_PRIMARY_HCO_COMPILE_ID) AS RN_LAST
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
first_last AS (
    SELECT
        D_PATIENT_ID,
        MAX(CASE WHEN RN_FIRST = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
        MAX(CASE WHEN RN_LAST  = 1 THEN IS_ATC_HCO END) AS LAST_ATC
    FROM ranked
    GROUP BY 1
)
SELECT
    CASE WHEN FIRST_ATC = 1 THEN 'ATC' ELSE 'Non-ATC' END AS FIRST_SITE,
    CASE WHEN LAST_ATC  = 1 THEN 'ATC' ELSE 'Non-ATC' END AS LAST_SITE,
    COUNT(*) AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM first_last
GROUP BY 1, 2
ORDER BY 3 DESC;


-- Insight 9 (Slide 4, Slide 9): how much treatment patients get, split by where they
-- started. AVG_TREATMENT_CLAIMS is the "6.7 vs 6.0 claims per patient" line.
WITH ranked AS (
    SELECT
        D_PATIENT_ID,
        IS_ATC_HCO,
        DATE_OF_SERVICE,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE, D_PRIMARY_HCO_COMPILE_ID) AS RN
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
pt AS (
    SELECT
        D_PATIENT_ID,
        MAX(CASE WHEN RN = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
        COUNT(*) AS TREATMENT_CLAIMS,
        DATEDIFF('day', MIN(DATE_OF_SERVICE), MAX(DATE_OF_SERVICE)) AS TX_SPAN_DAYS
    FROM ranked
    GROUP BY 1
)
SELECT
    CASE WHEN FIRST_ATC = 1 THEN 'Started at ATC' ELSE 'Started at Non-ATC' END AS FIRST_SITE,
    COUNT(*) AS PATIENTS,
    ROUND(AVG(TREATMENT_CLAIMS), 1) AS AVG_TREATMENT_CLAIMS,
    ROUND(AVG(TX_SPAN_DAYS), 0)     AS AVG_TX_SPAN_DAYS
FROM pt
GROUP BY 1
ORDER BY 2 DESC;



-- Insight 6b (Slide 9, sample journeys): referral source with the ATC parent they moved to.
-- If STARTING_PARENT and MIGRATED_PARENT match, it is the same system (artifact).
-- If they differ, it is a real move from one system into an ATC.


WITH first_claim AS (
    SELECT
        D_PATIENT_ID,
        HCO_PARENT_NAME AS STARTING_PARENT,
        IS_ATC_HCO      AS STARTED_ATC
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    QUALIFY ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                               ORDER BY DATE_OF_SERVICE, D_PRIMARY_HCO_COMPILE_ID) = 1
),
last_atc AS (
    SELECT
        D_PATIENT_ID,
        HCO_PARENT_NAME AS MIGRATED_PARENT
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    WHERE IS_ATC_HCO = 1
    QUALIFY ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                               ORDER BY DATE_OF_SERVICE DESC, D_PRIMARY_HCO_COMPILE_ID) = 1
),
starters AS (
    SELECT
        COALESCE(fc.STARTING_PARENT, 'Unknown') AS STARTING_PARENT,
        COALESCE(la.MIGRATED_PARENT, 'Unknown') AS MIGRATED_PARENT,
        CASE WHEN c.CLASS_FINAL = 'ATC' THEN 1 ELSE 0 END AS MIGRATED
    FROM first_claim fc
    INNER JOIN COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL c
        ON fc.D_PATIENT_ID = c.D_PATIENT_ID
    LEFT JOIN last_atc la
        ON fc.D_PATIENT_ID = la.D_PATIENT_ID
    WHERE fc.STARTED_ATC = 0
      AND c.CLASS_FINAL = 'ATC'
)
SELECT
    STARTING_PARENT,
    MIGRATED_PARENT,
    COUNT(*) AS PATIENTS,
    CASE WHEN UPPER(TRIM(STARTING_PARENT)) = UPPER(TRIM(MIGRATED_PARENT))
         THEN 'Same system (artifact)'
         ELSE 'Different system (real move)' END AS MOVE_TYPE
FROM starters
GROUP BY 1, 2
ORDER BY PATIENTS DESC
LIMIT 30;

-- Insight 1 (Slide 3): the headline. Share of patients treated at ATC versus non-ATC.
-- Second query is the two-way ATC vs Non-ATC roll-up (the 46.2% headline number).
SELECT
    CLASS_FINAL,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;

SELECT
    CASE WHEN CLASS_FINAL = 'ATC' THEN 'ATC' ELSE 'Non-ATC' END AS SITE_GROUP,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;


-- Insight 2 (Slide 3): how the ATC count is built, by match type. Shows how confident we are.
SELECT
    CLASS_HYBRID,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;


-- Insight 3 (Slide 9): ATC share for each year, to see the trend over time.
-- This is the "19% to 24%, 2021 to 2025" year-over-year line.
SELECT
    TX_YEAR,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS_TREATED,
    COUNT(DISTINCT CASE WHEN IS_ATC_HCO = 1 THEN D_PATIENT_ID END) AS ATC_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN IS_ATC_HCO = 1 THEN D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT D_PATIENT_ID), 0), 1) AS PCT_ATC
FROM COMPILE_DEV.PUBLIC.ATC_PATIENT_HCO_YEAR
GROUP BY 1
ORDER BY 1;


-- Insight 4: ATC patients who also have some non-ATC treatment activity.
WITH pt AS (
    SELECT
        D_PATIENT_ID,
        MAX(IS_ATC_HCO)                                  AS HAS_ATC,
        MAX(CASE WHEN IS_ATC_HCO = 0 THEN 1 ELSE 0 END)  AS HAS_NON_ATC,
        SUM(CASE WHEN IS_ATC_HCO = 0 THEN CLAIMS ELSE 0 END) AS NON_ATC_CLAIMS
    FROM COMPILE_DEV.PUBLIC.ATC_PATIENT_HCO_YEAR
    GROUP BY 1
)
SELECT
    CASE WHEN HAS_NON_ATC = 1 THEN 'ATC + non-ATC activity'
         ELSE 'ATC only' END AS PATTERN,
    COUNT(*) AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT_OF_ATC,
    SUM(NON_ATC_CLAIMS) AS NON_ATC_CLAIMS
FROM pt
WHERE HAS_ATC = 1
GROUP BY 1
ORDER BY 2 DESC;


-- Insight 5 (Slide 7): which non-ATC accounts hold the most patients, and how concentrated it is.
WITH leak AS (
    SELECT
        HCO_PARENT_NAME,
        COUNT(DISTINCT D_PATIENT_ID)             AS PATIENTS,
        COUNT(DISTINCT D_PRIMARY_HCO_COMPILE_ID) AS DISTINCT_HCOS,
        SUM(TREATMENT_CLAIMS)                    AS TOTAL_CLAIMS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_FINAL LIKE 'Non-ATC%'
    GROUP BY 1
)
SELECT
    HCO_PARENT_NAME,
    PATIENTS,
    DISTINCT_HCOS,
    TOTAL_CLAIMS,
    RANK() OVER (ORDER BY PATIENTS DESC) AS LEAK_RANK,
    ROUND(100.0 * PATIENTS / SUM(PATIENTS) OVER (), 1) AS PCT_OF_LEAKAGE,
    ROUND(100.0 * SUM(PATIENTS) OVER (ORDER BY PATIENTS DESC
                                      ROWS UNBOUNDED PRECEDING)
          / SUM(PATIENTS) OVER (), 1) AS CUM_PCT_OF_LEAKAGE
FROM leak
ORDER BY PATIENTS DESC
LIMIT 25;


-- Insight 5b (Slide 8): largest non-ATC accounts within each state.
-- Same leakage logic as Insight 5, grouped to state x parent and ranked within
-- each state. The deck shows the six states with the most non-ATC volume, top
-- three accounts each; STATE_NON_ATC_PATIENTS gives the order to pick those six.
WITH state_leak AS (
    SELECT
        PRIMARY_HCO_NPI_STATE AS STATE,
        HCO_PARENT_NAME,
        COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_FINAL LIKE 'Non-ATC%'
      AND PRIMARY_HCO_NPI_STATE IS NOT NULL
    GROUP BY 1, 2
),
ranked AS (
    SELECT
        STATE,
        HCO_PARENT_NAME,
        PATIENTS,
        RANK() OVER (PARTITION BY STATE ORDER BY PATIENTS DESC) AS RANK_IN_STATE,
        SUM(PATIENTS) OVER (PARTITION BY STATE)                 AS STATE_NON_ATC_PATIENTS
    FROM state_leak
)
SELECT
    STATE,
    STATE_NON_ATC_PATIENTS,
    HCO_PARENT_NAME,
    PATIENTS,
    RANK_IN_STATE
FROM ranked
WHERE RANK_IN_STATE <= 3
ORDER BY STATE_NON_ATC_PATIENTS DESC, RANK_IN_STATE;


-- Insight 7: how much non-ATC volume sits inside the large community networks.
SELECT
    COALESCE(HCO_COMMUNITY_NETWORK, 'Independent / Other') AS NETWORK,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT_OF_LEAKAGE
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL LIKE 'Non-ATC%'
GROUP BY 1
ORDER BY 2 DESC;


-- Insight 10 (Slide 5): ATC share by region.
-- ATC_PATIENTS is "Treated in ATC Network", NON_ATC_PATIENTS is "Untapped".
SELECT
    COALESCE(r.REGION, 'Unmapped') AS REGION,
    COUNT(DISTINCT a.D_PATIENT_ID) AS TOTAL_PATIENTS,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC' THEN a.D_PATIENT_ID END) AS ATC_PATIENTS,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL <> 'ATC' THEN a.D_PATIENT_ID END) AS NON_ATC_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC' THEN a.D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT a.D_PATIENT_ID), 0), 1) AS PCT_ATC
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
    ON a.PRIMARY_HCO_NPI_STATE = r.STATE
GROUP BY 1
ORDER BY TOTAL_PATIENTS DESC;


-- Insight 10b (Slide 6): ATC penetration and untapped volume by state.
-- State-grain version of Insight 10, feeding the scatter: x = PCT_ATC,
-- y = UNTAPPED_PATIENTS. Priority zone on the slide is high untapped, low PCT_ATC.
-- HAVING >= 50 drops the long tail of tiny states so the plot stays readable;
-- it is a display threshold, not a business rule.
SELECT
    a.PRIMARY_HCO_NPI_STATE AS STATE,
    COUNT(DISTINCT a.D_PATIENT_ID) AS TOTAL_PATIENTS,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL =  'ATC' THEN a.D_PATIENT_ID END) AS ATC_PATIENTS,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL <> 'ATC' THEN a.D_PATIENT_ID END) AS UNTAPPED_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC' THEN a.D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT a.D_PATIENT_ID), 0), 1) AS PCT_ATC
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
WHERE a.PRIMARY_HCO_NPI_STATE IS NOT NULL
GROUP BY 1
HAVING COUNT(DISTINCT a.D_PATIENT_ID) >= 50
ORDER BY UNTAPPED_PATIENTS DESC;


-- Insight 11 (Slide 9): days from diagnosis to first treatment. Context only, the gap is small.
-- This is the "about a 40-day median, similar across both settings" appendix line.
WITH first_tx AS (
    SELECT
        D_PATIENT_ID,
        IS_ATC_HCO,
        DATEDIFF('day', FIRST_DX_DATE, DATE_OF_SERVICE) AS DAYS_DX_TO_TX,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE, D_PRIMARY_HCO_COMPILE_ID) AS RN
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
)
SELECT
    CASE WHEN IS_ATC_HCO = 1 THEN 'ATC' ELSE 'Non-ATC' END AS FIRST_SITE,
    COUNT(*) AS PATIENTS,
    ROUND(AVG(DAYS_DX_TO_TX), 0)    AS AVG_DAYS_DX_TO_TX,
    ROUND(MEDIAN(DAYS_DX_TO_TX), 0) AS MEDIAN_DAYS_DX_TO_TX
FROM first_tx
WHERE RN = 1
  AND DAYS_DX_TO_TX >= 0
GROUP BY 1
ORDER BY 2 DESC;


-- Insight 12: Yervoy versus Opdualag, and the ATC share of each.
SELECT
    DRUG,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    COUNT(DISTINCT CASE WHEN IS_ATC_HCO = 1 THEN D_PATIENT_ID END) AS ATC_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN IS_ATC_HCO = 1 THEN D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT D_PATIENT_ID), 0), 1) AS PCT_ATC
FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
WHERE DRUG <> 'Other'
GROUP BY 1
ORDER BY 2 DESC;


-- Insight 13: ATC centers ranked by claims per patient, minimum 10 patients.
SELECT
    PRIMARY_HCO_NPI_NAME AS ACCOUNT_NAME,
    HCO_PARENT_NAME,
    PRIMARY_HCO_NPI_STATE AS STATE,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    SUM(TREATMENT_CLAIMS)        AS TOTAL_CLAIMS,
    ROUND(1.0 * SUM(TREATMENT_CLAIMS) / NULLIF(COUNT(DISTINCT D_PATIENT_ID), 0), 1)
        AS CLAIMS_PER_PATIENT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1, 2, 3
HAVING COUNT(DISTINCT D_PATIENT_ID) >= 10
ORDER BY CLAIMS_PER_PATIENT DESC;


-- Reference list: authorized ATC accounts rolled up to parent.
SELECT
    HCO_PARENT_NAME,
    COUNT(DISTINCT D_PATIENT_ID)             AS PATIENTS,
    COUNT(DISTINCT D_PRIMARY_HCO_COMPILE_ID) AS DISTINCT_HCOS,
    COUNT(DISTINCT PRIMARY_HCO_NPI_STATE)    AS STATES,
    SUM(TREATMENT_CLAIMS)                    AS TOTAL_CLAIMS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1
ORDER BY PATIENTS DESC;

-- Reference list: authorized ATC accounts at the individual site level.
SELECT
    PRIMARY_HCO_NPI_NAME AS ACCOUNT_NAME,
    HCO_PARENT_NAME,
    PRIMARY_HCO_NPI_STATE AS STATE,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    SUM(TREATMENT_CLAIMS)        AS TOTAL_CLAIMS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1, 2, 3
ORDER BY PATIENTS DESC;
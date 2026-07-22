/* ============================================================================
   ATC Network vs Non-ATC Site of Care Analysis - Metastatic Melanoma
   MASTER FILE: one-shot rebuild plus every slide output, corrected roster.

   HOW TO RUN
       Paste the whole file, press Run All, then screenshot each result grid in
       order. Part A rebuilds the four base tables; Parts B and C only read them,
       so a single top-to-bottom run is enough. Do not run the outputs on their
       own against an old table - the numbers will look plausible and be wrong.

   Business question:
       For metastatic melanoma patients diagnosed and treated with Yervoy or
       Opdualag from 2021 to 2025, what share were treated at an Authorized
       Treatment Center versus a non-ATC site of care, and where is the
       remaining opportunity?

   BASE TABLES (built in Part A)
       ATC_CLASSIFIED_FINAL    one row per patient, hybrid classification
       ATC_PATIENT_HCO_YEAR    patient x HCO x year (trend, overlap)
       ATC_TREATMENT_CLAIMS    claim level with dates and drug (journey, timing)
       STATE_REGION_MAP        state to region lookup (6 regions)

   DECK ALIGNMENT (9-slide deck, corrected July 2026). Each slide, the cell it
   fills, and the query in Part B that feeds it:

       Slide 2  Methodology            no query, text only
       Slide 3  Market structure       B3A table, B3B headline, B3C year trend
       Slide 4  Patient journey        B4A four boxes, B4B claims intensity
       Slide 5  Regional penetration   B5  bars, untapped, penetration percent
       Slide 6  State scatter          B6  untapped vs penetration by state
       Slide 7  Non-ATC by region      B7A raw top 5, B7B genuine top 5
       Slide 8  Non-ATC by state       B8A raw top 5, B8B genuine top 5
       Slide 9  Appendix               B9A satellite split, B9B dx-to-tx timing,
                                       plus B3C, B4B and B5 re-used

   Part C is context and reconciliation, not on any slide. It is here so a second
   run is never needed: classification confidence, the headline vs journey
   reconciliation (CHECK D), community-network share, drug mix, and the two ATC
   reference lists.

   TOP 5 NOT TOP 3
       The deck shows three accounts per region and per state. Every ranked query
       here returns the top 5, and Slide 8 returns the top 8 states, so if a rank
       shifts after the correction the buffer is already in hand and nothing has
       to be re-run.

   ROSTER GAP CORRECTION (applied 2026-07-17, baked into Steps 1, 2 AND 3)
       CTAM_ATC_ALIGNMENT_2026 is missing four authorized organisations, so their
       patients were scored Non-ATC. Each was confirmed against Infinity's ATC
       master (file_Veeva_Komodo_ATC_Mapping, 93 accounts): City of Hope,
       NYU Langone, Ohio State Wexner, Hoag. Effect: +566 patients move to ATC,
       6,935 to 7,501, i.e. 42.7% to 46.2%. Because the correction is in the base
       tables, every output below reads CLASS_FINAL / IS_ATC_HCO directly - there
       is no second, on-read correction anywhere in this file. Delete the four
       patterns in all three steps once the source roster carries these accounts.

   JOURNEY ALIGNMENT (applied 2026-07-21, Steps 2 and 3)
       Steps 2 and 3 now also carry the name-fallback branch, pulled from the
       finished Step 1 table, so the journey and year-trend views use the SAME ATC
       definition as the slide 3 headline. Before this, slide 4 sat on a narrower
       definition (NPI + roster only) and told a false migration story. The honest
       reading is retention, not migration: patients rarely switch networks once
       treatment begins. See B4A and the CHECK D reconciliation in C2.
   ============================================================================ */


/* ############################################################################
   PART A  -  REBUILD THE FOUR BASE TABLES
   ############################################################################ */


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
            -- Roster gap correction. Confirmed authorized, matched on a pattern
            -- not an exact string so a suffix or stray space cannot break it.
            -- Bypasses the fallback_state_limit guard on purpose. Keep in sync
            -- with the identical patterns in Steps 2 and 3.
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
name_fallback_parents AS (
    -- Parents Step 1 accepted as ATC on a name match (authorized parent in two
    -- states or fewer). Read from the finished Step 1 table so the two-state guard
    -- is already applied. Added so the trend uses the same ATC definition as the
    -- slide 3 headline. Keep in sync with Step 3.
    SELECT DISTINCT UPPER(TRIM(HCO_PARENT_NAME)) AS PARENT
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_HYBRID = 'ATC: name fallback'
      AND CLASS_FINAL  = 'ATC'
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
),
flagged AS (
    -- Flag each claim at the row level. Name fallback is matched by a join, NOT a
    -- subquery inside the later aggregate - Snowflake cannot evaluate a subquery
    -- inside an aggregate function. Keep in sync with Steps 1 and 3.
    SELECT
        t.D_PATIENT_ID,
        t.TX_YEAR,
        t.D_PRIMARY_HCO_COMPILE_ID,
        CASE
            WHEN n.NPI IS NOT NULL THEN 1
            WHEN UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%CITY OF HOPE%'
              OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%NYU LANGONE%'
              OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%WEXNER%'
              OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%HOAG%' THEN 1
            WHEN nf.PARENT IS NOT NULL THEN 1
            ELSE 0
        END AS IS_ATC_CLAIM
    FROM treated t
    INNER JOIN diagnosed d ON t.D_PATIENT_ID = d.D_PATIENT_ID
    LEFT JOIN auth_npi n ON TRIM(t.D_PRIMARY_HCO_NPI) = n.NPI
    LEFT JOIN name_fallback_parents nf ON UPPER(TRIM(t.HCO_PARENT_NAME)) = nf.PARENT
)
SELECT
    D_PATIENT_ID,
    TX_YEAR,
    D_PRIMARY_HCO_COMPILE_ID,
    MAX(IS_ATC_CLAIM) AS IS_ATC_HCO,
    COUNT(*)          AS CLAIMS
FROM flagged
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
name_fallback_parents AS (
    -- Same set as Step 2. Keeps the journey ATC flag aligned with the headline.
    SELECT DISTINCT UPPER(TRIM(HCO_PARENT_NAME)) AS PARENT
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_HYBRID = 'ATC: name fallback'
      AND CLASS_FINAL  = 'ATC'
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
    -- Roster gap correction. Keep in sync with Steps 1 and 2. Name fallback is
    -- matched by a LEFT JOIN (nf), not an IN-subquery: Snowflake rejects a subquery
    -- inside a SELECT-list CASE ("Unsupported subquery type"). Same pattern as Step 2.
    CASE
        WHEN n.NPI IS NOT NULL THEN 1
        WHEN UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%CITY OF HOPE%'
          OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%NYU LANGONE%'
          OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%WEXNER%'
          OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%HOAG%' THEN 1
        WHEN nf.PARENT IS NOT NULL THEN 1
        ELSE 0
    END AS IS_ATC_HCO
FROM treated t
INNER JOIN diagnosed d ON t.D_PATIENT_ID = d.D_PATIENT_ID
LEFT JOIN auth_npi n ON TRIM(t.D_PRIMARY_HCO_NPI) = n.NPI
LEFT JOIN name_fallback_parents nf ON UPPER(TRIM(t.HCO_PARENT_NAME)) = nf.PARENT;


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


/* ############################################################################
   PART B  -  SLIDE OUTPUTS, IN SLIDE ORDER
   Screenshot each grid and retype the numbers onto the matching slide.
   ############################################################################ */


/* ---------------------------------------------------------------------------
   B3A. SLIDE 3, the market-structure table. Four buckets and a total row.
   Buckets match the definitions written on slide 2. Expect:
       ATC 7,501 (46.2%), Non-ATC: Hospital, Community network, Other, Total 16,246.
   --------------------------------------------------------------------------- */
WITH bucketed AS (
    SELECT
        D_PATIENT_ID,
        CASE
            WHEN CLASS_FINAL = 'ATC'                                  THEN 'ATC'
            WHEN CLASS_FINAL = 'Non-ATC: Community Network'           THEN 'Non-ATC: Community network'
            WHEN CLASS_FINAL IN ('Non-ATC: Unknown', 'Needs Review')  THEN 'Non-ATC: Other'
            ELSE 'Non-ATC: Hospital'
        END AS SITE_OF_CARE
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
),
agg AS (
    -- Buckets are mutually exclusive (one row per patient), so the bucket
    -- distinct counts sum to the grand distinct total.
    SELECT SITE_OF_CARE, COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
    FROM bucketed
    GROUP BY 1
),
tot AS (
    SELECT SUM(PATIENTS) AS TOTAL FROM agg
)
SELECT a.SITE_OF_CARE, a.PATIENTS, ROUND(100.0 * a.PATIENTS / t.TOTAL, 1) AS PCT
FROM agg a CROSS JOIN tot t
UNION ALL
SELECT 'Total', t.TOTAL, 100.0 FROM tot t
ORDER BY CASE WHEN SITE_OF_CARE = 'Total' THEN 1 ELSE 0 END, PATIENTS DESC;


/* ---------------------------------------------------------------------------
   B3B. SLIDE 3, the headline bullet. Two-way split, the "about 54% outside the
   ATC Network" line.
   --------------------------------------------------------------------------- */
SELECT
    CASE WHEN CLASS_FINAL = 'ATC' THEN 'ATC' ELSE 'Non-ATC' END AS SITE_GROUP,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;


/* ---------------------------------------------------------------------------
   B3C. SLIDE 3 trend bullet and SLIDE 9 appendix. ATC share by the year each
   patient began treatment. The "rose from about 43% to 50%, 2021 to 2025" line.
   Read the first and last year off ATC_SHARE_PCT.
   --------------------------------------------------------------------------- */
WITH first_year AS (
    SELECT D_PATIENT_ID, MIN(TX_YEAR) AS FIRST_TX_YEAR
    FROM COMPILE_DEV.PUBLIC.ATC_PATIENT_HCO_YEAR
    GROUP BY 1
),
first_site AS (
    SELECT
        y.D_PATIENT_ID,
        f.FIRST_TX_YEAR,
        MAX(y.IS_ATC_HCO) AS STARTED_ATC
    FROM COMPILE_DEV.PUBLIC.ATC_PATIENT_HCO_YEAR y
    JOIN first_year f
      ON y.D_PATIENT_ID = f.D_PATIENT_ID
     AND y.TX_YEAR      = f.FIRST_TX_YEAR
    GROUP BY 1, 2
)
SELECT
    FIRST_TX_YEAR                                 AS TX_YEAR,
    COUNT(*)                                      AS PATIENTS_STARTING,
    SUM(STARTED_ATC)                              AS STARTED_AT_ATC,
    ROUND(100.0 * SUM(STARTED_ATC) / COUNT(*), 1) AS ATC_SHARE_PCT
FROM first_site
GROUP BY 1
ORDER BY 1;


/* ---------------------------------------------------------------------------
   B4A. SLIDE 4, the patient journey. First treatment site by last treatment
   site, on the aligned ATC definition (name fallback now in Step 3, so this
   matches the slide 3 headline). Expect about:
       Started non-ATC, stayed non-ATC   8,775 (53.5%)
       Started ATC, stayed ATC           7,482 (45.6%)
       Started non-ATC, moved to ATC        99 (0.6%)
       Started ATC, left                    48 (0.3%)
   The story is retention, not migration: patients rarely switch networks once
   treatment begins, so ATC share is set at first treatment. Do NOT say ATCs gain
   patients over the course of care - only about 99 do.
   --------------------------------------------------------------------------- */
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
    CASE WHEN FIRST_ATC = 1 THEN 'Started at an ATC' ELSE 'Started non-ATC' END AS FIRST_SITE,
    CASE WHEN LAST_ATC  = 1 THEN 'Ended at an ATC'   ELSE 'Ended non-ATC'   END AS LAST_SITE,
    COUNT(*)                                          AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM first_last
GROUP BY 1, 2
ORDER BY 3 DESC;


/* ---------------------------------------------------------------------------
   B4B. SLIDE 4 strip and SLIDE 9 appendix. Claims per patient by starting site.
   The "6.9 vs 6.0 claims per patient" line.
   --------------------------------------------------------------------------- */
WITH ranked AS (
    SELECT
        D_PATIENT_ID,
        IS_ATC_HCO,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE, D_PRIMARY_HCO_COMPILE_ID) AS RN
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
pt AS (
    SELECT
        D_PATIENT_ID,
        MAX(CASE WHEN RN = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
        COUNT(*)                                  AS TREATMENT_CLAIMS
    FROM ranked
    GROUP BY 1
)
SELECT
    CASE WHEN FIRST_ATC = 1 THEN 'Started at ATC' ELSE 'Started at non-ATC' END AS FIRST_SITE,
    COUNT(*)                        AS PATIENTS,
    ROUND(AVG(TREATMENT_CLAIMS), 1) AS AVG_CLAIMS_PER_PATIENT
FROM pt
GROUP BY 1
ORDER BY 2 DESC;


/* ---------------------------------------------------------------------------
   B5. SLIDE 5 bars and SLIDE 9 penetration range. Treated in the ATC Network,
   untapped, total, and the penetration percent next to each region label.
   The Unmapped row is the unassigned-geography count the slide footnote excludes;
   read it and put the real number in that footnote.
   --------------------------------------------------------------------------- */
SELECT
    COALESCE(r.REGION, 'Unmapped, excluded from the slide')  AS REGION_NAME,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
                        THEN a.D_PATIENT_ID END)             AS TREATED_IN_ATC_NETWORK,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL <> 'ATC'
                        THEN a.D_PATIENT_ID END)             AS UNTAPPED,
    COUNT(DISTINCT a.D_PATIENT_ID)                           AS TOTAL_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
                                      THEN a.D_PATIENT_ID END)
          / COUNT(DISTINCT a.D_PATIENT_ID), 0)               AS ATC_PENETRATION_PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
    ON a.PRIMARY_HCO_NPI_STATE = r.STATE
GROUP BY 1
ORDER BY 4 DESC;


/* ---------------------------------------------------------------------------
   B6. SLIDE 6, the state scatter. One row per state. Plot UNTAPPED on the y axis
   and ATC_PENETRATION_PCT on the x axis. Priority zone is high untapped, low
   penetration (top left). Only states with 100 or more patients are returned so
   the chart stays readable.
   --------------------------------------------------------------------------- */
SELECT
    PRIMARY_HCO_NPI_STATE                                 AS STATE,
    COUNT(DISTINCT CASE WHEN CLASS_FINAL = 'ATC'
                        THEN D_PATIENT_ID END)            AS TREATED_IN_ATC_NETWORK,
    COUNT(DISTINCT CASE WHEN CLASS_FINAL <> 'ATC'
                        THEN D_PATIENT_ID END)            AS UNTAPPED,
    COUNT(DISTINCT D_PATIENT_ID)                          AS TOTAL_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN CLASS_FINAL = 'ATC'
                                      THEN D_PATIENT_ID END)
          / COUNT(DISTINCT D_PATIENT_ID), 1)              AS ATC_PENETRATION_PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE PRIMARY_HCO_NPI_STATE IS NOT NULL
GROUP BY 1
HAVING COUNT(DISTINCT D_PATIENT_ID) >= 100
ORDER BY 3 DESC;


/* ---------------------------------------------------------------------------
   B7A. SLIDE 7, top 5 non-ATC accounts per region (raw, correction only), plus
   each region's untapped total for the card header. The slide shows three; the
   extra two are the buffer. City of Hope and NYU Langone must NOT appear - if
   either does, the correction did not land.
   --------------------------------------------------------------------------- */
WITH nonatc AS (
    SELECT
        COALESCE(r.REGION, 'Unmapped')                                       AS REGION_NAME,
        COALESCE(NULLIF(TRIM(a.HCO_PARENT_NAME), ''), 'Unknown / unmapped')  AS PARENT,
        COUNT(DISTINCT a.D_PATIENT_ID)                                       AS PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
    LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
        ON a.PRIMARY_HCO_NPI_STATE = r.STATE
    WHERE a.CLASS_FINAL <> 'ATC'
    GROUP BY 1, 2
),
region_tot AS (
    SELECT REGION_NAME, SUM(PATIENTS) AS REGION_UNTAPPED
    FROM nonatc GROUP BY 1
),
ranked AS (
    SELECT
        n.REGION_NAME, n.PARENT, n.PATIENTS, t.REGION_UNTAPPED,
        ROW_NUMBER() OVER (PARTITION BY n.REGION_NAME ORDER BY n.PATIENTS DESC) AS RN
    FROM nonatc n
    JOIN region_tot t ON n.REGION_NAME = t.REGION_NAME
)
SELECT REGION_NAME, REGION_UNTAPPED, RN AS RANK_IN_REGION, PARENT, PATIENTS
FROM ranked
WHERE RN <= 5
  AND REGION_NAME <> 'Unmapped'
ORDER BY REGION_UNTAPPED DESC, PATIENTS DESC;


/* ---------------------------------------------------------------------------
   B7B. SLIDE 7 alternative, GENUINE targets per region, top 5. Same as B7A but
   also drops the multi-site systems that sit on the ATC roster with only one
   authorized site (Kaiser, Providence, Mayo, Intermountain, Avera, Northwell,
   AdventHealth, Advocate, St Luke's, Baylor). Nothing even partly an ATC appears
   as a target here. Use B7A to match the current slide, B7B for the cleaner list.
   --------------------------------------------------------------------------- */
WITH nonatc AS (
    SELECT
        COALESCE(r.REGION, 'Unmapped')                                       AS REGION_NAME,
        COALESCE(NULLIF(TRIM(a.HCO_PARENT_NAME), ''), 'Unknown / unmapped')  AS PARENT,
        COUNT(DISTINCT a.D_PATIENT_ID)                                       AS PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
    LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
        ON a.PRIMARY_HCO_NPI_STATE = r.STATE
    WHERE a.CLASS_FINAL <> 'ATC'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%KAISER%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%PROVIDENCE%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%MAYO%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%INTERMOUNTAIN%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%AVERA%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%NORTHWELL%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%ADVENTHEALTH%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%ADVOCATE%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%ST LUKE%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%BAYLOR%'
    GROUP BY 1, 2
),
region_tot AS (
    SELECT REGION_NAME, SUM(PATIENTS) AS REGION_UNTAPPED
    FROM nonatc GROUP BY 1
),
ranked AS (
    SELECT
        n.REGION_NAME, n.PARENT, n.PATIENTS, t.REGION_UNTAPPED,
        ROW_NUMBER() OVER (PARTITION BY n.REGION_NAME ORDER BY n.PATIENTS DESC) AS RN
    FROM nonatc n
    JOIN region_tot t ON n.REGION_NAME = t.REGION_NAME
)
SELECT REGION_NAME, REGION_UNTAPPED, RN AS RANK_IN_REGION, PARENT, PATIENTS
FROM ranked
WHERE RN <= 5
  AND REGION_NAME <> 'Unmapped'
ORDER BY REGION_UNTAPPED DESC, PATIENTS DESC;


/* ---------------------------------------------------------------------------
   B8A. SLIDE 8, top 5 non-ATC accounts (raw, correction only) for the eight
   largest states by non-ATC volume. The slide shows six states and three
   accounts each; the extra states and accounts are the buffer in case the order
   shifts after the correction. STATE_RANK gives the true ordering.
   --------------------------------------------------------------------------- */
WITH nonatc AS (
    SELECT
        a.PRIMARY_HCO_NPI_STATE                                              AS STATE,
        COALESCE(NULLIF(TRIM(a.HCO_PARENT_NAME), ''), 'Unknown / unmapped')  AS PARENT,
        COUNT(DISTINCT a.D_PATIENT_ID)                                       AS PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
    WHERE a.CLASS_FINAL <> 'ATC'
      AND a.PRIMARY_HCO_NPI_STATE IS NOT NULL
    GROUP BY 1, 2
),
state_tot AS (
    SELECT STATE, SUM(PATIENTS) AS STATE_UNTAPPED
    FROM nonatc GROUP BY 1
),
top_states AS (
    SELECT STATE, STATE_UNTAPPED,
           ROW_NUMBER() OVER (ORDER BY STATE_UNTAPPED DESC) AS STATE_RANK
    FROM state_tot
),
ranked AS (
    SELECT
        n.STATE, n.PARENT, n.PATIENTS, s.STATE_UNTAPPED, s.STATE_RANK,
        ROW_NUMBER() OVER (PARTITION BY n.STATE ORDER BY n.PATIENTS DESC) AS RN
    FROM nonatc n
    JOIN top_states s ON n.STATE = s.STATE
)
SELECT STATE, STATE_RANK, STATE_UNTAPPED, RN AS RANK_IN_STATE, PARENT, PATIENTS
FROM ranked
WHERE RN <= 5
  AND STATE_RANK <= 8
ORDER BY STATE_UNTAPPED DESC, PATIENTS DESC;


/* ---------------------------------------------------------------------------
   B8B. SLIDE 8 alternative, GENUINE targets, top 5 for the eight largest states.
   Same multi-site roster exclusion as B7B. Note the eight largest states can
   differ from B8A once those systems are removed, so read STATE_RANK here too.
   --------------------------------------------------------------------------- */
WITH nonatc AS (
    SELECT
        a.PRIMARY_HCO_NPI_STATE                                              AS STATE,
        COALESCE(NULLIF(TRIM(a.HCO_PARENT_NAME), ''), 'Unknown / unmapped')  AS PARENT,
        COUNT(DISTINCT a.D_PATIENT_ID)                                       AS PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
    WHERE a.CLASS_FINAL <> 'ATC'
      AND a.PRIMARY_HCO_NPI_STATE IS NOT NULL
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%KAISER%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%PROVIDENCE%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%MAYO%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%INTERMOUNTAIN%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%AVERA%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%NORTHWELL%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%ADVENTHEALTH%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%ADVOCATE%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%ST LUKE%'
      AND UPPER(TRIM(a.HCO_PARENT_NAME)) NOT LIKE '%BAYLOR%'
    GROUP BY 1, 2
),
state_tot AS (
    SELECT STATE, SUM(PATIENTS) AS STATE_UNTAPPED
    FROM nonatc GROUP BY 1
),
top_states AS (
    SELECT STATE, STATE_UNTAPPED,
           ROW_NUMBER() OVER (ORDER BY STATE_UNTAPPED DESC) AS STATE_RANK
    FROM state_tot
),
ranked AS (
    SELECT
        n.STATE, n.PARENT, n.PATIENTS, s.STATE_UNTAPPED, s.STATE_RANK,
        ROW_NUMBER() OVER (PARTITION BY n.STATE ORDER BY n.PATIENTS DESC) AS RN
    FROM nonatc n
    JOIN top_states s ON n.STATE = s.STATE
)
SELECT STATE, STATE_RANK, STATE_UNTAPPED, RN AS RANK_IN_STATE, PARENT, PATIENTS
FROM ranked
WHERE RN <= 5
  AND STATE_RANK <= 8
ORDER BY STATE_UNTAPPED DESC, PATIENTS DESC;


/* ---------------------------------------------------------------------------
   B9A. SLIDE 9 appendix, the satellite split. Share of ATC patients by how they
   were classified. The "57% of ATC patients are at satellite sites" line reads
   off the non-NPI-confirmed rows (roster gap corrected plus name fallback came
   in through the parent, i.e. satellites of an ATC parent).
   --------------------------------------------------------------------------- */
SELECT
    CLASS_HYBRID,
    COUNT(DISTINCT D_PATIENT_ID)                          AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT_OF_ATC
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1
ORDER BY 2 DESC;


/* ---------------------------------------------------------------------------
   B9B. SLIDE 9 appendix, diagnosis to first treatment timing. The "about a
   40-day median, similar across both settings" line.
   --------------------------------------------------------------------------- */
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
    COUNT(*)                        AS PATIENTS,
    ROUND(AVG(DAYS_DX_TO_TX), 0)    AS AVG_DAYS_DX_TO_TX,
    ROUND(MEDIAN(DAYS_DX_TO_TX), 0) AS MEDIAN_DAYS_DX_TO_TX
FROM first_tx
WHERE RN = 1
  AND DAYS_DX_TO_TX >= 0
GROUP BY 1
ORDER BY 2 DESC;


/* ############################################################################
   PART C  -  CONTEXT AND RECONCILIATION (not on a slide)
   Run for the buffer, so a follow-up question never needs a second trip.
   ############################################################################ */


/* ---------------------------------------------------------------------------
   C1. Classification confidence. How the ATC and non-ATC counts are built by
   match type. Supports the slide 3 table and the satellite split.
   --------------------------------------------------------------------------- */
SELECT
    CLASS_HYBRID,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;


/* ---------------------------------------------------------------------------
   C2. CHECK D, headline versus journey reconciliation.
   Steps 2 and 3 now carry the same name-fallback branch as Step 1, so the journey
   uses the SAME ATC definition as the slide 3 headline. This confirms it:
   ATC_IN_JOURNEY should now land near the 7,501 headline (about 7,638, a touch
   higher because the journey flags a patient ATC on any claim at a name-fallback
   site while the headline uses the primary site), so DIFFERENCE goes slightly
   negative. Before the alignment ATC_IN_JOURNEY was only about 3,924.
   --------------------------------------------------------------------------- */
WITH headline AS (
    SELECT COUNT(DISTINCT D_PATIENT_ID) AS ATC_HEADLINE
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_FINAL = 'ATC'
),
name_fallback_only AS (
    SELECT COUNT(DISTINCT D_PATIENT_ID) AS ATC_VIA_NAME_FALLBACK
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_FINAL = 'ATC'
      AND CLASS_HYBRID = 'ATC: name fallback'
),
journey AS (
    SELECT COUNT(DISTINCT D_PATIENT_ID) AS ATC_IN_JOURNEY
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    WHERE IS_ATC_HCO = 1
)
SELECT
    h.ATC_HEADLINE,
    j.ATC_IN_JOURNEY,
    h.ATC_HEADLINE - j.ATC_IN_JOURNEY AS DIFFERENCE,
    n.ATC_VIA_NAME_FALLBACK           AS NAME_FALLBACK_ONLY
FROM headline h, journey j, name_fallback_only n;


/* ---------------------------------------------------------------------------
   C3. Community-network share of the non-ATC volume (US Oncology, One Oncology,
   American Oncology versus independent or other).
   --------------------------------------------------------------------------- */
SELECT
    COALESCE(HCO_COMMUNITY_NETWORK, 'Independent / Other') AS NETWORK,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT_OF_NON_ATC
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL LIKE 'Non-ATC%'
GROUP BY 1
ORDER BY 2 DESC;


/* ---------------------------------------------------------------------------
   C4. Drug mix, Yervoy versus Opdualag, and the ATC share of each.
   --------------------------------------------------------------------------- */
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


/* ---------------------------------------------------------------------------
   C5. Reference list, authorized ATC accounts rolled up to parent.
   --------------------------------------------------------------------------- */
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


/* ---------------------------------------------------------------------------
   C6. Reference list, authorized ATC accounts at the individual site level.
   --------------------------------------------------------------------------- */
SELECT
    PRIMARY_HCO_NPI_NAME  AS ACCOUNT_NAME,
    HCO_PARENT_NAME,
    PRIMARY_HCO_NPI_STATE AS STATE,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    SUM(TREATMENT_CLAIMS)        AS TOTAL_CLAIMS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1, 2, 3
ORDER BY PATIENTS DESC;
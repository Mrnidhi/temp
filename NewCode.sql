/* ============================================================================
   Diagnosed & Treated Patients - ATC vs Non-ATC Split

   Business question:
       For metastatic melanoma patients diagnosed and treated with Yervoy or
       Opdualag from 2021-2025, what share of patients were treated at an
       Authorized Treatment Center versus a non-ATC site of care?

   Outputs:

   BASE TABLES
       ATC_CLASSIFIED_FINAL    one row per patient, hybrid classification
       ATC_PATIENT_HCO_YEAR    patient x HCO x year (trend, overlap)
       ATC_TREATMENT_CLAIMS    claim level with dates and drug (journey, timing)
       STATE_REGION_MAP        state to region lookup (6 regions)

   INSIGHTS
       8   Patient journey (first vs last treatment site)      [priority]
       9   Treatment persistence by starting site              [priority]
      6a   Migration cohort: start non-ATC, classified ATC
      6b   Time spent in each setting (migration cohort)
       1   Headline split (ATC vs Non-ATC)
       2   Classification confidence
       3   ATC share by treatment year
       4   ATC-assigned patients with non-ATC activity
       5   Leakage concentration by account
       7   Community network share of leakage
      10   Regional ATC penetration
      11   Time from diagnosis to first treatment (context only)
      12   Drug mix (Yervoy vs Opdualag)
      13   ATC performance profile
   ============================================================================ */


SET fallback_state_limit = 2;


-- Base classification (one row per patient)
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
        WHEN c.CLASS_HYBRID = 'ATC: name fallback' AND f.PARENT_STATES <= $fallback_state_limit THEN 'ATC'
        WHEN c.CLASS_HYBRID = 'ATC: name fallback' AND f.PARENT_STATES >  $fallback_state_limit THEN 'Non-ATC: System sweep'
        WHEN c.CLASS_HYBRID = 'Needs Review'                                                    THEN 'Needs Review'
        ELSE c.CLASS_HYBRID
    END AS CLASS_FINAL
FROM classified c
LEFT JOIN fallback_footprint f
    ON c.HCO_PARENT_NAME = f.HCO_PARENT_NAME;


-- Patient x HCO x year grain, for trend and overlap (NPI-confirmed flag)
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
    MAX(CASE WHEN n.NPI IS NOT NULL THEN 1 ELSE 0 END) AS IS_ATC_HCO,
    COUNT(*) AS CLAIMS
FROM treated t
INNER JOIN diagnosed d ON t.D_PATIENT_ID = d.D_PATIENT_ID
LEFT JOIN auth_npi   n ON TRIM(t.D_PRIMARY_HCO_NPI) = n.NPI
GROUP BY 1, 2, 3;


-- Claim-level treatment table with dates and drug, for journey / persistence / timing
-- NDC-to-drug mapping inferred from labeler; verify against internal code dictionary
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
    CASE WHEN n.NPI IS NOT NULL THEN 1 ELSE 0 END AS IS_ATC_HCO
FROM treated t
INNER JOIN diagnosed d ON t.D_PATIENT_ID = d.D_PATIENT_ID
LEFT JOIN auth_npi n ON TRIM(t.D_PRIMARY_HCO_NPI) = n.NPI;


-- State to region map (6 regions; VA/MD/DC/DE in Northeast; AK/HI unmapped by design)
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


-- Insight 8: Patient journey - first treatment site vs last treatment site  [PRIORITY]
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


-- Insight 9: Treatment persistence by starting site  [PRIORITY]
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


-- Insight 6a: Migration cohort - first treatment Non-ATC but classified ATC overall
-- (Kolin's ~3,500 patients: started community, moved into an ATC)
WITH first_site AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO AS FIRST_ATC
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    QUALIFY ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                               ORDER BY DATE_OF_SERVICE, D_PRIMARY_HCO_COMPILE_ID) = 1
)
SELECT
    CASE
        WHEN c.CLASS_FINAL = 'ATC' AND fs.FIRST_ATC = 0 THEN 'Migrated in (start Non-ATC, classified ATC)'
        WHEN c.CLASS_FINAL = 'ATC' AND fs.FIRST_ATC = 1 THEN 'Stayed ATC (start and classified ATC)'
        WHEN c.CLASS_FINAL <> 'ATC'                     THEN 'Non-ATC'
        ELSE 'Other'
    END AS PATIENT_GROUP,
    COUNT(DISTINCT c.D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT c.D_PATIENT_ID)
          / SUM(COUNT(DISTINCT c.D_PATIENT_ID)) OVER (), 1) AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL c
INNER JOIN first_site fs ON c.D_PATIENT_ID = fs.D_PATIENT_ID
GROUP BY 1
ORDER BY 2 DESC;


-- Insight 6b: Referral source - of patients starting Non-ATC, which starting systems
-- send patients on to an ATC. Starting parent read from the patient's first claim.
WITH first_claim AS (
    SELECT
        D_PATIENT_ID,
        HCO_PARENT_NAME AS STARTING_PARENT,
        IS_ATC_HCO      AS STARTED_ATC
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    QUALIFY ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                               ORDER BY DATE_OF_SERVICE, D_PRIMARY_HCO_COMPILE_ID) = 1
),
starters AS (
    SELECT
        fc.D_PATIENT_ID,
        COALESCE(fc.STARTING_PARENT, 'Unknown') AS STARTING_PARENT,
        CASE WHEN c.CLASS_FINAL = 'ATC' THEN 1 ELSE 0 END AS MIGRATED
    FROM first_claim fc
    INNER JOIN COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL c
        ON fc.D_PATIENT_ID = c.D_PATIENT_ID
    WHERE fc.STARTED_ATC = 0
)
SELECT
    STARTING_PARENT,
    COUNT(*) AS PATIENTS_STARTED_HERE,
    SUM(MIGRATED) AS MIGRATED_TO_ATC,
    ROUND(100.0 * SUM(MIGRATED) / NULLIF(COUNT(*), 0), 1) AS MIGRATION_RATE_PCT
FROM starters
GROUP BY 1
HAVING COUNT(*) >= 30
ORDER BY PATIENTS_STARTED_HERE DESC
LIMIT 25;


-- Insight 1: Headline split (ATC vs Non-ATC)
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


-- Insight 2: Classification confidence (how the ATC count is built)
SELECT
    CLASS_HYBRID,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;


-- Insight 3: ATC share by treatment year
SELECT
    TX_YEAR,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS_TREATED,
    COUNT(DISTINCT CASE WHEN IS_ATC_HCO = 1 THEN D_PATIENT_ID END) AS ATC_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN IS_ATC_HCO = 1 THEN D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT D_PATIENT_ID), 0), 1) AS PCT_ATC
FROM COMPILE_DEV.PUBLIC.ATC_PATIENT_HCO_YEAR
GROUP BY 1
ORDER BY 1;


-- Insight 4: ATC-assigned patients with non-ATC activity (referral / leakage signal)
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


-- Insight 5: Leakage concentration by parent account
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


-- Insight 7: Community network share of leakage
SELECT
    COALESCE(HCO_COMMUNITY_NETWORK, 'Independent / Other') AS NETWORK,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT_OF_LEAKAGE
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL LIKE 'Non-ATC%'
GROUP BY 1
ORDER BY 2 DESC;


-- Insight 10: Regional ATC penetration
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


-- Insight 11: Time from diagnosis to first treatment (context only; median diff is small)
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


-- Insight 12: Drug mix - Yervoy vs Opdualag, share treated at ATC
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


-- Insight 13: ATC performance profile (engagement by center, min 10 patients)
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


-- Reference: authorized account list, rolled to parent
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

-- Reference: authorized account list, site level
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
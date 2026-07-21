/* ============================================================================
   RUN THIS - build the four base tables once, then only the queries still needed
   to finalize the deck. Nothing else from the MASTER runs, so this is the cheapest
   way to close out Site of Care.

   HOW TO RUN
       Run all, top to bottom, once. Part A rebuilds the tables (the only heavy
       step, it scans the claims table twice). Part B is five light reads plus a
       roster sanity. Screenshot Q3A, Q4A, Q4B, Q4D, Q4E, Q4F and send them.

   This is a trimmed copy of the MASTER - the table builds are identical (aligned:
   Steps 2 and 3 carry the name fallback), only the slide outputs that did not
   change are dropped. The MASTER stays the source of truth.
   ============================================================================ */


/* ############################################################################
   PART A  -  REBUILD THE FOUR BASE TABLES  (heavy step, runs once)
   ############################################################################ */


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
    -- inside an aggregate function.
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
    -- Roster gap correction plus name fallback. Keep in sync with Steps 1 and 2.
    CASE
        WHEN n.NPI IS NOT NULL THEN 1
        WHEN UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%CITY OF HOPE%'
          OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%NYU LANGONE%'
          OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%WEXNER%'
          OR UPPER(TRIM(t.HCO_PARENT_NAME)) LIKE '%HOAG%' THEN 1
        WHEN UPPER(TRIM(t.HCO_PARENT_NAME)) IN
             (SELECT PARENT FROM name_fallback_parents) THEN 1
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


/* ############################################################################
   PART B  -  FINISH QUERIES  (light reads, screenshot each)
   ############################################################################ */


/* Q3A. Build sanity. The four roster orgs must every one read CLASS_FINAL = ATC.
   If any shows non-ATC, the build broke - stop and tell me before the rest. */
SELECT
    CASE
        WHEN UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%CITY OF HOPE%' THEN 'City of Hope'
        WHEN UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%NYU LANGONE%'  THEN 'NYU Langone'
        WHEN UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%WEXNER%'       THEN 'Ohio State Wexner'
        WHEN UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%HOAG%'         THEN 'Hoag'
    END                          AS ORG,
    CLASS_FINAL,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%CITY OF HOPE%'
   OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%NYU LANGONE%'
   OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%WEXNER%'
   OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%HOAG%'
GROUP BY 1, 2
ORDER BY PATIENTS DESC;


/* Q4A. CHECK D. ATC_IN_JOURNEY should now sit near the 7,501 headline (about
   7,638), not the old 3,924. Confirms Steps 2 and 3 are aligned. */
WITH headline AS (
    SELECT COUNT(DISTINCT D_PATIENT_ID) AS ATC_HEADLINE
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL WHERE CLASS_FINAL = 'ATC'
),
journey AS (
    SELECT COUNT(DISTINCT D_PATIENT_ID) AS ATC_IN_JOURNEY
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS WHERE IS_ATC_HCO = 1
),
name_fallback_only AS (
    SELECT COUNT(DISTINCT D_PATIENT_ID) AS NAME_FALLBACK_ONLY
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_FINAL = 'ATC' AND CLASS_HYBRID = 'ATC: name fallback'
)
SELECT h.ATC_HEADLINE, j.ATC_IN_JOURNEY,
       h.ATC_HEADLINE - j.ATC_IN_JOURNEY AS DIFFERENCE,
       n.NAME_FALLBACK_ONLY
FROM headline h, journey j, name_fallback_only n;


/* Q4B. Slide 4 four boxes, live (aligned). First treatment site by last treatment
   site. Expect about 8,775 / 7,482 / 99 / 48. Retention, not migration. */
WITH ranked AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE ASC,  D_PRIMARY_HCO_COMPILE_ID) AS RN_FIRST,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE DESC, D_PRIMARY_HCO_COMPILE_ID) AS RN_LAST
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
first_last AS (
    SELECT D_PATIENT_ID,
        MAX(CASE WHEN RN_FIRST = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
        MAX(CASE WHEN RN_LAST  = 1 THEN IS_ATC_HCO END) AS LAST_ATC
    FROM ranked GROUP BY 1
)
SELECT
    CASE WHEN FIRST_ATC = 1 THEN 'Started at an ATC' ELSE 'Started non-ATC' END AS FIRST_SITE,
    CASE WHEN LAST_ATC  = 1 THEN 'Ended at an ATC'   ELSE 'Ended non-ATC'   END AS LAST_SITE,
    COUNT(*) AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM first_last
GROUP BY 1, 2
ORDER BY 3 DESC;


/* Q4D. Year trend, aligned (slide 3 "rose from X% to Y%" bullet). Read the first
   and last year off ATC_SHARE_PCT. */
WITH first_year AS (
    SELECT D_PATIENT_ID, MIN(TX_YEAR) AS FIRST_TX_YEAR
    FROM COMPILE_DEV.PUBLIC.ATC_PATIENT_HCO_YEAR
    GROUP BY 1
),
first_site AS (
    SELECT y.D_PATIENT_ID, f.FIRST_TX_YEAR, MAX(y.IS_ATC_HCO) AS STARTED_ATC
    FROM COMPILE_DEV.PUBLIC.ATC_PATIENT_HCO_YEAR y
    JOIN first_year f ON y.D_PATIENT_ID = f.D_PATIENT_ID AND y.TX_YEAR = f.FIRST_TX_YEAR
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


/* Q4E. Claims per patient, aligned (slide 4 strip "X vs Y claims per patient"). */
WITH ranked AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE, D_PRIMARY_HCO_COMPILE_ID) AS RN
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
pt AS (
    SELECT D_PATIENT_ID,
        MAX(CASE WHEN RN = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
        COUNT(*)                                  AS TREATMENT_CLAIMS
    FROM ranked GROUP BY 1
)
SELECT
    CASE WHEN FIRST_ATC = 1 THEN 'Started at ATC' ELSE 'Started at non-ATC' END AS FIRST_SITE,
    COUNT(*)                        AS PATIENTS,
    ROUND(AVG(TREATMENT_CLAIMS), 1) AS AVG_CLAIMS_PER_PATIENT
FROM pt
GROUP BY 1
ORDER BY 2 DESC;


/* Q4F. Diagnosis-to-first-treatment timing, aligned (appendix "about a 40-day
   median" line). */
WITH first_tx AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO,
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

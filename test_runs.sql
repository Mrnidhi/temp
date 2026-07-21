/* ============================================================================
   TEST / QA FILE - Site of Care. Every check worth running, in one place.

   WHAT THIS IS
       Read-only checks that confirm the four base tables are built and classified
       the way we think. Run this after any MASTER rebuild (new ATCs, roster change,
       definition change) to catch a break before the numbers reach a slide.

   HOW TO RUN
       The four base tables must already exist (run the MASTER first). Run all,
       screenshot each grid. Nothing here creates or changes a table.

   SECTIONS
       1  Population integrity     row and patient counts line up across tables
       2  Classification audit     how every patient bucket is built
       3  Roster correction        the four gap orgs landed as ATC
       4  Alignment effects        CHECK D, slide 4 boxes, start/class cross, and
                                 every slide number that moved with the alignment
       5  Data quality             state coverage, drug mix, community network
       6  New-ATC readiness         template to test an ATC before adding it

   This supersedes "TEST - slide 4 journey definitions" - Section 4 folds it in,
   now on the aligned definition that is live in the MASTER.
   ============================================================================ */


/* ############################################################################
   SECTION 1  -  POPULATION INTEGRITY
   ############################################################################ */

/* Q1A. Headcounts per base table. Sanity floor for everything else.
   Journey patients (~16,404) sit a little above classified (~16,246) because the
   journey keeps every treated-and-diagnosed patient, classified is one row each. */
SELECT 'classified patients'  AS METRIC, COUNT(DISTINCT D_PATIENT_ID) AS N FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
UNION ALL SELECT 'journey patients',     COUNT(DISTINCT D_PATIENT_ID)      FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
UNION ALL SELECT 'journey claims',       COUNT(*)                          FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
UNION ALL SELECT 'year-table patients',  COUNT(DISTINCT D_PATIENT_ID)      FROM COMPILE_DEV.PUBLIC.ATC_PATIENT_HCO_YEAR;


/* Q1B. One row per patient in the classified table. ROWS must equal PATIENTS,
   otherwise the market-table distinct counts would double-count. */
SELECT COUNT(*) AS ROWS, COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL;


/* Q1C. Where the two populations differ. Explains the journey-vs-classified gap. */
SELECT
    (SELECT COUNT(DISTINCT t.D_PATIENT_ID)
       FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS t
      WHERE NOT EXISTS (SELECT 1 FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL c
                         WHERE c.D_PATIENT_ID = t.D_PATIENT_ID))       AS IN_JOURNEY_NOT_CLASSIFIED,
    (SELECT COUNT(DISTINCT c.D_PATIENT_ID)
       FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL c
      WHERE NOT EXISTS (SELECT 1 FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS t
                         WHERE t.D_PATIENT_ID = c.D_PATIENT_ID))       AS CLASSIFIED_NOT_IN_JOURNEY;


/* ############################################################################
   SECTION 2  -  CLASSIFICATION AUDIT
   ############################################################################ */

/* Q2A. The full CLASS_HYBRID by CLASS_FINAL matrix. Shows exactly how each raw
   match type rolls into the final ATC / non-ATC decision, including name fallback
   splitting into ATC (<=2 states) and Non-ATC: System sweep (>2 states). */
SELECT CLASS_HYBRID, CLASS_FINAL, COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1, 2
ORDER BY 3 DESC;


/* Q2B. Name-fallback footprint audit. Every parent accepted (or swept) by the
   name match, how many states it spans, and where the two-state guard drew the
   line. This is the softest half of the ATC number, so eyeball it. */
SELECT
    HCO_PARENT_NAME,
    PARENT_STATES,
    MAX(CLASS_FINAL)             AS CLASS_FINAL,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_HYBRID = 'ATC: name fallback'
GROUP BY 1, 2
ORDER BY PATIENTS DESC;


/* Q2C. Needs Review - names close to an authorized parent but not a clean match.
   Kept out of ATC on purpose. Small list to eyeball for anything misfiled. */
SELECT HCO_PARENT_NAME, COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'Needs Review'
GROUP BY 1
ORDER BY 2 DESC;


/* ############################################################################
   SECTION 3  -  ROSTER CORRECTION
   ############################################################################ */

/* Q3A. The four roster-gap orgs. Every row must read CLASS_FINAL = ATC. If any
   shows non-ATC, the correction did not land in Step 1. */
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


/* Q3B. The mirror check. Must return ZERO rows - none of the four can still be
   sitting in a non-ATC bucket (which would leak them onto slides 7 and 8). */
SELECT HCO_PARENT_NAME, CLASS_FINAL, COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL <> 'ATC'
  AND (UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%CITY OF HOPE%'
    OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%NYU LANGONE%'
    OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%WEXNER%'
    OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%HOAG%')
GROUP BY 1, 2;


/* ############################################################################
   SECTION 4  -  ALIGNMENT EFFECTS
   CHECK D and the slide 4 boxes, plus every other slide number that moved once
   Steps 2 and 3 picked up the name fallback (year trend, claims strip, timing).
   ############################################################################ */

/* Q4A. CHECK D. With Steps 2 and 3 aligned, ATC_IN_JOURNEY should land near the
   7,501 headline (about 7,638, slightly higher - a patient is flagged ATC on any
   claim at a name-fallback site, the headline uses the primary site). Before the
   alignment this was about 3,924. */
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


/* Q4C. Start site by overall classification. Audit only - this is the cross that
   the old slide 4 "3,701 moved to ATC" number came from. It is a first-site vs
   classified cross, not a trajectory, which is why it is not the slide 4 story. */
WITH ranked AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE ASC, D_PRIMARY_HCO_COMPILE_ID) AS RN
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
first_claim AS (
    SELECT D_PATIENT_ID, MAX(CASE WHEN RN = 1 THEN IS_ATC_HCO END) AS FIRST_ATC
    FROM ranked GROUP BY 1
)
SELECT
    CASE WHEN fc.FIRST_ATC = 1 THEN 'Started at an ATC' ELSE 'Started non-ATC' END AS FIRST_SITE,
    CASE WHEN c.CLASS_FINAL = 'ATC' THEN 'Classified ATC' ELSE 'Classified non-ATC' END AS CLASSIFIED_AS,
    COUNT(*) AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM first_claim fc
JOIN COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL c ON fc.D_PATIENT_ID = c.D_PATIENT_ID
GROUP BY 1, 2
ORDER BY 3 DESC;


/* Q4D. Year trend, aligned (slide 3 "rose from X% to Y%" bullet). ATC share by the
   year each patient began treatment. Reads the year table, which is now aligned,
   so read the new first-year and last-year percents off ATC_SHARE_PCT. */
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


/* Q4E. Claims per patient, aligned (slide 4 strip "X vs Y claims per patient").
   Reads the journey, now aligned, so this replaces the old narrow number. */
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
   median" line). Splits by the journey ATC flag, now aligned. */
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


/* ############################################################################
   SECTION 5  -  DATA QUALITY
   ############################################################################ */

/* Q5A. State coverage. How many patients have no state, or a state not mapped to a
   region (those drop out of slides 5 and 6). Confirms the Unmapped footnote count. */
SELECT
    CASE
        WHEN a.PRIMARY_HCO_NPI_STATE IS NULL THEN 'null state'
        WHEN r.STATE IS NULL                 THEN 'state not mapped to a region'
        ELSE 'mapped'
    END                          AS STATE_STATUS,
    COUNT(DISTINCT a.D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r ON a.PRIMARY_HCO_NPI_STATE = r.STATE
GROUP BY 1
ORDER BY 2 DESC;


/* Q5B. Drug mix and ATC share by drug. */
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


/* Q5C. Community-network share of non-ATC volume. */
SELECT
    COALESCE(HCO_COMMUNITY_NETWORK, 'Independent / Other') AS NETWORK,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT_OF_NON_ATC
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL LIKE 'Non-ATC%'
GROUP BY 1
ORDER BY 2 DESC;


/* ############################################################################
   SECTION 6  -  NEW-ATC READINESS (future use)
   ############################################################################ */

/* Q6. Before adding a new ATC to the roster, set the pattern below to its parent
   name and run this to see how many patients it would pull in and which bucket
   they sit in today. Run it once per new account. Change only the SET line. */
SET new_atc_pattern = '%YOUR NEW ATC PARENT NAME%';

SELECT
    CLASS_FINAL,
    COUNT(DISTINCT D_PATIENT_ID)          AS PATIENTS,
    COUNT(DISTINCT PRIMARY_HCO_NPI_STATE) AS STATES
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE UPPER(TRIM(HCO_PARENT_NAME)) LIKE UPPER($new_atc_pattern)
GROUP BY 1
ORDER BY 2 DESC;

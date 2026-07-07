/*
ATC Follow-ups — closes out the remaining ATC vs Non-ATC asks
(run after the base tables from "Diagnosed & Treated Patients - ATC vs Non-ATC Split.sql" exist)

Asks covered:

  A   Currently-active ATC check                     (Tim — confirm the analysis uses active ATCs only)
  B1  True-site vs satellite split, headline         (Tim + Kolin — teased in the slide 4 footnote)
  B2  Satellite share by parent (top parents)
  B3  Sensitivity: headline split if satellites were excluded
  C   ATC share by year, 2021-2025                   (feeds the 19%→24% growth chart)
  D1  Central region drill-down by state             (why 26% vs ~48% elsewhere)
  D2  ATC supply per region (site + parent counts)
  D3  Where Central patients go instead (top non-ATC parents)
  E   Sample patient journeys, migration cohort      (Kolin — 2-3 records, expect nulls)

Depends on:
  COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
  COMPILE_DEV.PUBLIC.ATC_PATIENT_HCO_YEAR
  COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
  COMPILE_DEV.PUBLIC.STATE_REGION_MAP
  COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
*/


-- ============================================================================
-- A: Currently-active ATC check
-- The classification already filters Status = 'AUTHORIZED'. This shows every
-- status in the roster so we can confirm AUTHORIZED = currently active and
-- see how many rows/NPIs sit in other statuses.
-- ============================================================================
SELECT
    UPPER(TRIM("Status")) AS STATUS,
    COUNT(*) AS ROSTER_ROWS,
    COUNT(DISTINCT TRIM("NPI")) AS DISTINCT_NPIS,
    COUNT(DISTINCT UPPER(TRIM("ATC HCO Parent Name (McKesson Claims)"))) AS DISTINCT_PARENTS
FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
GROUP BY 1
ORDER BY 2 DESC;

-- If any status other than AUTHORIZED exists (e.g. terminated / pending),
-- check whether those NPIs picked up patients anyway (they should not have):
WITH non_auth_npi AS (
    SELECT DISTINCT TRIM("NPI") AS NPI
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status")) <> 'AUTHORIZED'
      AND "NPI" IS NOT NULL
      AND TRIM("NPI") NOT IN ('0', '', 'NPI')
)
SELECT
    a.CLASS_FINAL,
    COUNT(DISTINCT a.D_PATIENT_ID) AS PATIENTS_AT_NON_AUTH_NPIS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
INNER JOIN non_auth_npi n ON TRIM(a.D_PRIMARY_HCO_NPI) = n.NPI
GROUP BY 1
ORDER BY 2 DESC;


-- ============================================================================
-- B1: True-site vs satellite split (headline)
-- Within CLASS_FINAL = 'ATC', the CLASS_HYBRID tier already separates the two:
--   'ATC: NPI confirmed'  = the patient's primary site NPI is on the
--                           authorized list -> true ATC site
--   'ATC: name fallback'  = site NPI not on the list, matched via the ATC
--                           parent name -> satellite of an ATC parent
-- ============================================================================
SELECT
    CASE
        WHEN CLASS_HYBRID = 'ATC: NPI confirmed' THEN 'True ATC site (NPI on authorized list)'
        ELSE 'Satellite (ATC parent, site not on list)'
    END AS SITE_TYPE,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
        / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT_OF_ATC
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1
ORDER BY 2 DESC;


-- ============================================================================
-- B2: Satellite share by parent — which ATC parents are satellite-heavy
-- (the "MSK satellite" concern from Meet 7, min 10 patients)
-- ============================================================================
SELECT
    HCO_PARENT_NAME,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    COUNT(DISTINCT CASE WHEN CLASS_HYBRID = 'ATC: NPI confirmed'
        THEN D_PATIENT_ID END) AS TRUE_SITE_PATIENTS,
    COUNT(DISTINCT CASE WHEN CLASS_HYBRID <> 'ATC: NPI confirmed'
        THEN D_PATIENT_ID END) AS SATELLITE_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN CLASS_HYBRID <> 'ATC: NPI confirmed'
        THEN D_PATIENT_ID END)
        / NULLIF(COUNT(DISTINCT D_PATIENT_ID), 0), 1) AS PCT_SATELLITE
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1
HAVING COUNT(DISTINCT D_PATIENT_ID) >= 10
ORDER BY SATELLITE_PATIENTS DESC
LIMIT 25;


-- ============================================================================
-- B3: Sensitivity — what the headline split becomes if satellites are
-- treated as Non-ATC (answers "does the satellite rule overstate ATC?")
-- Current headline: 42.7 / 57.3. This shows the floor.
-- ============================================================================
SELECT
    CASE
        WHEN CLASS_HYBRID = 'ATC: NPI confirmed' THEN 'ATC (true sites only)'
        ELSE 'Non-ATC (incl. satellites)'
    END AS SITE_GROUP,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
        / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;


-- ============================================================================
-- C: ATC share by treatment year — data for the 19%→24% growth chart
-- (same as Insight 3; rerun to grab all five yearly values for the visual)
-- ============================================================================
SELECT
    TX_YEAR,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS_TREATED,
    COUNT(DISTINCT CASE WHEN IS_ATC_HCO = 1 THEN D_PATIENT_ID END) AS ATC_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN IS_ATC_HCO = 1 THEN D_PATIENT_ID END)
        / NULLIF(COUNT(DISTINCT D_PATIENT_ID), 0), 1) AS PCT_ATC
FROM COMPILE_DEV.PUBLIC.ATC_PATIENT_HCO_YEAR
GROUP BY 1
ORDER BY 1;


-- ============================================================================
-- D1: Central region drill-down — ATC share by state within Central
-- (is 26% uniform across TX/OK/KS/NE/SD/ND/AR, or driven by one state?)
-- ============================================================================
SELECT
    a.PRIMARY_HCO_NPI_STATE AS STATE,
    COUNT(DISTINCT a.D_PATIENT_ID) AS TOTAL_PATIENTS,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC' THEN a.D_PATIENT_ID END) AS ATC_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC' THEN a.D_PATIENT_ID END)
        / NULLIF(COUNT(DISTINCT a.D_PATIENT_ID), 0), 1) AS PCT_ATC
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
INNER JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
    ON a.PRIMARY_HCO_NPI_STATE = r.STATE
WHERE r.REGION = 'Central'
GROUP BY 1
ORDER BY 2 DESC;


-- ============================================================================
-- D2: ATC supply per region — is Central low because there are simply
-- fewer ATC sites there? (demand vs supply question)
-- ============================================================================
SELECT
    COALESCE(r.REGION, 'Unmapped') AS REGION,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
        THEN a.D_PRIMARY_HCO_COMPILE_ID END) AS ATC_SITES,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
        THEN a.HCO_PARENT_NAME END) AS ATC_PARENTS,
    COUNT(DISTINCT a.D_PATIENT_ID) AS TOTAL_PATIENTS,
    ROUND(1.0 * COUNT(DISTINCT a.D_PATIENT_ID)
        / NULLIF(COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
            THEN a.D_PRIMARY_HCO_COMPILE_ID END), 0), 1) AS PATIENTS_PER_ATC_SITE
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
    ON a.PRIMARY_HCO_NPI_STATE = r.STATE
GROUP BY 1
ORDER BY TOTAL_PATIENTS DESC;


-- ============================================================================
-- D3: Where Central patients go instead — top non-ATC parents in Central
-- (who is absorbing the volume; potential outreach / future-ATC candidates)
-- ============================================================================
SELECT
    a.HCO_PARENT_NAME,
    COUNT(DISTINCT a.D_PATIENT_ID) AS PATIENTS,
    COUNT(DISTINCT a.D_PRIMARY_HCO_COMPILE_ID) AS DISTINCT_HCOS,
    ROUND(100.0 * COUNT(DISTINCT a.D_PATIENT_ID)
        / SUM(COUNT(DISTINCT a.D_PATIENT_ID)) OVER (), 1) AS PCT_OF_CENTRAL_NON_ATC
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
INNER JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
    ON a.PRIMARY_HCO_NPI_STATE = r.STATE
WHERE r.REGION = 'Central'
  AND a.CLASS_FINAL LIKE 'Non-ATC%'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;


-- ============================================================================
-- E: Sample patient journeys — 3 random patients from the migration cohort
-- (started Non-ATC, classified ATC). Full claim history per patient.
-- Kolin's note from Meet 5: expect null values on many fields.
-- ============================================================================
WITH first_site AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO AS FIRST_ATC
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    QUALIFY ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
        ORDER BY DATE_OF_SERVICE, D_PRIMARY_HCO_COMPILE_ID) = 1
),
sample_migrants AS (
    SELECT c.D_PATIENT_ID
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL c
    INNER JOIN first_site fs ON c.D_PATIENT_ID = fs.D_PATIENT_ID
    WHERE c.CLASS_FINAL = 'ATC'
      AND fs.FIRST_ATC = 0
    ORDER BY RANDOM()
    LIMIT 3
)
SELECT
    t.D_PATIENT_ID,
    t.DATE_OF_SERVICE,
    t.DRUG,
    CASE WHEN t.IS_ATC_HCO = 1 THEN 'ATC' ELSE 'Non-ATC' END AS SITE_TYPE,
    t.D_PRIMARY_HCO_COMPILE_ID,
    t.FIRST_DX_DATE,
    DATEDIFF("day", t.FIRST_DX_DATE, t.DATE_OF_SERVICE) AS DAYS_SINCE_DX
FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS t
INNER JOIN sample_migrants s ON t.D_PATIENT_ID = s.D_PATIENT_ID
ORDER BY t.D_PATIENT_ID, t.DATE_OF_SERVICE;
/*Disease considered: mMelanoma
Diagnosis Code (ICD 10): '%C43%', '%C77%', '%C78%', '%C79%'
Drugs Considered:
Yervoy (Ipilimumab), Opdualag (nivolumab & relatlimab-rmbw), Keytruda (pembrolizumab),
Proleukin (aldesleukin), Opdivo (nivolumab), Tecentriq (Atezolizumab),
Imlygic (talimogene laherparepvec), Dacarbazine (DTIC-Dome)

Purpose (Board ask - "Add site of care: ATC vs non-ATC"):
Of Diagnosised & Treated mMelanoma patients (2021-2025), what % are treated at:
    - ATC
    - Non-ATC > Hospital-affiliated
    - Non-ATC > LCP / Physician-Owned (e.g. FL Cancer, TX Oncology)
    - Non-ATC > Stand-alone private practice
Output is pie-ready: one row per category with patient count and % of total.

Run order:
  QUERY 0 (once)  - discover the real HCO_TYPE values so the 3 non-ATC buckets
                    can be mapped accurately. Adjust the CASE in Q1/Q2 if needed.
  QUERY 1         - HEADLINE pie data (TOP_LEVEL + detailed CENTER_TYPE).
  QUERY 2         - per-HCO drill-down + sense-check.

Confirm with KK (marked --CONFIRM): ATC list (Authorized only), HCO vs PARENT
match level, Full vs Field drug universe, and the 3 non-ATC bucket definitions.
*/


/* =========================================================================
   QUERY 0 - DISCOVERY (run once): what center types do non-ATC treated
   centers actually have? Use this to confirm the 3 non-ATC buckets below.
   ========================================================================= */

WITH TREATED_HCOS AS 
(
SELECT DISTINCT 
    D_PRIMARY_HCO_COMPILE_ID
FROM 
    COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
WHERE 
    D_NDC_CODE IN ('00003232711','00003232822','00003712511','00006302602',
        '00006302604','00006302902','07377602201','00003377211','00003377412',
        '00003373413','00502420917','00555130079','00633230128')
    OR D_PROCEDURE_CODE IN ('J9228','J9298','J9271','J9299','J9022','J9325','J9130')
)
SELECT 
    H.HCO_TYPE,
    H.HCO_TYPE_LEVEL_1,
    H.HCO_ACADEMIC_FLAG,
    H.HCO_COMMUNITY_NETWORK,
    COUNT(*) AS HCO_COUNT
FROM 
    TREATED_HCOS T
LEFT JOIN 
    COMPILE_PROVIDER360.ENTITIES.IOV2501_HCO_ATTRIBUTES H
    ON T.D_PRIMARY_HCO_COMPILE_ID = H.D_HCO_COMPILE_ID
GROUP BY 
    1,2,3,4
ORDER BY 
    HCO_COUNT DESC
;



/* =========================================================================
   QUERY 1 - HEADLINE: pie-ready site-of-care split (THE deliverable)
   ========================================================================= */

WITH DIAGNOSED_PATIENTS AS 
(
SELECT 
    D_PATIENT_ID
FROM 
    COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
WHERE 
    D_PATIENT_ID <> 'XXX - HIDDEN'
    AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%C43%')
    AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%C77%', '%C78%', '%C79%')
    AND YEAR(DATE_OF_SERVICE) in (2021, 2022, 2023, 2024, 2025)
),

TREATED_PATIENTS AS                  --CONFIRM: Full Universe (8 drugs); for Field Universe keep only Yervoy/Opdualag
(
SELECT 
    D_PATIENT_ID,
    D_PRIMARY_HCO_COMPILE_ID,
    PRIMARY_HCO_NPI_NAME,
    D_HCO_PARENT_COMPILE_ID,
    HCO_PARENT_NAME,
    PRIMARY_HCO_NPI_STATE,
    DATE_OF_SERVICE
FROM 
    COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
WHERE 
    D_NDC_CODE IN 
    (
        '00003232711', /*Yervoy*/    '00003232822', /*Yervoy*/    '00003712511', /*Opdualag*/
        '00006302602', /*Keytruda*/  '00006302604', /*Keytruda*/  '00006302902', /*Keytruda*/
        '07377602201', /*Proleukin*/ '00003377211', /*Opdivo*/    '00003377412', /*Opdivo*/
        '00003373413', /*Opdivo*/    '00502420917', /*Tecentriq*/ '00555130079', /*Imlygic*/
        '00633230128'  /*Dacarbazine*/
    )
    OR D_PROCEDURE_CODE IN 
    (
        'J9228', /*Yervoy*/ 'J9298', /*Opdualag*/ 'J9271', /*Keytruda*/ 'J9299', /*Opdivo*/
        'J9022', /*Tecentriq*/ 'J9325', /*Imlygic*/ 'J9130' /*Dacarbazine*/
    )
),

DIAGNOSED_AND_TREATED AS 
(
SELECT 
    B.D_PATIENT_ID, B.D_PRIMARY_HCO_COMPILE_ID, B.PRIMARY_HCO_NPI_NAME,
    B.D_HCO_PARENT_COMPILE_ID, B.HCO_PARENT_NAME, B.PRIMARY_HCO_NPI_STATE, B.DATE_OF_SERVICE
FROM 
    DIAGNOSED_PATIENTS A
INNER JOIN 
    TREATED_PATIENTS B ON A.D_PATIENT_ID = B.D_PATIENT_ID
),

PATIENT_HCO_CLAIMS AS 
(
-- treatment claims per patient, per center
SELECT 
    D_PATIENT_ID,
    D_PRIMARY_HCO_COMPILE_ID,
    ANY_VALUE(PRIMARY_HCO_NPI_NAME) AS PRIMARY_HCO_NPI_NAME,
    ANY_VALUE(D_HCO_PARENT_COMPILE_ID) AS D_HCO_PARENT_COMPILE_ID,
    ANY_VALUE(HCO_PARENT_NAME) AS HCO_PARENT_NAME,
    ANY_VALUE(PRIMARY_HCO_NPI_STATE) AS PRIMARY_HCO_NPI_STATE,
    COUNT(*) AS TREATMENT_CLAIMS,
    MAX(DATE_OF_SERVICE) AS LAST_TREATMENT_DATE
FROM 
    DIAGNOSED_AND_TREATED
GROUP BY 
    D_PATIENT_ID, D_PRIMARY_HCO_COMPILE_ID
),

PATIENT_PRIMARY_HCO AS 
(
-- one row per patient = the center with the most treatment claims (tie-break: most recent)
SELECT *
FROM PATIENT_HCO_CLAIMS
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY D_PATIENT_ID
    ORDER BY TREATMENT_CLAIMS DESC, LAST_TREATMENT_DATE DESC, D_PRIMARY_HCO_COMPILE_ID
) = 1
),

ATC_REFERENCE AS 
(
-- CONFIRM: replace with KK's "CTAM ATC Alignment" tab. Count ONLY Authorized centers.
--   OPTION A: SELECT DISTINCT <id> AS ATC_COMPILE_ID FROM <ATC_TABLE> WHERE STATUS = 'Authorized'
--   OPTION B (inline): paste (compile_id, status) pairs below
SELECT ATC_COMPILE_ID
FROM (VALUES 
    ('PLACEHOLDER_ATC_ID_1','Authorized'),
    ('PLACEHOLDER_ATC_ID_2','Planned')
    -- ... add the remaining ATC compile IDs with their status
) AS V (ATC_COMPILE_ID, STATUS)
WHERE STATUS = 'Authorized'          -- Planned ATCs are not live yet -> excluded
),

PATIENT_CLASSIFIED AS 
(
-- Classify each patient's primary center.
-- ATC match is at HCO level (CONFIRM: switch join to D_HCO_PARENT_COMPILE_ID for parent level).
-- Non-ATC sub-types use HCO_TYPE / network (defaults below - refine using QUERY 0 output).
SELECT 
    P.D_PATIENT_ID,
    P.D_PRIMARY_HCO_COMPILE_ID,
    CASE 
        WHEN P.D_PRIMARY_HCO_COMPILE_ID IS NULL THEN 'Unmapped'
        WHEN R.ATC_COMPILE_ID IS NOT NULL       THEN 'ATC'
        ELSE 'non-ATC'
    END AS TOP_LEVEL,
    CASE 
        WHEN P.D_PRIMARY_HCO_COMPILE_ID IS NULL THEN 'Unmapped (no HCO)'
        WHEN R.ATC_COMPILE_ID IS NOT NULL       THEN 'ATC'
        WHEN H.HCO_TYPE ILIKE ANY ('%hospital%','%medical center%','%health system%','%university%','%academic%')
             THEN 'Non-ATC: Hospital-affiliated'
        WHEN H.HCO_COMMUNITY_NETWORK IS NOT NULL
          OR H.HCO_TYPE ILIKE ANY ('%oncology%','%cancer center%','%physician%','%group%','%network%')
             THEN 'Non-ATC: LCP / Physician-Owned'
        ELSE 'Non-ATC: Stand-alone private practice'
    END AS CENTER_TYPE
FROM 
    PATIENT_PRIMARY_HCO P
LEFT JOIN 
    ATC_REFERENCE R ON P.D_PRIMARY_HCO_COMPILE_ID = R.ATC_COMPILE_ID   --CONFIRM match level
LEFT JOIN 
    COMPILE_PROVIDER360.ENTITIES.IOV2501_HCO_ATTRIBUTES H ON P.D_PRIMARY_HCO_COMPILE_ID = H.D_HCO_COMPILE_ID
)

SELECT 
    TOP_LEVEL,
    CENTER_TYPE,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
        / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT_OF_TOTAL
FROM 
    PATIENT_CLASSIFIED
GROUP BY 
    TOP_LEVEL, CENTER_TYPE
ORDER BY 
    CASE CENTER_TYPE
        WHEN 'ATC' THEN 1
        WHEN 'Non-ATC: Hospital-affiliated' THEN 2
        WHEN 'Non-ATC: LCP / Physician-Owned' THEN 3
        WHEN 'Non-ATC: Stand-alone private practice' THEN 4
        ELSE 5
    END
;



/* =========================================================================
   QUERY 2 - PER-HCO DRILL-DOWN (which centers sit in each bucket; sense-check)
   ========================================================================= */

WITH DIAGNOSED_PATIENTS AS 
(
SELECT D_PATIENT_ID
FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
WHERE D_PATIENT_ID <> 'XXX - HIDDEN'
  AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%C43%')
  AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%C77%', '%C78%', '%C79%')
  AND YEAR(DATE_OF_SERVICE) in (2021, 2022, 2023, 2024, 2025)
),

TREATED_PATIENTS AS 
(
SELECT D_PATIENT_ID, D_PRIMARY_HCO_COMPILE_ID, PRIMARY_HCO_NPI_NAME,
       D_HCO_PARENT_COMPILE_ID, HCO_PARENT_NAME, PRIMARY_HCO_NPI_STATE, DATE_OF_SERVICE
FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
WHERE D_NDC_CODE IN ('00003232711','00003232822','00003712511','00006302602',
        '00006302604','00006302902','07377602201','00003377211','00003377412',
        '00003373413','00502420917','00555130079','00633230128')
   OR D_PROCEDURE_CODE IN ('J9228','J9298','J9271','J9299','J9022','J9325','J9130')
),

DIAGNOSED_AND_TREATED AS 
(
SELECT B.D_PATIENT_ID, B.D_PRIMARY_HCO_COMPILE_ID, B.PRIMARY_HCO_NPI_NAME,
       B.D_HCO_PARENT_COMPILE_ID, B.HCO_PARENT_NAME, B.PRIMARY_HCO_NPI_STATE, B.DATE_OF_SERVICE
FROM DIAGNOSED_PATIENTS A
INNER JOIN TREATED_PATIENTS B ON A.D_PATIENT_ID = B.D_PATIENT_ID
),

PATIENT_HCO_CLAIMS AS 
(
SELECT D_PATIENT_ID, D_PRIMARY_HCO_COMPILE_ID,
       ANY_VALUE(PRIMARY_HCO_NPI_NAME) AS PRIMARY_HCO_NPI_NAME,
       ANY_VALUE(D_HCO_PARENT_COMPILE_ID) AS D_HCO_PARENT_COMPILE_ID,
       ANY_VALUE(HCO_PARENT_NAME) AS HCO_PARENT_NAME,
       ANY_VALUE(PRIMARY_HCO_NPI_STATE) AS PRIMARY_HCO_NPI_STATE,
       COUNT(*) AS TREATMENT_CLAIMS, MAX(DATE_OF_SERVICE) AS LAST_TREATMENT_DATE
FROM DIAGNOSED_AND_TREATED
GROUP BY D_PATIENT_ID, D_PRIMARY_HCO_COMPILE_ID
),

PATIENT_PRIMARY_HCO AS 
(
SELECT *
FROM PATIENT_HCO_CLAIMS
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY D_PATIENT_ID
    ORDER BY TREATMENT_CLAIMS DESC, LAST_TREATMENT_DATE DESC, D_PRIMARY_HCO_COMPILE_ID
) = 1
),

ATC_REFERENCE AS 
(
SELECT ATC_COMPILE_ID
FROM (VALUES 
    ('PLACEHOLDER_ATC_ID_1','Authorized'),
    ('PLACEHOLDER_ATC_ID_2','Planned')
) AS V (ATC_COMPILE_ID, STATUS)
WHERE STATUS = 'Authorized'
),

PATIENT_CLASSIFIED AS 
(
SELECT 
    P.D_PATIENT_ID,
    P.D_PRIMARY_HCO_COMPILE_ID,
    P.PRIMARY_HCO_NPI_NAME,
    P.HCO_PARENT_NAME,
    P.PRIMARY_HCO_NPI_STATE,
    H.HCO_TYPE,
    H.HCO_COMMUNITY_NETWORK,
    CASE 
        WHEN P.D_PRIMARY_HCO_COMPILE_ID IS NULL THEN 'Unmapped (no HCO)'
        WHEN R.ATC_COMPILE_ID IS NOT NULL       THEN 'ATC'
        WHEN H.HCO_TYPE ILIKE ANY ('%hospital%','%medical center%','%health system%','%university%','%academic%')
             THEN 'Non-ATC: Hospital-affiliated'
        WHEN H.HCO_COMMUNITY_NETWORK IS NOT NULL
          OR H.HCO_TYPE ILIKE ANY ('%oncology%','%cancer center%','%physician%','%group%','%network%')
             THEN 'Non-ATC: LCP / Physician-Owned'
        ELSE 'Non-ATC: Stand-alone private practice'
    END AS CENTER_TYPE
FROM 
    PATIENT_PRIMARY_HCO P
LEFT JOIN 
    ATC_REFERENCE R ON P.D_PRIMARY_HCO_COMPILE_ID = R.ATC_COMPILE_ID
LEFT JOIN 
    COMPILE_PROVIDER360.ENTITIES.IOV2501_HCO_ATTRIBUTES H ON P.D_PRIMARY_HCO_COMPILE_ID = H.D_HCO_COMPILE_ID
)

SELECT 
    CENTER_TYPE,
    D_PRIMARY_HCO_COMPILE_ID,
    PRIMARY_HCO_NPI_NAME,
    HCO_PARENT_NAME,
    PRIMARY_HCO_NPI_STATE,
    HCO_TYPE,
    HCO_COMMUNITY_NETWORK,
    COUNT(*) AS PATIENTS
FROM 
    PATIENT_CLASSIFIED
GROUP BY 
    1,2,3,4,5,6,7
ORDER BY 
    PATIENTS DESC
;
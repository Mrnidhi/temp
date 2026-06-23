/*Disease considered: mMelanoma
Diagnosis Code (ICD 10): '%IC43%', '%IC77%', '%IC78%', '%IC79%'
Drugs Considered:
Yervoy (Ipilimumab) - per NDC guidelines
Opdualag (nivolumab & relatlimab-rmbw) - per NDC guidelines
Keytruda (pembrolizumab) - per NDC guidelines
Proleukin (aldesleukin) - per NDC guidelines
Opdivo (nivolumab) - per NDC guidelines
Tecentriq (Atezolizumab) - per NDC guidelines
Imlygic (talimogene laherparepvec) - per NDC guidelines
Dacarbazine (DTIC-Dome) - listed as most popular Chemo

Purpose: Of Diagnosised & Treated mMelanoma patients (2021-2025), what % are
treated at an Authorized Treatment Center (ATC) vs a non-ATC center?

Extends the existing "Diagnosised & Treated Patients by HCO" query (Full Universe)
with two new CTEs:
    PATIENT_PRIMARY_HCO  - assigns each patient to ONE treating center, so a
                           patient seen at 2 centers is not counted twice
    PATIENT_CLASSIFIED   - labels that center ATC vs non-ATC

All column names verified against COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS.
Both HCO keys are carried through (D_PRIMARY_HCO_COMPILE_ID and
D_HCO_PARENT_COMPILE_ID) so the ATC match can be done at either level.

3 items to confirm with KK are marked  --CONFIRM
*/


/* =========================================================================
   QUERY 1 - HEADLINE: the ATC vs non-ATC split (this is the deliverable)
   ========================================================================= */

WITH DIAGNOSED_PATIENTS AS 
(
SELECT 
    D_PATIENT_ID
FROM 
    COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
WHERE 
    D_PATIENT_ID <> 'XXX - HIDDEN'
    AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%IC43%')
    AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%IC77%', '%IC78%', '%IC79%')
    AND YEAR(DATE_OF_SERVICE) in (2021, 2022, 2023, 2024, 2025)   --CONFIRM: 5yr window (was 2024,2025)
),

TREATED_PATIENTS AS 
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
WHERE                            --CONFIRM: Full Universe (8 drugs) below, or Field Universe (Yervoy/Opdualag only)
    D_NDC_CODE IN 
    (
        '00003232711', /*Yervoy*/
        '00003232822', /*Yervoy*/
        '00003712511', /*Opdualag*/
        '00006302602', /*Keytruda*/
        '00006302604', /*Keytruda*/
        '00006302902', /*Keytruda*/
        '07377602201', /*Proleukin*/
        '00003377211', /*Opdivo*/
        '00003377412', /*Opdivo*/
        '00003373413', /*Opdivo*/
        '00502420917', /*Tecentriq*/
        '00555130079', /*Imlygic*/
        '00633230128' /*Dacarbazine*/
    )
    OR D_PROCEDURE_CODE IN 
    (
        'J9228', /*Yervoy*/
        'J9298', /*Opdualag*/
        'J9271', /*Keytruda*/
        'J9299', /*Opdivo*/
        'J9022', /*Tecentriq*/
        'J9325', /*Imlygic*/
        'J9130' /*Dacarbazine*/
    )
),

DIAGNOSED_AND_TREATED AS 
(
-- Same Diagnosised & Treated join you already use, kept at patient/claim grain
SELECT 
    B.D_PATIENT_ID,
    B.D_PRIMARY_HCO_COMPILE_ID,
    B.PRIMARY_HCO_NPI_NAME,
    B.D_HCO_PARENT_COMPILE_ID,
    B.HCO_PARENT_NAME,
    B.PRIMARY_HCO_NPI_STATE,
    B.DATE_OF_SERVICE
FROM 
    DIAGNOSED_PATIENTS A
INNER JOIN 
    TREATED_PATIENTS B
    ON A.D_PATIENT_ID = B.D_PATIENT_ID
),

PATIENT_HCO_CLAIMS AS 
(
-- NEW: treatment claims per patient, per center
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
-- NEW: keep ONE row per patient = the center with the most treatment claims
-- (tie-break: most recent). Prevents counting a patient at two centers.
-- For a "most-recent-center" rule instead, lead the ORDER BY with LAST_TREATMENT_DATE DESC.
SELECT 
    *
FROM 
    PATIENT_HCO_CLAIMS
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY D_PATIENT_ID
    ORDER BY TREATMENT_CLAIMS DESC, LAST_TREATMENT_DATE DESC, D_PRIMARY_HCO_COMPILE_ID
) = 1
),

ATC_REFERENCE AS 
(
-- CONFIRM: replace with KK's real ATC list (the ATC alignment tab).
--   OPTION A (preferred): SELECT DISTINCT <id col> AS ATC_COMPILE_ID FROM <ATC_TABLE>
--   OPTION B (inline): paste the ~90 ATC HCO (or parent) compile IDs below
SELECT 
    ATC_COMPILE_ID
FROM (VALUES 
    ('PLACEHOLDER_ATC_ID_1'),
    ('PLACEHOLDER_ATC_ID_2')
    -- ... add the remaining ATC compile IDs
) AS V (ATC_COMPILE_ID)
),

PATIENT_CLASSIFIED AS 
(
-- NEW: label each patient's center ATC vs non-ATC.
-- Default join is at the HCO level (D_PRIMARY_HCO_COMPILE_ID).
-- CONFIRM match level: if KK wants PARENT-level, change the join key below to
--   ON P.D_HCO_PARENT_COMPILE_ID = R.ATC_COMPILE_ID
SELECT 
    P.D_PATIENT_ID,
    P.D_PRIMARY_HCO_COMPILE_ID,
    P.PRIMARY_HCO_NPI_NAME,
    P.D_HCO_PARENT_COMPILE_ID,
    P.HCO_PARENT_NAME,
    P.PRIMARY_HCO_NPI_STATE,
    CASE 
        WHEN P.D_PRIMARY_HCO_COMPILE_ID IS NULL THEN 'Unmapped (no HCO)'
        WHEN R.ATC_COMPILE_ID IS NOT NULL THEN 'ATC'
        ELSE 'non-ATC'
    END AS CENTER_TYPE
FROM 
    PATIENT_PRIMARY_HCO P
LEFT JOIN 
    ATC_REFERENCE R
    ON P.D_PRIMARY_HCO_COMPILE_ID = R.ATC_COMPILE_ID   --CONFIRM match level (HCO id here vs parent id)
)

SELECT 
    CENTER_TYPE,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
        / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT_OF_TOTAL
FROM 
    PATIENT_CLASSIFIED
GROUP BY 
    CENTER_TYPE
ORDER BY 
    PATIENTS DESC
;



/* =========================================================================
   QUERY 2 - PER-HCO BREAKDOWN (for the non-ATC drill-down + sense-checking)
   Same CTE chain, final SELECT lists centers and LEFT JOINs HCO attributes.
   (Re-stating the CTEs keeps each query self-contained, same as your other files.)
   ========================================================================= */

WITH DIAGNOSED_PATIENTS AS 
(
SELECT 
    D_PATIENT_ID
FROM 
    COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
WHERE 
    D_PATIENT_ID <> 'XXX - HIDDEN'
    AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%IC43%')
    AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%IC77%', '%IC78%', '%IC79%')
    AND YEAR(DATE_OF_SERVICE) in (2021, 2022, 2023, 2024, 2025)
),

TREATED_PATIENTS AS 
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
        '00003232711', /*Yervoy*/
        '00003232822', /*Yervoy*/
        '00003712511', /*Opdualag*/
        '00006302602', /*Keytruda*/
        '00006302604', /*Keytruda*/
        '00006302902', /*Keytruda*/
        '07377602201', /*Proleukin*/
        '00003377211', /*Opdivo*/
        '00003377412', /*Opdivo*/
        '00003373413', /*Opdivo*/
        '00502420917', /*Tecentriq*/
        '00555130079', /*Imlygic*/
        '00633230128' /*Dacarbazine*/
    )
    OR D_PROCEDURE_CODE IN 
    (
        'J9228', /*Yervoy*/
        'J9298', /*Opdualag*/
        'J9271', /*Keytruda*/
        'J9299', /*Opdivo*/
        'J9022', /*Tecentriq*/
        'J9325', /*Imlygic*/
        'J9130' /*Dacarbazine*/
    )
),

DIAGNOSED_AND_TREATED AS 
(
SELECT 
    B.D_PATIENT_ID,
    B.D_PRIMARY_HCO_COMPILE_ID,
    B.PRIMARY_HCO_NPI_NAME,
    B.D_HCO_PARENT_COMPILE_ID,
    B.HCO_PARENT_NAME,
    B.PRIMARY_HCO_NPI_STATE,
    B.DATE_OF_SERVICE
FROM 
    DIAGNOSED_PATIENTS A
INNER JOIN 
    TREATED_PATIENTS B
    ON A.D_PATIENT_ID = B.D_PATIENT_ID
),

PATIENT_HCO_CLAIMS AS 
(
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
SELECT 
    *
FROM 
    PATIENT_HCO_CLAIMS
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY D_PATIENT_ID
    ORDER BY TREATMENT_CLAIMS DESC, LAST_TREATMENT_DATE DESC, D_PRIMARY_HCO_COMPILE_ID
) = 1
),

ATC_REFERENCE AS 
(
SELECT 
    ATC_COMPILE_ID
FROM (VALUES 
    ('PLACEHOLDER_ATC_ID_1'),
    ('PLACEHOLDER_ATC_ID_2')
) AS V (ATC_COMPILE_ID)
),

PATIENT_CLASSIFIED AS 
(
SELECT 
    P.D_PATIENT_ID,
    P.D_PRIMARY_HCO_COMPILE_ID,
    P.PRIMARY_HCO_NPI_NAME,
    P.D_HCO_PARENT_COMPILE_ID,
    P.HCO_PARENT_NAME,
    P.PRIMARY_HCO_NPI_STATE,
    CASE 
        WHEN P.D_PRIMARY_HCO_COMPILE_ID IS NULL THEN 'Unmapped (no HCO)'
        WHEN R.ATC_COMPILE_ID IS NOT NULL THEN 'ATC'
        ELSE 'non-ATC'
    END AS CENTER_TYPE
FROM 
    PATIENT_PRIMARY_HCO P
LEFT JOIN 
    ATC_REFERENCE R
    ON P.D_PRIMARY_HCO_COMPILE_ID = R.ATC_COMPILE_ID
)

SELECT 
    C.CENTER_TYPE,
    C.D_PRIMARY_HCO_COMPILE_ID,
    C.PRIMARY_HCO_NPI_NAME,
    C.HCO_PARENT_NAME,
    C.PRIMARY_HCO_NPI_STATE,
    H.HCO_TYPE,
    H.HCO_ACADEMIC_FLAG,
    H.HCO_COMMUNITY_NETWORK,
    COUNT(*) AS PATIENTS
FROM 
    PATIENT_CLASSIFIED C
LEFT JOIN 
    COMPILE_PROVIDER360.ENTITIES.IOV2501_HCO_ATTRIBUTES H
    ON C.D_PRIMARY_HCO_COMPILE_ID = H.HCO_COMPILE_ID
GROUP BY 
    1,2,3,4,5,6,7,8
ORDER BY 
    9 DESC
;
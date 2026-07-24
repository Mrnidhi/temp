/*Disease considered: mMelanoma
Diagnosis Code (ICD 10): '%C43%', '%C77%', '%C78%', '%C79%'
Drugs Considered: Yervoy (Ipilimumab) & Opdualag (nivolumab & relatlimab-rmbw)
NDC Codes:
'00003232711' Yervoy
'00003232822' Yervoy
'00003712511' Opdualag
HCPCS Codes: 'J9228' Yervoy & 'J9298' Opdualag

Site of care for diagnosed & treated patients, 2021-2025: ATC vs non-ATC, with
non-ATC split into hospital-affiliated / physician-owned / private practice.
Each patient counts once, at the center where they were treated the most.

ATC list comes from the CTAM ATC Alignment CSV loaded as a table. There is no
compile ID in that file, so ATCs are matched on parent name:
  ATC "HCO Parent Name (McKesson Claims)"  ->  claims HCO_PARENT_NAME
Set @ATC_TABLE below to wherever the CSV is loaded.
*/

-- Point this at the loaded ATC table (skip the 4 preamble rows on load, header on row 5)
-- e.g. COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026

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

TREATED_PATIENTS AS 
(
SELECT 
    D_PATIENT_ID,
    D_PRIMARY_HCO_COMPILE_ID,
    HCO_PARENT_NAME,
    DATE_OF_SERVICE
FROM 
    COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
WHERE 
    D_NDC_CODE IN ('00003232711', '00003232822', '00003712511')
    OR D_PROCEDURE_CODE IN ('J9228', 'J9298')
),

PATIENT_HCO AS 
(
SELECT 
    A.D_PATIENT_ID,
    B.D_PRIMARY_HCO_COMPILE_ID,
    B.HCO_PARENT_NAME,
    COUNT(*) AS TREATMENT_CLAIMS,
    MAX(B.DATE_OF_SERVICE) AS LAST_TREATMENT
FROM 
    DIAGNOSED_PATIENTS A
INNER JOIN 
    TREATED_PATIENTS B ON A.D_PATIENT_ID = B.D_PATIENT_ID
GROUP BY 
    A.D_PATIENT_ID, B.D_PRIMARY_HCO_COMPILE_ID, B.HCO_PARENT_NAME
),

PATIENT_SITE AS 
(
-- one center per patient: most treatment claims, latest breaks ties
SELECT 
    D_PATIENT_ID,
    D_PRIMARY_HCO_COMPILE_ID,
    HCO_PARENT_NAME
FROM 
    PATIENT_HCO
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY D_PATIENT_ID 
    ORDER BY TREATMENT_CLAIMS DESC, LAST_TREATMENT DESC
) = 1
),

ATC_LIST AS 
(
-- Authorized ATC parent names from the loaded CSV (drop blanks/dashes, normalize case)
SELECT DISTINCT 
    UPPER(TRIM("ATC HCO Parent Name (McKesson Claims)")) AS ATC_PARENT_NAME
FROM 
    COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026          -- change to your loaded table
WHERE 
    Status = 'Authorized'
    AND "ATC HCO Parent Name (McKesson Claims)" NOT IN ('', '-')
    AND "ATC HCO Parent Name (McKesson Claims)" IS NOT NULL
)

SELECT 
    CASE 
        WHEN A.ATC_PARENT_NAME IS NOT NULL   THEN 'ATC'
        WHEN H.HCO_TYPE = 'HOSPITALS'        THEN 'Non-ATC: Hospital-affiliated'
        WHEN H.HCO_TYPE = 'PHYSICIAN GROUP'  THEN 'Non-ATC: Physician-owned'
        ELSE 'Non-ATC: Private practice'
    END AS SITE_OF_CARE,
    COUNT(*) AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM 
    PATIENT_SITE S
LEFT JOIN 
    ATC_LIST A ON UPPER(TRIM(S.HCO_PARENT_NAME)) = A.ATC_PARENT_NAME
LEFT JOIN 
    COMPILE_PROVIDER360.ENTITIES.IOV2501_HCO_ATTRIBUTES H 
    ON S.D_PRIMARY_HCO_COMPILE_ID = H.D_HCO_COMPILE_ID
GROUP BY 
    1
ORDER BY 
    PATIENTS DESC
;


/* ---------------------------------------------------------------------------
   CHECK A — ATC parent names that did NOT match any claims HCO_PARENT_NAME.
   Run after loading the ATC table. Whatever comes back is the fix-list: tidy
   those names (spelling/punctuation) so they match, then rerun the split.
   --------------------------------------------------------------------------- */

SELECT 
    A.ATC_PARENT_NAME
FROM 
    (
    SELECT DISTINCT UPPER(TRIM("ATC HCO Parent Name (McKesson Claims)")) AS ATC_PARENT_NAME
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026         -- change to your loaded table
    WHERE Status = 'Authorized'
      AND "ATC HCO Parent Name (McKesson Claims)" NOT IN ('', '-')
      AND "ATC HCO Parent Name (McKesson Claims)" IS NOT NULL
    ) A
LEFT JOIN 
    (
    SELECT DISTINCT UPPER(TRIM(HCO_PARENT_NAME)) AS P
    FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
    ) C ON A.ATC_PARENT_NAME = C.P
WHERE 
    C.P IS NULL
;


/* ---------------------------------------------------------------------------
   CHECK B — how many Authorized ATCs have NO usable parent name (blank/dash).
   These cannot be matched and will fall into non-ATC. Report this number to KK
   as a known undercount of ATC share (a limit of the source file, not the query).
   --------------------------------------------------------------------------- */

SELECT 
    COUNT(*) AS authorized_atcs,
    COUNT(CASE WHEN "ATC HCO Parent Name (McKesson Claims)" IN ('', '-') 
                 OR "ATC HCO Parent Name (McKesson Claims)" IS NULL 
               THEN 1 END) AS authorized_atcs_no_parent_name
FROM 
    COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026             -- change to your loaded table
WHERE 
    Status = 'Authorized'
;
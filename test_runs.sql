-- Do diagnosed AND treated overlap at all?
WITH DIAGNOSED_PATIENTS AS (
    SELECT DISTINCT D_PATIENT_ID
    FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
    WHERE D_PATIENT_ID <> 'XXX - HIDDEN'
      AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%IC43%')
      AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%IC77%','%IC78%','%IC79%')
      AND YEAR(DATE_OF_SERVICE) IN (2021,2022,2023,2024,2025)
),
TREATED_PATIENTS AS (
    SELECT DISTINCT D_PATIENT_ID
    FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
    WHERE D_NDC_CODE IN ('00003232711','00003232822','00003712511','00006302602',
        '00006302604','00006302902','07377602201','00003377211','00003377412',
        '00003373413','00502420917','00555130079','00633230128')
       OR D_PROCEDURE_CODE IN ('J9228','J9298','J9271','J9299','J9022','J9325','J9130')
)
SELECT COUNT(*) AS both_diagnosed_and_treated
FROM DIAGNOSED_PATIENTS A
INNER JOIN TREATED_PATIENTS B ON A.D_PATIENT_ID = B.D_PATIENT_ID;



-- VERSION A: with the I prefix (what your query file currently uses)
WITH DIAGNOSED_PATIENTS AS (
    SELECT DISTINCT D_PATIENT_ID
    FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
    WHERE D_PATIENT_ID <> 'XXX - HIDDEN'
      AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%IC43%')
      AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%IC77%','%IC78%','%IC79%')
      AND YEAR(DATE_OF_SERVICE) IN (2021,2022,2023,2024,2025)
)
SELECT COUNT(*) AS diagnosed_with_I FROM DIAGNOSED_PATIENTS;




-- VERSION B: without the I prefix
WITH DIAGNOSED_PATIENTS AS (
    SELECT DISTINCT D_PATIENT_ID
    FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
    WHERE D_PATIENT_ID <> 'XXX - HIDDEN'
      AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%C43%')
      AND D_DIAGNOSIS_CODE_ALL ILIKE ANY ('%C77%','%C78%','%C79%')
      AND YEAR(DATE_OF_SERVICE) IN (2021,2022,2023,2024,2025)
)
SELECT COUNT(*) AS diagnosed_without_I FROM DIAGNOSED_PATIENTS;


SELECT HCO_TYPE, HCO_TYPE_LEVEL_1, HCO_LEGAL_ENTITY_TYPE,
       HCO_ACADEMIC_FLAG, COUNT(*) AS HCOS
FROM COMPILE_PROVIDER360.ENTITIES.IOV2501_HCO_ATTRIBUTES
GROUP BY 1,2,3,4 ORDER BY HCOS DESC LIMIT 100;

SELECT D_DIAGNOSIS_CODE_ALL
FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
WHERE D_DIAGNOSIS_CODE_ALL ILIKE '%C43%' LIMIT 10;



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
*/

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
    COUNT(*) AS TREATMENT_CLAIMS,
    MAX(B.DATE_OF_SERVICE) AS LAST_TREATMENT
FROM 
    DIAGNOSED_PATIENTS A
INNER JOIN 
    TREATED_PATIENTS B ON A.D_PATIENT_ID = B.D_PATIENT_ID
GROUP BY 
    A.D_PATIENT_ID, B.D_PRIMARY_HCO_COMPILE_ID
),

PATIENT_SITE AS 
(
-- one center per patient: where they had the most treatment claims, latest breaks ties
SELECT 
    D_PATIENT_ID,
    D_PRIMARY_HCO_COMPILE_ID
FROM 
    PATIENT_HCO
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY D_PATIENT_ID 
    ORDER BY TREATMENT_CLAIMS DESC, LAST_TREATMENT DESC
) = 1
),

ATC_LIST AS 
(
-- waiting on Kolin for the CTAM ATC Alignment list (Authorized centers only).
-- drop the real compile IDs in here, or point this at the table once it's loaded.
SELECT ATC_COMPILE_ID
FROM (VALUES ('')) AS V (ATC_COMPILE_ID)
)

SELECT 
    CASE 
        WHEN A.ATC_COMPILE_ID IS NOT NULL    THEN 'ATC'
        WHEN H.HCO_TYPE = 'HOSPITALS'        THEN 'Non-ATC: Hospital-affiliated'
        WHEN H.HCO_TYPE = 'PHYSICIAN GROUP'  THEN 'Non-ATC: Physician-owned'
        ELSE 'Non-ATC: Private practice'
    END AS SITE_OF_CARE,
    COUNT(*) AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM 
    PATIENT_SITE S
LEFT JOIN 
    ATC_LIST A ON S.D_PRIMARY_HCO_COMPILE_ID = A.ATC_COMPILE_ID
LEFT JOIN 
    COMPILE_PROVIDER360.ENTITIES.IOV2501_HCO_ATTRIBUTES H ON S.D_PRIMARY_HCO_COMPILE_ID = H.D_HCO_COMPILE_ID
GROUP BY 
    1
ORDER BY 
    PATIENTS DESC
;



/* 

I have an Excel file open with our Authorized Treatment Center (ATC) list. I need to describe its structure precisely to a colleague who will use it to join against medical claims data in Snowflake. Please look at the file and tell me:

1. SHEET NAMES: List every tab/sheet in the workbook. For each, one line on what it appears to contain.

2. For the main ATC tab (the one with the list of treatment centers), give me:
   a. The exact column headers, in order, written exactly as they appear (including any spaces, slashes, or parentheses).
   b. For each column, what it contains and an example value or two from the data rows.
   c. The total number of ATC rows (centers) listed.

3. ID COLUMNS — this is the most important part: Identify any column that looks like an identifier that could join to claims data. I'm specifically looking for:
   - An HCO "compile ID" (a long numeric or alphanumeric internal ID)
   - An NPI (10-digit number)
   - Anything labeled "McKesson", "Compile", "HCO", or "ID"
   For each such column, give the header name exactly and 2-3 example values.

4. STATUS: Is there a column indicating whether each center is "Authorized" vs "Planned" (or similar)? Give the exact column name and list all the distinct values that appear in it, with a rough count of each.

5. PARENT vs SITE: Does the list represent individual treatment centers (sites), or parent organizations, or both? For example, is something like "Texas Oncology" or "Florida Cancer" shown as one single row (a parent), or as many separate rows (individual locations)? Tell me which, and point to any column that distinguishes parent from site.

6. NAME COLUMNS: List any columns containing center names, and note if there's both a full/legal name and a short/abbreviated name.

7. Anything else notable — extra columns (region, CTAM/RAD assignment, state, etc.), blank/missing values, or anything that looks inconsistent.

Please present this as plain text I can copy, not a summary paragraph. Exact column names matter most.

*/
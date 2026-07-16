/* Run all three. They tell us exactly why 2B is empty. */

-- D1) Did the rebuild actually happen?
--     If ATC_COUNT = 6935 the table was NOT rebuilt (run STEP 1 first).
--     If ATC_COUNT = 7501 it was rebuilt and the problem is name matching.
SELECT
    COUNT(DISTINCT CASE WHEN CLASS_FINAL = 'ATC' THEN D_PATIENT_ID END) AS ATC_COUNT,
    COUNT(DISTINCT CASE WHEN CLASS_HYBRID = 'ATC: roster gap corrected'
                        THEN D_PATIENT_ID END)                          AS GAP_CORRECTED_COUNT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL;


-- D2) What are the EXACT parent strings in the source table?
--     LEN catches trailing spaces or hidden characters that would break the
--     exact-match join. Compare these against the four names in STEP 1.
SELECT DISTINCT
    HCO_PARENT_NAME,
    LENGTH(HCO_PARENT_NAME)        AS LEN,
    UPPER(TRIM(HCO_PARENT_NAME))   AS NORMALISED
FROM COMPILE_DEV.PUBLIC.ATC_SOC_PATIENT_CLASSIFIED_2021_2025
WHERE UPPER(HCO_PARENT_NAME) LIKE '%CITY OF HOPE%'
   OR UPPER(HCO_PARENT_NAME) LIKE '%LANGONE%'
   OR UPPER(HCO_PARENT_NAME) LIKE '%WEXNER%'
   OR UPPER(HCO_PARENT_NAME) LIKE '%HOAG%';


-- D3) Does the community-network branch steal them? (the Step 0 check)
--     Any of the three named networks here means those patients stay Non-ATC
--     no matter what, because that branch is evaluated first.
SELECT
    UPPER(TRIM(HCO_PARENT_NAME))  AS PARENT,
    HCO_COMMUNITY_NETWORK,
    COUNT(DISTINCT D_PATIENT_ID)  AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_SOC_PATIENT_CLASSIFIED_2021_2025
WHERE UPPER(TRIM(HCO_PARENT_NAME)) IN (
        'CITY OF HOPE',
        'NYU LANGONE HEALTH SYSTEM',
        'THE OHIO STATE UNIVERSITY WEXNER MEDICAL CENTER',
        'HOAG HOSPITAL NEWPORT BEACH')
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
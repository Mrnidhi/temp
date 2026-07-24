/* PHASE 1 INSIGHT PROBES - capture / expand / partner (staged 07/24).
   Run in SNOWFLAKE, paste back ALL rows of A, B, C, D.
   Uses only verified columns of COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL.
   Active windows anchor to the data's own cutoff, never CURRENT_DATE.

   What each probe tests:
   A - how much of "non-ATC" is billing/attribution artifact (imaging, lab, diagnostic)
   B - how much of "non-ATC" is structurally unaddressable (VA, Kaiser, no parent)
   C - which states hold non-ATC volume (diff against roster states = white space)
   D - which ATC parents run the biggest satellite funnels (PPR tie + Tim's "effort") */

-- A: ARTIFACT SCREEN. Non-ATC parents by HCO_TYPE, artifact-suspect types flagged.
SELECT
    HCO_TYPE,
    CASE WHEN UPPER(COALESCE(HCO_TYPE,'')) LIKE '%IMAG%'
      OR UPPER(COALESCE(HCO_TYPE,'')) LIKE '%LAB%'
      OR UPPER(COALESCE(HCO_TYPE,'')) LIKE '%DIAGNOST%'
      OR UPPER(COALESCE(HCO_TYPE,'')) LIKE '%PHARMAC%'
      THEN 1 ELSE 0 END                     AS ARTIFACT_SUSPECT,
    COUNT(DISTINCT D_PATIENT_ID)            AS PATIENTS,
    COUNT(DISTINCT HCO_PARENT_NAME)         AS PARENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL LIKE 'Non-ATC%'
GROUP BY 1, 2
ORDER BY PATIENTS DESC;

-- A2: the artifact-suspect parents by name (to eyeball, e.g. Clearview)
SELECT HCO_PARENT_NAME, MAX(HCO_TYPE) AS HCO_TYPE,
       COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL LIKE 'Non-ATC%'
  AND ( UPPER(COALESCE(HCO_TYPE,'')) LIKE '%IMAG%' OR UPPER(COALESCE(HCO_TYPE,'')) LIKE '%LAB%'
     OR UPPER(COALESCE(HCO_TYPE,'')) LIKE '%DIAGNOST%' OR UPPER(COALESCE(HCO_TYPE,'')) LIKE '%PHARMAC%'
     OR UPPER(COALESCE(HCO_PARENT_NAME,'')) LIKE '%IMAGING%' OR UPPER(COALESCE(HCO_PARENT_NAME,'')) LIKE '%DIAGNOSTIC%' )
GROUP BY 1 HAVING COUNT(DISTINCT D_PATIENT_ID) >= 5
ORDER BY PATIENTS DESC;

-- B: ADDRESSABILITY. Structurally hard vs winnable non-ATC.
SELECT
    CASE
      WHEN HCO_PARENT_NAME IS NULL THEN '1 No parent (unattributable)'
      WHEN UPPER(HCO_PARENT_NAME) LIKE '%VETERANS%' OR UPPER(HCO_PARENT_NAME) LIKE '%U.S. DEPARTMENT%'
        THEN '2 VA / federal (unaddressable)'
      WHEN UPPER(HCO_PARENT_NAME) LIKE '%KAISER%' OR UPPER(HCO_PARENT_NAME) LIKE '%PERMANENTE%'
        THEN '3 Kaiser closed system (hard)'
      ELSE '4 Addressable pool'
    END                                     AS BUCKET,
    COUNT(DISTINCT D_PATIENT_ID)            AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL LIKE 'Non-ATC%'
GROUP BY 1 ORDER BY 1;

-- C: STATE WHITE SPACE. Where the non-ATC volume sits.
SELECT HCO_STATE, COUNT(DISTINCT D_PATIENT_ID) AS NON_ATC_PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL LIKE 'Non-ATC%'
GROUP BY 1 HAVING COUNT(DISTINCT D_PATIENT_ID) >= 25
ORDER BY NON_ATC_PATIENTS DESC;

-- D: SATELLITE FUNNELS. Per ATC parent: primary vs satellite mix.
SELECT
    HCO_PARENT_NAME                          AS ATC_PARENT,
    COUNT(DISTINCT CASE WHEN CLASS_HYBRID = 'ATC: NPI confirmed' THEN D_PATIENT_ID END) AS PRIMARY_CONFIRMED,
    COUNT(DISTINCT CASE WHEN CLASS_HYBRID = 'ATC: name fallback' THEN D_PATIENT_ID END) AS SATELLITE_ROLLUP,
    COUNT(DISTINCT D_PATIENT_ID)             AS TOTAL,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN CLASS_HYBRID = 'ATC: name fallback' THEN D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT D_PATIENT_ID), 0), 1) AS SATELLITE_PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1 HAVING COUNT(DISTINCT D_PATIENT_ID) >= 25
ORDER BY SATELLITE_PCT DESC, TOTAL DESC;

-- E: the active census rerun lives in "Remaining insights - active census
--    expansion duration.sql" (fixed date anchor). Run it in the same sitting.

/* BRIDGE: prior (primary-only) analysis vs current (parent rollup) analysis.
   Run in SNOWFLAKE. Paste back all rows.

   The bridge assembles from Q1:
     primary only  = the NPI-confirmed tier of CLASS_HYBRID (expect near the old ~20% share)
     + satellites  = the name-matched / rollup tiers
     + roster adds = the ~399 confirmed on 07/23 (plus site-split results, separate file)
     = current total ATC */

-- Q1: patients by classification tier
SELECT
    CLASS_FINAL,
    CLASS_HYBRID,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1, 2
ORDER BY PATIENTS DESC;

-- Q2: sanity total (should be ~16,246)
SELECT COUNT(DISTINCT D_PATIENT_ID) AS TOTAL_PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL;

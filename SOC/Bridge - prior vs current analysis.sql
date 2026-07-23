/* BRIDGE: prior (primary-only) analysis vs current (parent rollup) analysis.
   Run in SNOWFLAKE. Paste back all rows.

   Q1 gives the classification tiers with patient counts. The bridge assembles from it:
     primary only  = the NPI-confirmed tier            (should land near the old ~20% share)
     + satellites  = the name-matched / rollup tiers
     + roster adds = the ~399 confirmed on 07/23 (plus site-split results, separate file)
     = current total ATC

   If a column name errors, run:  SELECT * FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL LIMIT 5;
   and use the actual names for the two classification columns. */

-- Q1: patients by classification tier and match basis
SELECT
    CLASS_HYBRID,
    MATCH_BASIS,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1, 2
ORDER BY PATIENTS DESC;

-- Q2: sanity total (should be ~16,246)
SELECT COUNT(DISTINCT D_PATIENT_ID) AS TOTAL_PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL;

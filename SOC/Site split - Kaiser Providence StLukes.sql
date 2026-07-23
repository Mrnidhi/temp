/* SITE SPLIT for the three system-level roster matches (07/23 reconciliation).
   Run in SNOWFLAKE. Paste back all rows.

   Kaiser Permanente (166 pts), Providence St. Joseph (85), St Luke's (10) matched the
   official roster at the SYSTEM level, but only one site in each system is authorized:
     Kaiser      -> Vallejo CA (Kaiser Permanente Vallejo Medical Center)
     Providence  -> Portland OR (Providence Portland Medical Center)
     St Luke's   -> Denver CO (Colorado Blood Cancer Institute at Presbyterian/St Luke's)

   This lists the site-level accounts and states under each parent so the authorized-site
   patients can be counted and the rest stay non-ATC.

   If a column name errors (site column may be HCO_NAME or similar), run:
   SELECT * FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL LIMIT 5;  and adjust. */

SELECT
    HCO_PARENT_NAME                        AS PARENT,
    HCO_NAME                               AS SITE,
    STATE,
    COUNT(DISTINCT D_PATIENT_ID)           AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL LIKE 'Non-ATC%'
  AND ( UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%KAISER%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%PROVIDENCE%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%ST%LUKE%' )
GROUP BY 1, 2, 3
ORDER BY PARENT, PATIENTS DESC;

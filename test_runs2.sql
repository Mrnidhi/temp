/* Run in SNOWFLAKE. Top non-ATC accounts within each region = a regional target
   list. Counts patients per region x parent (so a multi-state system lands in the
   region where its patients actually are). Uses NewCode.sql base tables.
   Paste back the output. */

-- Top 8 non-ATC accounts per region
WITH nonatc AS (
    SELECT
        COALESCE(r.REGION, 'Unmapped') AS REGION_NAME,
        COALESCE(NULLIF(TRIM(a.HCO_PARENT_NAME), ''), 'Unknown / unmapped') AS PARENT,
        COUNT(DISTINCT a.D_PATIENT_ID) AS PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
    LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
        ON a.PRIMARY_HCO_NPI_STATE = r.STATE
    WHERE a.CLASS_FINAL LIKE 'Non-ATC%'
    GROUP BY 1, 2
),
ranked AS (
    SELECT REGION_NAME, PARENT, PATIENTS,
           ROW_NUMBER() OVER (PARTITION BY REGION_NAME ORDER BY PATIENTS DESC) AS RN
    FROM nonatc
)
SELECT REGION_NAME, PARENT, PATIENTS
FROM ranked
WHERE RN <= 8
ORDER BY REGION_NAME, PATIENTS DESC;


-- Optional: non-ATC patients by state (top to bottom)
SELECT
    a.PRIMARY_HCO_NPI_STATE AS STATE,
    COALESCE(r.REGION, 'Unmapped') AS REGION_NAME,
    COUNT(DISTINCT a.D_PATIENT_ID) AS NON_ATC_PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
    ON a.PRIMARY_HCO_NPI_STATE = r.STATE
WHERE a.CLASS_FINAL LIKE 'Non-ATC%'
GROUP BY 1, 2
ORDER BY NON_ATC_PATIENTS DESC;
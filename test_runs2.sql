/* Run in SNOWFLAKE. Non-ATC target list by region and by state. Trimmed to top 3
   so it is quick to screenshot. Uses NewCode.sql base tables. Paste back both. */

-- 1) Top 3 non-ATC accounts per region (~21 rows)
WITH nonatc AS (
    SELECT
        COALESCE(r.REGION, 'Unmapped') AS REGION_NAME,
        COALESCE(NULLIF(TRIM(a.HCO_PARENT_NAME), ''), 'Unknown / unmapped') AS PARENT,
        COUNT(DISTINCT a.D_PATIENT_ID) AS PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
    LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
        ON a.PRIMARY_HCO_NPI_STATE = r.STATE
    WHERE a.CLASS_FINAL LIKE 'Non-ATC%'
    GROUP BY
        COALESCE(r.REGION, 'Unmapped'),
        COALESCE(NULLIF(TRIM(a.HCO_PARENT_NAME), ''), 'Unknown / unmapped')
),
ranked AS (
    SELECT REGION_NAME, PARENT, PATIENTS,
           ROW_NUMBER() OVER (PARTITION BY REGION_NAME ORDER BY PATIENTS DESC) AS RN
    FROM nonatc
)
SELECT REGION_NAME, PARENT, PATIENTS
FROM ranked
WHERE RN <= 3
ORDER BY REGION_NAME, PATIENTS DESC;


-- 2) Top 3 non-ATC accounts per state, states with 50+ non-ATC patients only
WITH nonatc AS (
    SELECT
        a.PRIMARY_HCO_NPI_STATE AS STATE,
        COALESCE(NULLIF(TRIM(a.HCO_PARENT_NAME), ''), 'Unknown / unmapped') AS PARENT,
        COUNT(DISTINCT a.D_PATIENT_ID) AS PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
    WHERE a.CLASS_FINAL LIKE 'Non-ATC%'
    GROUP BY
        a.PRIMARY_HCO_NPI_STATE,
        COALESCE(NULLIF(TRIM(a.HCO_PARENT_NAME), ''), 'Unknown / unmapped')
),
state_tot AS (
    SELECT STATE, SUM(PATIENTS) AS STATE_TOTAL FROM nonatc GROUP BY STATE
),
ranked AS (
    SELECT n.STATE, n.PARENT, n.PATIENTS, s.STATE_TOTAL,
           ROW_NUMBER() OVER (PARTITION BY n.STATE ORDER BY n.PATIENTS DESC) AS RN
    FROM nonatc n
    JOIN state_tot s ON n.STATE = s.STATE
)
SELECT STATE, PARENT, PATIENTS
FROM ranked
WHERE RN <= 3 AND STATE_TOTAL >= 50
ORDER BY STATE_TOTAL DESC, PATIENTS DESC;
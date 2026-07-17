/* Data for slides 6, 7, 8, 9 from the CORRECTED classification.
   Run after the roster-gap rebuild (ATC = 7,501). Each block is one result set.
   ATC = CLASS_FINAL = 'ATC'. Non-ATC = CLASS_FINAL LIKE 'Non-ATC%'.
   Penetration = ATC / (ATC + Non-ATC), Needs Review excluded from the rate. */


-- ============ SLIDE 6 - Regional opportunity (at-ATC vs untapped) ============
SELECT
    COALESCE(r.REGION, 'Unmapped') AS REGION_NAME,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'          THEN a.D_PATIENT_ID END) AS AT_ATC,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL LIKE 'Non-ATC%'  THEN a.D_PATIENT_ID END) AS UNTAPPED,
    COUNT(DISTINCT a.D_PATIENT_ID)                                                   AS TOTAL,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC' THEN a.D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
                                        OR a.CLASS_FINAL LIKE 'Non-ATC%'
                                       THEN a.D_PATIENT_ID END), 0), 1)              AS PENETRATION_PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
    ON a.PRIMARY_HCO_NPI_STATE = r.STATE
GROUP BY 1
ORDER BY UNTAPPED DESC;


-- ============ SLIDE 7 - State-level scatter (untapped vs penetration) ============
SELECT
    a.PRIMARY_HCO_NPI_STATE AS STATE,
    COALESCE(r.REGION, 'Unmapped') AS REGION_NAME,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'         THEN a.D_PATIENT_ID END) AS AT_ATC,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL LIKE 'Non-ATC%' THEN a.D_PATIENT_ID END) AS UNTAPPED,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC' THEN a.D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
                                        OR a.CLASS_FINAL LIKE 'Non-ATC%'
                                       THEN a.D_PATIENT_ID END), 0), 1)             AS PENETRATION_PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
    ON a.PRIMARY_HCO_NPI_STATE = r.STATE
GROUP BY 1, 2
HAVING COUNT(DISTINCT CASE WHEN a.CLASS_FINAL LIKE 'Non-ATC%' THEN a.D_PATIENT_ID END) >= 20
ORDER BY UNTAPPED DESC;


-- ============ SLIDE 8 - Top 3 non-ATC accounts per region (target list) ============
-- City of Hope / NYU / Ohio State Wexner / Hoag now score ATC, so they drop out here.
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
WHERE RN <= 3
ORDER BY REGION_NAME, PATIENTS DESC;


-- ============ SLIDE 9 - Concentration by segment (dispersed vs concentrated) ==
-- Answers Tim's appendix ask: top-10 share, accounts to reach 50%, by segment.
WITH parents AS (
    SELECT
        COALESCE(NULLIF(TRIM(HCO_PARENT_NAME), ''), 'Unknown / unmapped') AS PARENT,
        COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_FINAL LIKE 'Non-ATC%'
    GROUP BY 1
),
ranked AS (
    SELECT PARENT, PATIENTS,
           ROW_NUMBER() OVER (ORDER BY PATIENTS DESC) AS RN,
           SUM(PATIENTS) OVER () AS TOTAL_NONATC,
           SUM(PATIENTS) OVER (ORDER BY PATIENTS DESC
                               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RUNNING
    FROM parents
)
SELECT
    (SELECT COUNT(*) FROM parents)                                    AS TOTAL_ACCOUNTS,
    MAX(TOTAL_NONATC)                                                 AS TOTAL_NONATC_PATIENTS,
    ROUND(100.0 * SUM(CASE WHEN RN <= 10 THEN PATIENTS END)
          / MAX(TOTAL_NONATC), 1)                                     AS TOP10_SHARE_PCT,
    MIN(CASE WHEN RUNNING >= 0.50 * TOTAL_NONATC THEN RN END)         AS ACCOUNTS_TO_50PCT,
    MIN(CASE WHEN RUNNING >= 0.80 * TOTAL_NONATC THEN RN END)         AS ACCOUNTS_TO_80PCT
FROM ranked;
/* ============================================================================
   For Tim Logan's feedback (Site of Care deck, slide 5):
   Penetration AND absolute opportunity, by region and by state.

   Key idea: low penetration alone doesn't mean "add ATCs here." A region can
   have the worst penetration but the smallest untapped pool. This ranks by
   untapped VOLUME so the biggest real opportunity surfaces.

   Untapped = non-ATC patients (the out-of-network pool we could capture).
   ============================================================================ */

-- 1) REGION view: penetration + opportunity, ranked by untapped volume
SELECT
    COALESCE(r.REGION, 'Unmapped')                                          AS REGION,
    COUNT(DISTINCT a.D_PATIENT_ID)                                          AS TOTAL_PATIENTS,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
                        THEN a.D_PATIENT_ID END)                            AS ATC_PATIENTS,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL <> 'ATC'
                        THEN a.D_PATIENT_ID END)                            AS UNTAPPED_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
                        THEN a.D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT a.D_PATIENT_ID), 0), 1)                   AS PCT_ATC,
    RANK() OVER (ORDER BY COUNT(DISTINCT CASE WHEN a.CLASS_FINAL <> 'ATC'
                        THEN a.D_PATIENT_ID END) DESC)                      AS OPPORTUNITY_RANK,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.CLASS_FINAL <> 'ATC'
                        THEN a.D_PATIENT_ID END)
          / SUM(COUNT(DISTINCT CASE WHEN a.CLASS_FINAL <> 'ATC'
                        THEN a.D_PATIENT_ID END)) OVER (), 1)               AS PCT_OF_TOTAL_UNTAPPED
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
    ON a.PRIMARY_HCO_NPI_STATE = r.STATE
GROUP BY 1
ORDER BY UNTAPPED_PATIENTS DESC;


-- 2) STATE view: same lens, one row per state, biggest opportunity first
SELECT
    a.PRIMARY_HCO_NPI_STATE                                                 AS STATE,
    COALESCE(r.REGION, 'Unmapped')                                          AS REGION,
    COUNT(DISTINCT a.D_PATIENT_ID)                                          AS TOTAL_PATIENTS,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
                        THEN a.D_PATIENT_ID END)                            AS ATC_PATIENTS,
    COUNT(DISTINCT CASE WHEN a.CLASS_FINAL <> 'ATC'
                        THEN a.D_PATIENT_ID END)                            AS UNTAPPED_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
                        THEN a.D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT a.D_PATIENT_ID), 0), 1)                   AS PCT_ATC
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
    ON a.PRIMARY_HCO_NPI_STATE = r.STATE
WHERE a.PRIMARY_HCO_NPI_STATE IS NOT NULL
GROUP BY 1, 2
ORDER BY UNTAPPED_PATIENTS DESC;
-- ============================================================================
-- Slide 5 fact-check: which CENTRAL-region states have no ATC presence?
-- Central = TX, OK, KS, NE, SD, ND, AR (per STATE_REGION_MAP).
-- Proxy for "no authorized ATC at all" = zero patients classified ATC in that state.
-- ============================================================================
WITH central_states AS (
    SELECT STATE
    FROM COMPILE_DEV.PUBLIC.STATE_REGION_MAP
    WHERE REGION = 'Central'
),
by_state AS (
    SELECT
        a.PRIMARY_HCO_NPI_STATE                                              AS STATE,
        COUNT(DISTINCT a.D_PATIENT_ID)                                        AS TOTAL_PATIENTS,
        COUNT(DISTINCT CASE WHEN a.CLASS_FINAL = 'ATC'
                            THEN a.D_PATIENT_ID END)                          AS ATC_PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
    INNER JOIN central_states c
        ON a.PRIMARY_HCO_NPI_STATE = c.STATE
    GROUP BY 1
)
SELECT
    STATE,
    TOTAL_PATIENTS,
    ATC_PATIENTS,
    TOTAL_PATIENTS - ATC_PATIENTS                                            AS NON_ATC_PATIENTS,
    ROUND(100.0 * ATC_PATIENTS / NULLIF(TOTAL_PATIENTS, 0), 1)               AS PCT_ATC,
    CASE WHEN ATC_PATIENTS = 0 THEN 'NO ATC PRESENCE'
         WHEN ATC_PATIENTS < 5 THEN 'near-zero'
         ELSE '' END                                                         AS FLAG
FROM by_state
ORDER BY ATC_PATIENTS ASC, TOTAL_PATIENTS DESC;
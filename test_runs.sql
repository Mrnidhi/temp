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

-- VERIFIED RESULT (run 2026-07-10, 7 rows = all 7 Central states; Mississippi absent, confirming it is NOT Central):
--   STATE  TOTAL  ATC  NON_ATC  PCT_ATC  FLAG
--   AR     121    0    121      0.0      NO ATC PRESENCE
--   SD      57    0     57      0.0      NO ATC PRESENCE
--   ND      16    0     16      0.0      NO ATC PRESENCE
--   NE      38    1     37      2.6      near-zero
--   KS      79   13     66     16.5
--   OK     143   65     78     45.5
--   TX     563  186    377     33.0
-- Central total: 265 ATC / 1,017 = 26.0% (matches slide 5 chart).
-- Slide 5 fix: the zero-ATC Central states are Arkansas + the Dakotas, NOT Mississippi (which is Southeast).
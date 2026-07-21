/* ============================================================================
   TEST - Slide 4 referral cohort. The corrected "started outside, referred in"
   number that the slide has always been about.

   PURPOSE
       Of the ATC-classified patients (by most claims), how many had their FIRST
       treatment claim at a non-ATC site (referred in) versus at an ATC (direct).
       This is the metric Kolin defined in the Meet 4.5 / Meet 6 reviews - first
       claim site vs the by-most-claims classification. Pre-correction it was about
       3,701 (over half of ATC). This reads it on the corrected, aligned tables.

       Note: this is NOT first-vs-last claim (that stricter trajectory gives ~99 and
       is a different question). This is first-claim vs where their care centered.

   HOW TO RUN
       Tables must already exist (from the MASTER or the build-once file). This only
       reads them. Run, screenshot the two rows.
   ============================================================================ */

WITH ranked AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE, D_PRIMARY_HCO_COMPILE_ID) AS RN
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
first_claim AS (
    SELECT D_PATIENT_ID, MAX(CASE WHEN RN = 1 THEN IS_ATC_HCO END) AS FIRST_ATC
    FROM ranked
    GROUP BY 1
)
SELECT
    CASE WHEN fc.FIRST_ATC = 1 THEN 'Started at an ATC (direct)'
         ELSE 'Started non-ATC (referred in)' END AS ENTRY_PATH,
    COUNT(*)                                        AS ATC_PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT_OF_ATC
FROM first_claim fc
JOIN COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL c ON fc.D_PATIENT_ID = c.D_PATIENT_ID
WHERE c.CLASS_FINAL = 'ATC'
GROUP BY 1
ORDER BY ATC_PATIENTS DESC;
/* ============================================================================
   TEST - Migration, the proper analysis. Settle whether patients genuinely move
   from a non-ATC site into the ATC network.

   WHY THIS QUERY
       The 3,701 and the 65 each measured one slice with mismatched definitions.
       This categorizes EVERY patient by their real treatment path, on one
       consistent aligned definition, at the site level:

         1. ATC only            - every claim at an ATC. Never outside.
         2. Non-ATC only        - every claim outside. Never touched the network.
         3. Both, started non-ATC - has claims at BOTH, first claim was non-ATC.
                                    THIS is genuine "referred into the network".
         4. Both, started ATC   - has claims at both, first claim was ATC.

       Cohort 3 is the honest migration number. Two extra columns stress-test it:
         OF_WHICH_REACHED_GENUINE_ATC - how many of cohort 3 reached a CONFIRMED
             ATC (NPI or the four roster orgs), not just a name-matched site. If
             this is much smaller than the cohort, the "movement" is name-match
             noise, not real referral into a true center.
         AVG_SITES - average distinct sites per patient. A real mover visits more
             than one site; ~1.0 means they never actually moved.

   HOW TO RUN
       Tables must already exist. Read-only. Run, screenshot the four rows.
   ============================================================================ */

WITH name_fallback_parents AS (
    SELECT DISTINCT UPPER(TRIM(HCO_PARENT_NAME)) AS PARENT
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_HYBRID = 'ATC: name fallback'
      AND CLASS_FINAL  = 'ATC'
),
claims AS (
    SELECT
        t.D_PATIENT_ID,
        t.IS_ATC_HCO,
        -- Genuine ATC = confirmed by NPI or one of the four roster orgs, i.e. an
        -- ATC claim whose site is NOT a name-match-only parent.
        CASE WHEN t.IS_ATC_HCO = 1 AND nf.PARENT IS NULL THEN 1 ELSE 0 END AS IS_GENUINE_ATC,
        t.D_PRIMARY_HCO_COMPILE_ID,
        ROW_NUMBER() OVER (PARTITION BY t.D_PATIENT_ID
                           ORDER BY t.DATE_OF_SERVICE, t.D_PRIMARY_HCO_COMPILE_ID) AS RN
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS t
    LEFT JOIN name_fallback_parents nf
        ON UPPER(TRIM(t.HCO_PARENT_NAME)) = nf.PARENT
),
pt AS (
    SELECT
        D_PATIENT_ID,
        MAX(IS_ATC_HCO)                           AS HAS_ATC,
        MAX(1 - IS_ATC_HCO)                       AS HAS_NONATC,
        MAX(IS_GENUINE_ATC)                       AS HAS_GENUINE_ATC,
        MAX(CASE WHEN RN = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
        COUNT(DISTINCT D_PRIMARY_HCO_COMPILE_ID)  AS DISTINCT_SITES
    FROM claims
    GROUP BY 1
)
SELECT
    CASE
        WHEN HAS_ATC = 1 AND HAS_NONATC = 0                     THEN '1. ATC only'
        WHEN HAS_ATC = 0 AND HAS_NONATC = 1                     THEN '2. Non-ATC only'
        WHEN HAS_ATC = 1 AND HAS_NONATC = 1 AND FIRST_ATC = 0   THEN '3. Both, started non-ATC (referred in)'
        WHEN HAS_ATC = 1 AND HAS_NONATC = 1 AND FIRST_ATC = 1   THEN '4. Both, started ATC'
    END                                                         AS COHORT,
    COUNT(*)                                                    AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS PCT,
    SUM(HAS_GENUINE_ATC)                                        AS OF_WHICH_REACHED_GENUINE_ATC,
    ROUND(AVG(DISTINCT_SITES), 1)                               AS AVG_SITES
FROM pt
GROUP BY 1
ORDER BY 1;
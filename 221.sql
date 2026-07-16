/* ROSTER GAP CORRECTION - VERIFICATION RUNBOOK
   Run the three steps IN ORDER. Do not skip step 0.
   ========================================================================== */


/* -----------------------------------------------------------------------
   STEP 0 - PRE-CHECK. Run this FIRST, before re-running anything.
   Non-destructive, reads the source table only.

   Why: in NewCode.sql the community-network branch is evaluated BEFORE the
   roster-gap branch. If any of our four parents carry one of the three network
   tags, they will STAY Non-ATC and the +566 estimate is wrong.
   Also confirms the parent strings match exactly (the join is on an exact
   UPPER(TRIM(...)) match, so a stray suffix would silently break the fix).

   PASS = every row shows HCO_COMMUNITY_NETWORK as NULL/blank, and the four
          parents total 566.
   FAIL = any row shows THE US ONCOLOGY NETWORK / ONE ONCOLOGY /
          AMERICAN ONCOLOGY NETWORK. Stop and tell me the number.
   ----------------------------------------------------------------------- */
SELECT
    UPPER(TRIM(HCO_PARENT_NAME))  AS PARENT,
    HCO_COMMUNITY_NETWORK,
    COUNT(DISTINCT D_PATIENT_ID)  AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_SOC_PATIENT_CLASSIFIED_2021_2025
WHERE UPPER(TRIM(HCO_PARENT_NAME)) IN (
        'CITY OF HOPE',
        'NYU LANGONE HEALTH SYSTEM',
        'THE OHIO STATE UNIVERSITY WEXNER MEDICAL CENTER',
        'HOAG HOSPITAL NEWPORT BEACH')
GROUP BY 1, 2
ORDER BY 1, 3 DESC;


/* -----------------------------------------------------------------------
   STEP 1 - Only if step 0 passes: re-run Step 1 of git/NewCode.sql
   (the CREATE OR REPLACE ... ATC_CLASSIFIED_FINAL block, lines ~40 to ~125).
   That block now contains the roster_gap_parent correction.
   ----------------------------------------------------------------------- */


/* -----------------------------------------------------------------------
   STEP 2 - POST-CHECK. Run all three. If any disagree, do NOT update the deck.
   ----------------------------------------------------------------------- */

-- 2A) Headline. EXPECT: ATC 7,501 (46.2%) | Non-ATC 8,643 | Needs Review 102 | 16,246 total
--     Slide 3 folds Needs Review into "Other", so it reads 7,501 (46.2%) vs 8,745 (53.8%).
SELECT
    CASE WHEN CLASS_FINAL = 'ATC'          THEN 'ATC'
         WHEN CLASS_FINAL = 'Needs Review' THEN 'Needs Review'
         ELSE 'Non-ATC' END                                    AS GRP,
    COUNT(DISTINCT D_PATIENT_ID)                               AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1)      AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;

-- 2B) The four corrected parents. EXPECT exactly 4 rows summing to 566,
--     all CLASS_FINAL = 'ATC':
--     CITY OF HOPE 298 | NYU LANGONE 216 | OHIO STATE WEXNER 32 | HOAG 20
SELECT
    HCO_PARENT_NAME,
    CLASS_HYBRID,
    CLASS_FINAL,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_HYBRID = 'ATC: roster gap corrected'
GROUP BY 1, 2, 3
ORDER BY 4 DESC;

-- 2C) Guard check. The systems we deliberately did NOT promote must still be
--     Non-ATC. EXPECT: Kaiser 166, Providence 85, Mayo 56, Intermountain 55,
--     Avera 23, Northwell 21, AdventHealth 20, Advocate 12, St Luke's 10, Baylor 1.
SELECT
    HCO_PARENT_NAME,
    CLASS_FINAL,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE UPPER(HCO_PARENT_NAME) IN (
        'KAISER PERMANENTE', 'PROVIDENCE ST. JOSEPH HEALTH', 'MAYO CLINIC',
        'INTERMOUNTAIN HEALTHCARE', 'AVERA HEALTH', 'NORTHWELL HEALTH',
        'ADVENTHEALTH', 'ADVOCATE HEALTH', 'ST LUKE''S',
        'BAYLOR SCOTT & WHITE HEALTH')
GROUP BY 1, 2
ORDER BY 3 DESC;
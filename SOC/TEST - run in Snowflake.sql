/* SITE OF CARE. The only test file. Run in Snowflake, paste results back.

   One table is used throughout:  COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
   Nothing here writes or changes anything.

   ORDER OF WORK
     Q1 and Q7  run now. Q1 decides which roster organisations get folded in.
                Q7 is the effort view for Tim. Send both grids back.
     PATCH      paste the block into MAIN (3 places), rerun MAIN whole.
     Q2 to Q5   run after the rerun, before anything is shared.
     Q6         already run, internal check only, do not show a stakeholder.

   STATUS 07-24 baseline, before the patch: total 16,246. ATC 7,501 at 46.2%.
   Tiers: NPI confirmed 3,257, name fallback 4,029 of which 3,678 stay ATC,
   roster gap corrected 566 across City of Hope 298, NYU Langone 216,
   OSU Wexner 32, Hoag 20.
   ============================================================================ */


/* ============================================================================
   Q1. Site-level check on the eleven roster organisations. RUN THIS FIRST.

   Tim's official roster (07/23) named eleven organisations sitting on our
   non-ATC side, about 399 patients. Seven of them are multi-state systems.
   Kaiser, Providence and St Luke's looked the same way and all three failed:
   the authorized site held zero or one patient while the volume sat at other
   sites in the system. This runs the same check before anything is added.

   How to read it. Per organisation, if the patients sit at the site named on
   the roster, fold it in. If they sit at other sites in the same system, leave
   it out.
   ============================================================================ */
SELECT
    HCO_PARENT_NAME                        AS PARENT,
    PRIMARY_HCO_NPI_NAME                   AS SITE,
    HCO_STATE                              AS STATE,
    COUNT(DISTINCT D_PATIENT_ID)           AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL LIKE 'Non-ATC%'
  AND ( UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%IU HEALTH%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%INDIANA UNIVERSITY%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%MAYO%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%INTERMOUNTAIN%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%AVERA%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%NORTHWELL%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%ADVENTHEALTH%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%ADVOCATE%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%SANFORD%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%SSM%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%BAPTIST MEMORIAL%'
     OR UPPER(TRIM(HCO_PARENT_NAME)) LIKE '%BAYLOR%' )
GROUP BY 1, 2, 3
ORDER BY PARENT, PATIENTS DESC;


/* ============================================================================
   PATCH. Not a query. Edit "MAIN - Site of Care pipeline.sql", then rerun it
   from the top.

   MAIN carries the roster gap correction as a LIKE block in three places, at
   lines 108, 202 and 283. All three must stay identical.
   Keep the four already there and add only the organisations that passed Q1:

            WHEN UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%CITY OF HOPE%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%NYU LANGONE%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%WEXNER%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%HOAG%'
              -- added 2026-07-24, Tim Logan's official roster, site-checked in Q1
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%<passed org>%'
                THEN 'ATC: roster gap corrected'

   Two names to keep out of any new pattern. HUTCHINSON on its own catches
   Hutchinson Regional in Kansas, which is not Fred Hutch. JEFFERSON catches
   two Jefferson County hospitals that are not Thomas Jefferson.
   ============================================================================ */


/* ============================================================================
   Q2. Does it still reconcile. Must return 16,246.
   ============================================================================ */
SELECT COUNT(DISTINCT D_PATIENT_ID) AS TOTAL_PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL;


/* ============================================================================
   Q3. Headline split. Baseline was ATC 7,501 at 46.2%. Expect about 7,900
       and about 48.5% after the patch.
   ============================================================================ */
SELECT
    CLASS_FINAL,
    COUNT(DISTINCT D_PATIENT_ID)                          AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;


/* ============================================================================
   Q4. The three bridge tiers. This is what the Bridge tab reads.

   Baseline: NPI confirmed 3,257, name fallback 4,029, roster gap corrected 566.
   Note name fallback here is 4,029, but 351 of those fail the state limit and
   land in Non-ATC: System sweep, so only 3,678 stay ATC. That is why bridge
   step 2 is 3,678 and not 4,029.

   NPI confirmed must stay at exactly 3,257 after the patch. If it moves, a new
   pattern is catching sites it should not.
   ============================================================================ */
SELECT
    CLASS_HYBRID,
    COUNT(DISTINCT D_PATIENT_ID)                          AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT_OF_ALL
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;


/* ============================================================================
   Q5. Which organisations the roster fix actually moved. Baseline was four:
       City of Hope 298, NYU Langone 216, OSU Wexner 32, Hoag 20, total 566.
       After the patch this list explains the change line by line.
   ============================================================================ */
SELECT
    HCO_PARENT_NAME                        AS PARENT,
    COUNT(DISTINCT D_PATIENT_ID)           AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_HYBRID = 'ATC: roster gap corrected'
GROUP BY 1
ORDER BY PATIENTS DESC;


/* ============================================================================
   Q6. NPI coverage by ATC parent. ALREADY RUN 07-24, keep for reference.

   This was built as a satellite view and it is not one. The result came back
   bimodal: Moffitt 933 at 0.0, Dana-Farber 522 at 0.0, Cooper 83 at 0.0 on one
   side, and Fred Hutchinson 344 at 100.0, MSK 193 at 100.0, NYU Langone 216 at
   100.0, Temple 206 at 100.0 on the other, with almost nothing in between.

   A real satellite footprint does not look like that. What the column measures
   is whether the roster carried that parent's own NPI. At 100 the parent's NPI
   never matched a claim, so every patient fell through to the name match. At 0
   every patient matched by NPI and nothing came through the parent.

   Keep this as an internal data-quality check. It shows exactly which parents
   are missing an NPI in the roster. Do NOT put it in front of a stakeholder as
   an effort or satellite story. Use Q7 for that.
   ============================================================================ */
SELECT
    HCO_PARENT_NAME                                                     AS PARENT,
    COUNT(DISTINCT D_PATIENT_ID)                                        AS ATC_PATIENTS,
    COUNT(DISTINCT CASE WHEN CLASS_HYBRID <> 'ATC: NPI confirmed'
                        THEN D_PATIENT_ID END)                          AS UNDER_THE_PARENT,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN CLASS_HYBRID <> 'ATC: NPI confirmed'
                        THEN D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT D_PATIENT_ID), 0), 1)                 AS PCT_UNDER_PARENT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1
HAVING COUNT(DISTINCT D_PATIENT_ID) >= 50
ORDER BY ATC_PATIENTS DESC;


/* ============================================================================
   Q7. Site footprint by ATC parent. RUN THIS, with Q1.

   This is the effort question answered properly. For each authorized parent:
   how many distinct sites its patients are actually treated at, how many sit
   at the single biggest site, and therefore how much of the volume sits
   everywhere else. It counts sites and patients only, so nothing here depends
   on NPI matching and the Q6 problem cannot repeat.

   How to read it. A parent with one site and 100% at the top site is reached by
   calling on one place. A parent with twelve sites and 30% at the top site is
   most of the work, because the other 70% is spread across eleven more.
   ============================================================================ */
WITH by_site AS (
    SELECT
        HCO_PARENT_NAME              AS PARENT,
        PRIMARY_HCO_NPI_NAME         AS SITE,
        COUNT(DISTINCT D_PATIENT_ID) AS PTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_FINAL = 'ATC'
    GROUP BY 1, 2
),
parent_tot AS (
    SELECT
        HCO_PARENT_NAME              AS PARENT,
        COUNT(DISTINCT D_PATIENT_ID) AS ATC_PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_FINAL = 'ATC'
    GROUP BY 1
),
ranked AS (
    SELECT
        PARENT, SITE, PTS,
        ROW_NUMBER() OVER (PARTITION BY PARENT ORDER BY PTS DESC) AS RN
    FROM by_site
)
SELECT
    p.PARENT,
    p.ATC_PATIENTS,
    COUNT(*)                                                  AS SITES,
    MAX(CASE WHEN r.RN = 1 THEN r.SITE END)                   AS BIGGEST_SITE,
    MAX(CASE WHEN r.RN = 1 THEN r.PTS END)                    AS AT_BIGGEST_SITE,
    p.ATC_PATIENTS - MAX(CASE WHEN r.RN = 1 THEN r.PTS END)   AS EVERYWHERE_ELSE,
    ROUND(100.0 * (p.ATC_PATIENTS - MAX(CASE WHEN r.RN = 1 THEN r.PTS END))
          / NULLIF(p.ATC_PATIENTS, 0), 1)                     AS PCT_ELSEWHERE
FROM parent_tot p
JOIN ranked r ON r.PARENT = p.PARENT
GROUP BY p.PARENT, p.ATC_PATIENTS
HAVING p.ATC_PATIENTS >= 50
ORDER BY p.ATC_PATIENTS DESC;


/* ============================================================================
   Q8. Top non-ATC accounts in Texas, to fill the Texas card on the state slide.

   The Texas card currently shows only Texas Oncology because the other two were
   never in hand. This returns the real top accounts so no number is invented.
   Sanity check: Texas Oncology should come back at about 211, the figure already
   on the slide. If it does, the second and third rows are trustworthy. Paste the
   top three back.
   ============================================================================ */
SELECT
    HCO_PARENT_NAME              AS PARENT,
    COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL LIKE 'Non-ATC%'
  AND HCO_STATE = 'TX'
GROUP BY 1
ORDER BY PATIENTS DESC
LIMIT 5;


/* ============================================================================
   AFTER THE CHECKS PASS
     1. run "Patient Data query (Snowflake).sql", export the grid as
        patient_data.csv
     2. put that csv next to build_workbook.py and run  python build_workbook.py
     3. the workbook rebuilds, Bridge tab included, no manual typing
     4. slide 3 numbers change and the name-matching footnote can come off
     5. send to Tim
   ============================================================================ */

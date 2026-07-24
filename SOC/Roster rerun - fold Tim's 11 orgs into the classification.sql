/* ROSTER RERUN. Run in SNOWFLAKE, on the office laptop, in this order.

   Background. Tim Logan sent the official ATC roster on 07/23. Eleven organisations
   on it were sitting on our non-ATC side, about 399 patients:
     IU Health 188, Mayo 56, Intermountain 55, Avera 23, Northwell 21, AdventHealth 20,
     Advocate 12, Sanford 11, SSM 8, Baptist Memorial 4, Baylor 1.
   Folding them in moves the ATC share from 46.2% to about 48.5%.

   Read this before running PART 2. Kaiser, Providence and St Luke's also matched the
   roster, but only at system level, and the site-level check killed all three: the
   authorized site in each system holds zero or one patient. Seven of the eleven above
   are multi-state systems too (Mayo, Intermountain, Avera, Northwell, AdventHealth,
   Advocate, Baylor). PART 1 runs the same site-level check on them. Only fold in an
   organisation whose authorized site actually holds the patients. */


/* ############################################################################
   PART 1  -  site-level check on the eleven, before anything is changed
   ############################################################################ */

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

/* Paste the rows back into chat. Judgement, per organisation:
     the patients sit at the site named on the roster            -> fold it in
     the patients sit at other sites in the same system          -> leave it out
   Single-site organisations (IU Health, Sanford, SSM, Baptist Memorial) will pass
   on their own. The multi-state systems are the ones to check line by line. */


/* ############################################################################
   PART 2  -  patch NewCode.sql, then rerun it whole
   ############################################################################ */

/* NewCode.sql carries the roster gap correction as a LIKE block in three places
   (Step 1 around line 108, Step 2 around line 199, Step 3 around line 271). All
   three must stay identical. Add the organisations that passed PART 1 to each,
   keeping the four already there:

            WHEN UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%CITY OF HOPE%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%NYU LANGONE%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%WEXNER%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%HOAG%'
              -- added 2026-07-24 from Tim Logan's official roster, site-checked first
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%IU HEALTH%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%INDIANA UNIVERSITY HEALTH%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%SANFORD%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%SSM HEALTH%'
              OR UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%BAPTIST MEMORIAL%'
                THEN 'ATC: roster gap corrected'

   Two names need care. HUTCHINSON on its own also catches Hutchinson Regional in
   Kansas, which is not Fred Hutch, and JEFFERSON catches two Jefferson County
   hospitals that are not Thomas Jefferson. Neither is in this list, but any new
   pattern gets the same test before it goes in.

   Then rerun NewCode.sql from the top so all four base tables are rebuilt. */


/* ############################################################################
   PART 3  -  check the rerun before anything is shared
   ############################################################################ */

-- 3A. Does it still reconcile to 16,246, and where did the share land
SELECT
    CLASS_FINAL,
    COUNT(DISTINCT D_PATIENT_ID)                          AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;

-- 3B. The three bridge tiers, which feed the Bridge tab in the workbook
SELECT
    CLASS_HYBRID,
    COUNT(DISTINCT D_PATIENT_ID)                          AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1) AS PCT_OF_ALL
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 2 DESC;

-- 3C. Which organisations actually moved, so the change can be explained line by line
SELECT
    HCO_PARENT_NAME                        AS PARENT,
    COUNT(DISTINCT D_PATIENT_ID)           AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_HYBRID = 'ATC: roster gap corrected'
GROUP BY 1
ORDER BY PATIENTS DESC;

/* Expected: total still 16,246, ATC around 7,900, share around 48.5%. Step 1 of the
   bridge (NPI confirmed, 3,257) must not move, since the roster fix is a separate tier.
   If it does move, a pattern is catching sites it should not.

   After the rerun:
     1. export Patient Data again and rebuild the workbook (build_workbook.py)
     2. slide 3 numbers change, and the approximate name-matching footnote can come off
     3. the Bridge tab follows on its own, every cell on it is a formula */

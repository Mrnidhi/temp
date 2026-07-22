/* ============================================================================
   TREATMENT SITE ANALYSIS - where melanoma patients actually get infused.

   THE QUESTION (reframed)
       Not "first site vs last site" - that was Patient_Flow FLOW-1, and it misses
       the real pattern. A patient may first show up at a non-ATC site, then get the
       BULK of their infusions at an ATC (and maybe drift back). So we score each
       patient on WHERE THE TREATMENT HAPPENS - the share of infusion claims at ATC -
       and set that beside where they started.
       Patient X (1 non-ATC claim + 6 ATC claims) reads as "started non-ATC, treated
       mostly at ATC". First-vs-last would call X a non-mover if the last claim
       happened to be the one non-ATC visit. Majority-of-treatment catches it.

   ONE THING TO KNOW ABOUT THE TABLE
       ATC_TREATMENT_CLAIMS = one row per Yervoy / Opdualag INFUSION claim. So
       "started non-ATC" here means the FIRST INFUSION was non-ATC, not the diagnosis
       or registration (that lives in the medical claims - a separate pull). If you
       truly want diagnosis-site -> infusion-site, say so and we join the dx claims.

   DATA QUALITY (read M5 and the note at the bottom)
       The ATC flag is NAME-MATCHED - there is no clean, current ATC roster. So a
       site can be mis-flagged (a real ATC satellite missed, or a look-alike name
       counted in). Every number here therefore carries a confidence band, not a
       point. M5 quantifies how much of the answer rests on name matching alone.

   QUERIES
       M1  Do patients even use both site types?  (ATC-only / non-ATC-only / Mixed)
       M2  Started site  vs  treatment home (majority of infusions)  <- the real cross
       M3  How split are patients?  (ATC share bands)
       M4  Full pattern: started x treatment-home x ended  (come in -> treat -> leave)
       M5  Data-quality band: the M2 cohort under BROAD (name match) vs HARD (NPI)

   SNOWFLAKE: name-fallback set is joined with a LEFT JOIN, never IN (SELECT ...)
   inside a CASE - the MASTER notes that form throws "Unsupported subquery type".
   ============================================================================ */


/* ############################################################################
   M1  -  Do patients use one site type, or both?
   If Mixed is small, there is little real movement to find by ANY metric. If Mixed
   is large, the majority lens below matters and first-vs-last understates it.
   ############################################################################ */
WITH pat AS (
    SELECT D_PATIENT_ID,
           COUNT(*)        AS TOTAL_CLAIMS,
           SUM(IS_ATC_HCO) AS ATC_CLAIMS
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    GROUP BY 1
)
SELECT
    CASE WHEN ATC_CLAIMS = TOTAL_CLAIMS THEN 'ATC only'
         WHEN ATC_CLAIMS = 0            THEN 'non-ATC only'
         ELSE                                'Mixed (used both)' END AS SITE_USE,
    COUNT(*)                                            AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS PCT
FROM pat
GROUP BY 1
ORDER BY PATIENTS DESC;


/* ############################################################################
   M2  -  Started site (first infusion) vs treatment home (most infusions).
   The cell you are after is "Started non-ATC / Most treatment at ATC": registered
   outside, but got the actual drug at an ATC. Even split = no majority either way.
   ############################################################################ */
WITH ranked AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO,
           ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                              ORDER BY DATE_OF_SERVICE ASC, D_PRIMARY_HCO_COMPILE_ID) AS RN_FIRST
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
pat AS (
    SELECT D_PATIENT_ID,
           COUNT(*)                                        AS TOTAL_CLAIMS,
           SUM(IS_ATC_HCO)                                 AS ATC_CLAIMS,
           MAX(CASE WHEN RN_FIRST = 1 THEN IS_ATC_HCO END) AS FIRST_ATC
    FROM ranked
    GROUP BY 1
)
SELECT
    CASE WHEN FIRST_ATC = 1 THEN 'Started ATC' ELSE 'Started non-ATC' END AS FIRST_SITE,
    CASE WHEN ATC_CLAIMS * 2 >  TOTAL_CLAIMS THEN 'Most treatment at ATC'
         WHEN ATC_CLAIMS * 2 =  TOTAL_CLAIMS THEN 'Even split'
         ELSE                                     'Most treatment non-ATC' END AS TREATMENT_HOME,
    COUNT(*)                                            AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS PCT
FROM pat
GROUP BY 1, 2
ORDER BY PATIENTS DESC;


/* ############################################################################
   M3  -  How split are patients across the two site types?
   If this piles up at 0% and 100%, patients pick one place and there is no real
   "movement" to tell a story about. The middle bands are the genuinely mixed ones.
   ############################################################################ */
WITH pat AS (
    SELECT D_PATIENT_ID, COUNT(*) AS TOTAL_CLAIMS, SUM(IS_ATC_HCO) AS ATC_CLAIMS
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    GROUP BY 1
)
SELECT
    CASE
        WHEN ATC_CLAIMS = 0                     THEN '0% - all non-ATC'
        WHEN ATC_CLAIMS = TOTAL_CLAIMS          THEN '100% - all ATC'
        WHEN ATC_CLAIMS * 4 <= TOTAL_CLAIMS     THEN '1-25% ATC'
        WHEN ATC_CLAIMS * 2 <= TOTAL_CLAIMS     THEN '26-50% ATC'
        WHEN ATC_CLAIMS * 4 <= TOTAL_CLAIMS * 3 THEN '51-75% ATC'
        ELSE                                         '76-99% ATC'
    END                                                 AS ATC_SHARE_BAND,
    COUNT(*)                                            AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS PCT
FROM pat
GROUP BY 1
ORDER BY MIN(1.0 * ATC_CLAIMS / TOTAL_CLAIMS);


/* ############################################################################
   M4  -  Full pattern: started x treatment-home x ended.
   The come-in-for-the-drug-then-go-home picture. Watch the row
   Started non-ATC / Most at ATC / Ended non-ATC = travelled in for infusions,
   returned to a local site after.
   ############################################################################ */
WITH ranked AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO,
           ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE ASC,  D_PRIMARY_HCO_COMPILE_ID) AS RN_FIRST,
           ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE DESC, D_PRIMARY_HCO_COMPILE_ID) AS RN_LAST
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
pat AS (
    SELECT D_PATIENT_ID,
           COUNT(*)                                        AS TOTAL_CLAIMS,
           SUM(IS_ATC_HCO)                                 AS ATC_CLAIMS,
           MAX(CASE WHEN RN_FIRST = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
           MAX(CASE WHEN RN_LAST  = 1 THEN IS_ATC_HCO END) AS LAST_ATC
    FROM ranked
    GROUP BY 1
)
SELECT
    CASE WHEN FIRST_ATC = 1 THEN 'Started ATC' ELSE 'Started non-ATC' END AS FIRST_SITE,
    CASE WHEN ATC_CLAIMS * 2 >  TOTAL_CLAIMS THEN 'Most at ATC'
         WHEN ATC_CLAIMS * 2 =  TOTAL_CLAIMS THEN 'Even split'
         ELSE                                     'Most non-ATC' END       AS TREATMENT_HOME,
    CASE WHEN LAST_ATC = 1 THEN 'Ended ATC' ELSE 'Ended non-ATC' END       AS LAST_SITE,
    COUNT(*)                                            AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS PCT
FROM pat
GROUP BY 1, 2, 3
ORDER BY PATIENTS DESC;


/* ############################################################################
   M5  -  DATA-QUALITY BAND on the M2 cohort.
   The ATC flag is name-matched, so "started non-ATC, treated at ATC" depends on how
   much name matching we trust.
       BROAD = keep every name-matched ATC claim (the current build).
       HARD  = drop name-only ATC claims (parent matched by NAME but not NPI/roster),
               the conservative floor.
   The gap between the two rows is how much of the cohort rests on name matching
   alone. A wide gap = treat the headline as a range, and eyeball the mixed patients.
   ############################################################################ */
WITH nf AS (
    SELECT DISTINCT UPPER(TRIM(HCO_PARENT_NAME)) AS PARENT
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_HYBRID = 'ATC: name fallback'
      AND CLASS_FINAL  = 'ATC'
),
tagged AS (
    SELECT
        t.D_PATIENT_ID, t.DATE_OF_SERVICE, t.D_PRIMARY_HCO_COMPILE_ID,
        t.IS_ATC_HCO,
        CASE WHEN t.IS_ATC_HCO = 1 AND nf.PARENT IS NOT NULL THEN 1 ELSE 0 END AS SOFT_ATC
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS t
    LEFT JOIN nf ON UPPER(TRIM(t.HCO_PARENT_NAME)) = nf.PARENT
),
ranked AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO, SOFT_ATC,
           ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                              ORDER BY DATE_OF_SERVICE ASC, D_PRIMARY_HCO_COMPILE_ID) AS RN_FIRST
    FROM tagged
),
pat AS (
    SELECT D_PATIENT_ID,
           COUNT(*)                        AS TOTAL_CLAIMS,
           SUM(IS_ATC_HCO)                 AS ATC_BROAD,
           SUM(IS_ATC_HCO) - SUM(SOFT_ATC) AS ATC_HARD,
           MAX(CASE WHEN RN_FIRST = 1 THEN IS_ATC_HCO END)            AS FIRST_BROAD,
           MAX(CASE WHEN RN_FIRST = 1 THEN IS_ATC_HCO - SOFT_ATC END) AS FIRST_HARD
    FROM ranked
    GROUP BY 1
)
SELECT 'Broad - name matching kept (current)' AS DEFINITION,
       COUNT_IF(FIRST_BROAD = 0 AND ATC_BROAD * 2 > TOTAL_CLAIMS) AS STARTED_NONATC_TREATED_ATC,
       COUNT_IF(ATC_BROAD * 2 > TOTAL_CLAIMS)                     AS MAJORITY_ATC_TOTAL
FROM pat
UNION ALL
SELECT 'Hard - NPI + roster only (floor)',
       COUNT_IF(FIRST_HARD = 0 AND ATC_HARD * 2 > TOTAL_CLAIMS),
       COUNT_IF(ATC_HARD * 2 > TOTAL_CLAIMS)
FROM pat;


/* ============================================================================
   DATA-QUALITY NOTE - read before quoting any number above.

   The ATC flag is only as good as the name matching, and there is no clean roster:
     - FALSE NEGATIVES: a real ATC satellite whose parent name is spelled differently
       (or blank) is scored non-ATC -> understates ATC and understates "moved to ATC".
     - FALSE POSITIVES: a non-ATC site whose name resembles an authorized parent is
       scored ATC -> overstates it.
     - THE TWO-STATE GUARD (fallback_state_limit = 2 in the MASTER) drops big
       multi-state systems from ATC on purpose; move it and the ATC total swings
       (~20% to ~46%). See Q7B in the TEST file.
     - NAME VARIANTS: one system split across spellings is under-counted. See Q7A.

   HOW TO HANDLE IT
     1. Report the M2 cohort as a RANGE (M5 hard floor -> broad), not a single number.
     2. The mixed cohort (M1) is small enough to eyeball - pull the account names and
        confirm the ATC flags by hand before this goes on a slide.
     3. The real fix is the updated ATC roster with NPIs. Until then, every ATC number
        in the whole deck inherits this band, not just this file.
   ============================================================================ */
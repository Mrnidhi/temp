/* ============================================================================
   PATIENT FLOW - Site of Care. Where patients start vs where they end up.

   WHAT THIS IS
       The honest version of slide 4. One row per patient: the site type of their
       FIRST treatment claim vs their LAST treatment claim. That is a real journey
       (movement over time), not an overall bucket label. This is what "3,701"
       was pretending to be - the true number of patients who start outside and
       end inside the ATC network is about 99.

   HOW TO RUN
       Needs the MASTER base tables (ATC_TREATMENT_CLAIMS). Read-only, creates
       nothing. Run FLOW-1 first; it reproduces the corrected slide 4 boxes.

   BUCKETS
       2-bucket  = ATC vs non-ATC          (rock solid, FLOW-1 / FLOW-2 / FLOW-4)
       4-bucket  = ATC / Hospital / Community / Other  (FLOW-3 / FLOW-5 - DISABLED, see note)

   PATHWAYS (the full journey, not just first vs last)
       FLOW-6  = the whole ordered path per patient  (non-ATC -> ATC -> non-ATC ...)
       FLOW-7  = how many times each patient switches (0, 1, 2, 3+)
       FLOW-8  = conditional tree: of non-ATC starters, % who reach ATC, then
                 % who stay vs bounce back (and the ATC-start mirror)

   Pathways collapse each patient to ONE site per day first (ATC if >= half that
   day's claims are ATC, ties -> ATC), then keep only the switches. That turns a
   wall of repeat claims into a clean journey and stops same-day billing noise
   from looking like a trip.

   TIES TO THE MASTER
       FLOW-1 is the MASTER's B4A query (identical first-vs-last logic) with a
       plain-English Movement column added - it reproduces 8,775 / 7,482 / 99 / 48.
       The pathway queries (FLOW-6/7/8) collapse to one site per DAY first, so they
       will not tie to B4A patient-for-patient (B4A is per first/last CLAIM). Ask
       for the per-claim variant if you need exact reconciliation to B4A.

   SNOWFLAKE NOTES
       Aliases dodge reserved words (no ROWS / ROW / SOURCE / TARGET). The PCT
       column uses SUM(COUNT(*)) OVER () after GROUP BY - same window-over-aggregate
       pattern already proven in the MASTER and TEST files. Runs top to bottom.
   ============================================================================ */


/* ############################################################################
   FLOW-1  -  First site vs last site, ATC vs non-ATC  (the corrected slide 4)
   Expect 8,775 / 7,482 / 99 / 48. "Movement" spells out stay vs switch.
   ############################################################################ */
WITH ranked AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE ASC,  D_PRIMARY_HCO_COMPILE_ID) AS RN_FIRST,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE DESC, D_PRIMARY_HCO_COMPILE_ID) AS RN_LAST
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
first_last AS (
    SELECT D_PATIENT_ID,
        MAX(CASE WHEN RN_FIRST = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
        MAX(CASE WHEN RN_LAST  = 1 THEN IS_ATC_HCO END) AS LAST_ATC
    FROM ranked GROUP BY 1
)
SELECT
    CASE WHEN FIRST_ATC = 1 THEN 'Started at an ATC' ELSE 'Started non-ATC' END AS FIRST_SITE,
    CASE WHEN LAST_ATC  = 1 THEN 'Ended at an ATC'   ELSE 'Ended non-ATC'   END AS LAST_SITE,
    CASE
        WHEN FIRST_ATC = 1 AND LAST_ATC = 1 THEN 'Stayed ATC'
        WHEN FIRST_ATC = 0 AND LAST_ATC = 0 THEN 'Stayed non-ATC'
        WHEN FIRST_ATC = 0 AND LAST_ATC = 1 THEN 'Moved INTO ATC'
        ELSE                                     'Moved OUT to non-ATC'
    END                                                AS MOVEMENT,
    COUNT(*)                                           AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM first_last
GROUP BY 1, 2, 3
ORDER BY PATIENTS DESC;


/* ############################################################################
   FLOW-2  -  One-line version: stayers vs movers.
   The headline: ~99% of patients never switch networks.
   ############################################################################ */
WITH ranked AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE ASC,  D_PRIMARY_HCO_COMPILE_ID) AS RN_FIRST,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE DESC, D_PRIMARY_HCO_COMPILE_ID) AS RN_LAST
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
first_last AS (
    SELECT D_PATIENT_ID,
        MAX(CASE WHEN RN_FIRST = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
        MAX(CASE WHEN RN_LAST  = 1 THEN IS_ATC_HCO END) AS LAST_ATC
    FROM ranked GROUP BY 1
)
SELECT
    CASE
        WHEN FIRST_ATC = LAST_ATC       THEN 'Stayed put (never switched)'
        WHEN FIRST_ATC = 0 AND LAST_ATC = 1 THEN 'Moved INTO ATC'
        ELSE                                 'Moved OUT to non-ATC'
    END                                                AS MOVEMENT,
    COUNT(*)                                           AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM first_last
GROUP BY 1
ORDER BY PATIENTS DESC;


/* ############################################################################
   FLOW-3  -  First site vs last site, 4 buckets (ATC / Hospital / Community / Other)
   *** DISABLED - needs a per-claim site sub-type the claims table does not have ***

   The claims table (ATC_TREATMENT_CLAIMS) only carries IS_ATC_HCO, the plain
   ATC vs non-ATC flag. Hospital / Community / Other is a per-SITE property set in
   the MASTER build; it only lands at the patient's PRIMARY site (on
   ATC_CLASSIFIED_FINAL), not on every claim. So a truthful per-claim 4-bucket
   flow can't come from these two tables, and inventing a mapping here would risk
   numbers that don't tie back to slide 3 (7,100 / 1,317 / 328).

   TO ENABLE: expose the MASTER's site -> {ATC, Hospital, Community, Other} lookup
   keyed by D_PRIMARY_HCO_COMPILE_ID (or NPI), join it below, and set SITE_BUCKET
   from it. Send me that logic and I'll wire it. Until then the 2-bucket flows
   (FLOW-1 / 2 / 4 / 6 / 7 / 8) tell the whole story and all run clean.

   Template kept below, commented out so the file runs top to bottom:
   ############################################################################ */
/*
WITH claims AS (
    SELECT
        c.D_PATIENT_ID, c.DATE_OF_SERVICE, c.D_PRIMARY_HCO_COMPILE_ID,
        b.SITE_BUCKET                                   -- from your site-level lookup
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS c
    LEFT JOIN <site_bucket_lookup> b ON b.HCO_ID = c.D_PRIMARY_HCO_COMPILE_ID
),
ranked AS (
    SELECT D_PATIENT_ID, SITE_BUCKET,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE ASC,  D_PRIMARY_HCO_COMPILE_ID) AS RN_FIRST,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE DESC, D_PRIMARY_HCO_COMPILE_ID) AS RN_LAST
    FROM claims
),
first_last AS (
    SELECT D_PATIENT_ID,
        MAX(CASE WHEN RN_FIRST = 1 THEN SITE_BUCKET END) AS FIRST_BUCKET,
        MAX(CASE WHEN RN_LAST  = 1 THEN SITE_BUCKET END) AS LAST_BUCKET
    FROM ranked GROUP BY 1
)
SELECT
    FIRST_BUCKET, LAST_BUCKET,
    CASE WHEN FIRST_BUCKET = LAST_BUCKET THEN 'Stayed' ELSE 'Switched' END AS MOVEMENT,
    COUNT(*)                                           AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM first_last
GROUP BY 1, 2, 3
ORDER BY PATIENTS DESC;
*/


/* ############################################################################
   FLOW-4  -  Sankey edge list, 2-bucket. Paste FROM_SITE / TO_SITE / PATIENTS
   straight into Flourish, Power BI, or plotly. Start and end nodes are named
   distinctly so the diagram reads left (start) to right (end).
   ############################################################################ */
WITH ranked AS (
    SELECT D_PATIENT_ID, IS_ATC_HCO,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE ASC,  D_PRIMARY_HCO_COMPILE_ID) AS RN_FIRST,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE DESC, D_PRIMARY_HCO_COMPILE_ID) AS RN_LAST
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
first_last AS (
    SELECT D_PATIENT_ID,
        MAX(CASE WHEN RN_FIRST = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
        MAX(CASE WHEN RN_LAST  = 1 THEN IS_ATC_HCO END) AS LAST_ATC
    FROM ranked GROUP BY 1
)
SELECT
    CASE WHEN FIRST_ATC = 1 THEN 'Start: ATC' ELSE 'Start: non-ATC' END AS FROM_SITE,
    CASE WHEN LAST_ATC  = 1 THEN 'End: ATC'   ELSE 'End: non-ATC'   END AS TO_SITE,
    COUNT(*)                                                           AS PATIENTS
FROM first_last
GROUP BY 1, 2
ORDER BY PATIENTS DESC;

/* FLOW-5. Sankey edge list, 4-bucket (needs FLOW-3 enabled first): take
   FIRST_BUCKET, LAST_BUCKET, PATIENTS from FLOW-3 and feed the same tool. */


/* ############################################################################
   FLOW-6  -  The full ordered journey per patient, collapsed to switches only.
   Reads like non-ATC -> ATC -> non-ATC. Grouped so you see the most common
   journeys and how many patients walked each one. JOURNEY is 2-bucket for
   readability; swap in the FLOW-3 SITE_BUCKET if you want the 4-bucket path.
   ############################################################################ */
WITH per_day AS (   -- one site per patient per day (ATC if >= half the day is ATC)
    SELECT D_PATIENT_ID, DATE_OF_SERVICE,
           IFF(SUM(IS_ATC_HCO) * 2 >= COUNT(*), 1, 0) AS DAY_ATC
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    GROUP BY 1, 2
),
daily AS (
    SELECT D_PATIENT_ID, DATE_OF_SERVICE, DAY_ATC,
           CASE WHEN DAY_ATC = 1 THEN 'ATC' ELSE 'non-ATC' END AS SITE_LABEL,
           LAG(DAY_ATC) OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE) AS PREV_ATC
    FROM per_day
),
transitions AS (    -- keep the first day and every day the bucket flips
    SELECT D_PATIENT_ID, DATE_OF_SERVICE, SITE_LABEL
    FROM daily
    WHERE PREV_ATC IS NULL OR DAY_ATC <> PREV_ATC
),
paths AS (
    SELECT D_PATIENT_ID,
           LISTAGG(SITE_LABEL, ' -> ') WITHIN GROUP (ORDER BY DATE_OF_SERVICE) AS JOURNEY,
           COUNT(*) AS STOPS
    FROM transitions
    GROUP BY 1
)
SELECT
    JOURNEY,
    STOPS,
    COUNT(*)                                           AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM paths
GROUP BY 1, 2
ORDER BY PATIENTS DESC
LIMIT 40;


/* ############################################################################
   FLOW-7  -  How many times a patient switches networks (0, 1, 2, 3+).
   0 switches is the "stayed put" crowd - expect it to be the vast majority.
   ############################################################################ */
WITH per_day AS (
    SELECT D_PATIENT_ID, DATE_OF_SERVICE,
           IFF(SUM(IS_ATC_HCO) * 2 >= COUNT(*), 1, 0) AS DAY_ATC
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    GROUP BY 1, 2
),
daily AS (
    SELECT D_PATIENT_ID, DAY_ATC,
           LAG(DAY_ATC) OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE) AS PREV_ATC
    FROM per_day
),
switch_counts AS (
    SELECT D_PATIENT_ID,
           COUNT_IF(PREV_ATC IS NOT NULL AND DAY_ATC <> PREV_ATC) AS SWITCHES
    FROM daily
    GROUP BY 1
)
SELECT
    SWITCHES,
    COUNT(*)                                           AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM switch_counts
GROUP BY 1
ORDER BY SWITCHES;


/* ############################################################################
   FLOW-8  -  The conditional tree (the "simulation").
   Walks the branches with a percent-of-parent at each step:
     Started non-ATC  ->  moved to ATC?  ->  then stayed ATC / bounced back?
     Started at ATC   ->  moved to non-ATC? -> then stayed / bounced back?
   PCT_OF_PARENT is the conditional rate (e.g. of non-ATC starters, X% reach ATC).
   ############################################################################ */
WITH per_day AS (
    SELECT D_PATIENT_ID, DATE_OF_SERVICE,
           IFF(SUM(IS_ATC_HCO) * 2 >= COUNT(*), 1, 0) AS DAY_ATC
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    GROUP BY 1, 2
),
daily AS (
    SELECT D_PATIENT_ID, DATE_OF_SERVICE, DAY_ATC,
           CASE WHEN DAY_ATC = 1 THEN 'ATC' ELSE 'non-ATC' END AS SITE_LABEL,
           LAG(DAY_ATC) OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE) AS PREV_ATC
    FROM per_day
),
episodes AS (
    SELECT D_PATIENT_ID, SITE_LABEL,
           ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE) AS EP_NUM
    FROM daily
    WHERE PREV_ATC IS NULL OR DAY_ATC <> PREV_ATC
),
pat AS (        -- one row per patient: where they started, their first switch, how many stops
    SELECT D_PATIENT_ID,
           MAX(CASE WHEN EP_NUM = 1 THEN SITE_LABEL END) AS START_SITE,
           MAX(CASE WHEN EP_NUM = 2 THEN SITE_LABEL END) AS SECOND_SITE,
           MAX(EP_NUM)                                   AS STOPS
    FROM episodes
    GROUP BY 1
),
m AS (
    SELECT
        COUNT(*)                                                                AS ALL_PT,
        COUNT_IF(START_SITE = 'non-ATC')                                        AS NS,
        COUNT_IF(START_SITE = 'non-ATC' AND SECOND_SITE = 'ATC')                AS NS_TO_ATC,
        COUNT_IF(START_SITE = 'non-ATC' AND SECOND_SITE = 'ATC' AND STOPS = 2)  AS NS_STAY,
        COUNT_IF(START_SITE = 'non-ATC' AND SECOND_SITE = 'ATC' AND STOPS >= 3) AS NS_BACK,
        COUNT_IF(START_SITE = 'non-ATC' AND SECOND_SITE IS NULL)                AS NS_NEVER,
        COUNT_IF(START_SITE = 'ATC')                                            AS AT_PT,
        COUNT_IF(START_SITE = 'ATC' AND SECOND_SITE = 'non-ATC')                AS AT_TO_NS,
        COUNT_IF(START_SITE = 'ATC' AND SECOND_SITE = 'non-ATC' AND STOPS = 2)  AS AT_STAY,
        COUNT_IF(START_SITE = 'ATC' AND SECOND_SITE = 'non-ATC' AND STOPS >= 3) AS AT_BACK,
        COUNT_IF(START_SITE = 'ATC' AND SECOND_SITE IS NULL)                    AS AT_NEVER
    FROM pat
)
SELECT 1 AS SORT_ORDER, 'Started non-ATC'                  AS SEGMENT, NS       AS PATIENTS, ROUND(100.0 * NS        / NULLIF(ALL_PT, 0), 1) AS PCT_OF_PARENT FROM m
UNION ALL SELECT 2, '  then moved to ATC',                 NS_TO_ATC, ROUND(100.0 * NS_TO_ATC / NULLIF(NS, 0),        1) FROM m
UNION ALL SELECT 3, '    ...of those, stayed ATC',         NS_STAY,   ROUND(100.0 * NS_STAY   / NULLIF(NS_TO_ATC, 0), 1) FROM m
UNION ALL SELECT 4, '    ...of those, bounced back',       NS_BACK,   ROUND(100.0 * NS_BACK   / NULLIF(NS_TO_ATC, 0), 1) FROM m
UNION ALL SELECT 5, '  never left non-ATC',                NS_NEVER,  ROUND(100.0 * NS_NEVER  / NULLIF(NS, 0),        1) FROM m
UNION ALL SELECT 6, 'Started at ATC',                      AT_PT,     ROUND(100.0 * AT_PT     / NULLIF(ALL_PT, 0),    1) FROM m
UNION ALL SELECT 7, '  then moved to non-ATC',             AT_TO_NS,  ROUND(100.0 * AT_TO_NS  / NULLIF(AT_PT, 0),     1) FROM m
UNION ALL SELECT 8, '    ...of those, stayed non-ATC',     AT_STAY,   ROUND(100.0 * AT_STAY   / NULLIF(AT_TO_NS, 0),  1) FROM m
UNION ALL SELECT 9, '    ...of those, bounced back',       AT_BACK,   ROUND(100.0 * AT_BACK   / NULLIF(AT_TO_NS, 0),  1) FROM m
UNION ALL SELECT 10, '  never left ATC',                   AT_NEVER,  ROUND(100.0 * AT_NEVER  / NULLIF(AT_PT, 0),     1) FROM m
ORDER BY SORT_ORDER;
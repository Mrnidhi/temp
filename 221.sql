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
       4-bucket  = ATC / Hospital / Community / Other  (FLOW-3 / FLOW-5, see note)

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
   Same idea as FLOW-1, one level deeper: does a community-network patient ever
   graduate into an ATC, is Hospital the sticky one, etc.

   ASSUMPTION - claim-level site sub-type. IS_ATC_HCO is confirmed on the claims
   table. HCO_COMMUNITY_NETWORK and HCO_PARENT_NAME are assumed to sit on it too
   (they exist on ATC_CLASSIFIED_FINAL). If the claims table does NOT carry them,
   join a site/HCO dimension on D_PRIMARY_HCO_COMPILE_ID and build SITE_BUCKET
   from that. Confirm the three column names, then this runs as-is.
   ############################################################################ */
WITH claims AS (
    SELECT
        D_PATIENT_ID,
        DATE_OF_SERVICE,
        D_PRIMARY_HCO_COMPILE_ID,
        CASE
            WHEN IS_ATC_HCO = 1                    THEN 'ATC'
            WHEN HCO_COMMUNITY_NETWORK IS NOT NULL THEN 'Non-ATC: Community'
            WHEN HCO_PARENT_NAME       IS NOT NULL THEN 'Non-ATC: Hospital'
            ELSE                                        'Non-ATC: Other'
        END AS SITE_BUCKET
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
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
    FIRST_BUCKET,
    LAST_BUCKET,
    CASE WHEN FIRST_BUCKET = LAST_BUCKET THEN 'Stayed' ELSE 'Switched' END AS MOVEMENT,
    COUNT(*)                                           AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM first_last
GROUP BY 1, 2, 3
ORDER BY PATIENTS DESC;


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

/* FLOW-5. Sankey edge list, 4-bucket: just take FIRST_BUCKET, LAST_BUCKET,
   PATIENTS from FLOW-3 (drop MOVEMENT and PCT) and feed the same tool. */
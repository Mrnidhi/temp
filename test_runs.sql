/* ============================================================================
   Concentration by Segment  --  follow-up for Tim Logan's deck comment (Jul 13)
   Site of Care Analysis  .  ATC vs Non-ATC

   Tim's ask:   "highlight the concentration by segment ... the volume at some
                segments could be concentrated while others more dispersed ...
                would help direct efforts to address patients outside the ATCs."
   Kolin's add: "concentration of patients within ATC vs. ATC satellite?"

   What each section returns:
     C1   every patient split into segments, with a concentration proxy
          (patients per parent account) so concentrated vs dispersed is visible
     C2   non-ATC volume by account (Pareto: each account's share + cumulative)
     C3   one-line verdict: top-10 share, and how many accounts it takes to
          cover 50% / 80% of the non-ATC patients
     C4   non-ATC volume by region (where the outside-ATC patients sit)
     C5a  within ATC: true site vs satellite (Kolin's question)
     C5b  ATC satellite concentration by parent

   Requires the base tables from git/NewCode.sql (ATC_CLASSIFIED_FINAL,
   STATE_REGION_MAP). If they are not present, run NewCode.sql first. This
   script only reads them and creates nothing.
   Run each section and paste the output back labeled C1..C5.
   ============================================================================ */


-- C1: Concentration by segment ------------------------------------------------
-- One row per segment. PATIENTS_PER_PARENT is the concentration proxy:
-- high = volume sits in a few accounts (concentrated), low = spread thin.
SELECT
    CASE
        WHEN CLASS_FINAL = 'ATC' AND CLASS_HYBRID = 'ATC: NPI confirmed'
                                                    THEN '1 ATC - true site'
        WHEN CLASS_FINAL = 'ATC'                    THEN '2 ATC - satellite'
        WHEN CLASS_FINAL = 'Non-ATC: Community Network'
                                                    THEN '3 Non-ATC - community network'
        WHEN CLASS_FINAL = 'Non-ATC: System sweep'  THEN '4 Non-ATC - hospital system'
        WHEN CLASS_FINAL = 'Non-ATC: Unknown'       THEN '5 Non-ATC - unknown site'
        WHEN CLASS_FINAL = 'Non-ATC'                THEN '6 Non-ATC - independent / other'
        WHEN CLASS_FINAL = 'Needs Review'           THEN '7 Needs review'
        ELSE '8 Other'
    END                                                            AS SEGMENT,
    COUNT(DISTINCT D_PATIENT_ID)                                   AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1)          AS PCT_OF_ALL,
    COUNT(DISTINCT HCO_PARENT_NAME)                                AS DISTINCT_PARENTS,
    COUNT(DISTINCT D_PRIMARY_HCO_COMPILE_ID)                       AS DISTINCT_SITES,
    ROUND(1.0 * COUNT(DISTINCT D_PATIENT_ID)
          / NULLIF(COUNT(DISTINCT HCO_PARENT_NAME), 0), 1)         AS PATIENTS_PER_PARENT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
GROUP BY 1
ORDER BY 1;


-- C2: Non-ATC volume by account (Pareto) --------------------------------------
-- Top 20 non-ATC parent accounts. PCT_OF_NON_ATC is that account's share;
-- CUM_PCT_OF_NON_ATC is the running total, showing how fast volume piles up.
WITH leak AS (
    SELECT
        COALESCE(NULLIF(TRIM(HCO_PARENT_NAME), ''), 'Unknown / unmapped') AS PARENT,
        COUNT(DISTINCT D_PATIENT_ID)             AS PATIENTS,
        COUNT(DISTINCT D_PRIMARY_HCO_COMPILE_ID) AS DISTINCT_SITES
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_FINAL LIKE 'Non-ATC%'
    GROUP BY 1
)
SELECT
    PARENT,
    PATIENTS,
    DISTINCT_SITES,
    RANK() OVER (ORDER BY PATIENTS DESC)                          AS LEAK_RANK,
    ROUND(100.0 * PATIENTS / SUM(PATIENTS) OVER (), 1)            AS PCT_OF_NON_ATC,
    ROUND(100.0 * SUM(PATIENTS) OVER (ORDER BY PATIENTS DESC
                                      ROWS UNBOUNDED PRECEDING)
          / SUM(PATIENTS) OVER (), 1)                            AS CUM_PCT_OF_NON_ATC
FROM leak
ORDER BY PATIENTS DESC
LIMIT 20;


-- C3: Concentration verdict (identifiable non-ATC accounts only) --------------
-- Drops unknown / unmapped parent, since you can't target it. Returns one row:
-- if a handful of accounts cover 50-80%, it is concentrated; if it takes many,
-- it is dispersed.
WITH leak AS (
    SELECT HCO_PARENT_NAME AS PARENT,
           COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_FINAL LIKE 'Non-ATC%'
      AND HCO_PARENT_NAME IS NOT NULL
      AND TRIM(HCO_PARENT_NAME) NOT IN ('', 'null')
    GROUP BY 1
),
ranked AS (
    SELECT PARENT, PATIENTS,
           SUM(PATIENTS) OVER ()                        AS TOTAL,
           ROW_NUMBER() OVER (ORDER BY PATIENTS DESC)   AS RN,
           SUM(PATIENTS) OVER (ORDER BY PATIENTS DESC
                               ROWS UNBOUNDED PRECEDING) AS CUM
    FROM leak
)
SELECT
    MAX(TOTAL)                                                    AS NON_ATC_PATIENTS_NAMED,
    COUNT(*)                                                      AS DISTINCT_PARENTS,
    ROUND(100.0 * SUM(CASE WHEN RN <= 10 THEN PATIENTS ELSE 0 END)
          / MAX(TOTAL), 1)                                       AS TOP10_PARENT_SHARE_PCT,
    MIN(CASE WHEN CUM >= 0.50 * TOTAL THEN RN END)               AS PARENTS_TO_COVER_50PCT,
    MIN(CASE WHEN CUM >= 0.80 * TOTAL THEN RN END)               AS PARENTS_TO_COVER_80PCT
FROM ranked;


-- C4: Non-ATC volume by region ------------------------------------------------
-- Where the outside-ATC patients are, so outreach can be aimed geographically.
SELECT
    COALESCE(r.REGION, 'Unmapped')                               AS REGION,
    COUNT(DISTINCT a.D_PATIENT_ID)                               AS NON_ATC_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT a.D_PATIENT_ID)
          / SUM(COUNT(DISTINCT a.D_PATIENT_ID)) OVER (), 1)      AS PCT_OF_NON_ATC
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
    ON a.PRIMARY_HCO_NPI_STATE = r.STATE
WHERE a.CLASS_FINAL LIKE 'Non-ATC%'
GROUP BY 1
ORDER BY 2 DESC;


-- C5a: Within ATC - true site vs satellite (Kolin's question) -----------------
-- Same true-site / satellite definition that produced the 53% already in the deck.
SELECT
    CASE WHEN CLASS_HYBRID = 'ATC: NPI confirmed'
         THEN 'ATC - true site (NPI on authorized list)'
         ELSE 'ATC - satellite (ATC parent, site not on list)' END AS SITE_TYPE,
    COUNT(DISTINCT D_PATIENT_ID)                                  AS PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT D_PATIENT_ID)
          / SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER (), 1)         AS PCT_OF_ATC
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1
ORDER BY 2 DESC;


-- C5b: ATC satellite concentration by parent (min 10 ATC patients) ------------
SELECT
    HCO_PARENT_NAME,
    COUNT(DISTINCT D_PATIENT_ID)                                  AS ATC_PATIENTS,
    COUNT(DISTINCT CASE WHEN CLASS_HYBRID <> 'ATC: NPI confirmed'
          THEN D_PATIENT_ID END)                                 AS SATELLITE_PATIENTS,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN CLASS_HYBRID <> 'ATC: NPI confirmed'
          THEN D_PATIENT_ID END)
          / NULLIF(COUNT(DISTINCT D_PATIENT_ID), 0), 1)          AS PCT_SATELLITE
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1
HAVING COUNT(DISTINCT D_PATIENT_ID) >= 10
ORDER BY SATELLITE_PATIENTS DESC
LIMIT 25;
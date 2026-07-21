/* ============================================================================
   TEST FILE - Slide 4 journey, compare the definition options and choose one.

   PURPOSE
       Slide 3 (the 46% headline) counts a patient as ATC on NPI, the four roster
       patterns, OR a parent-name match to an authorized parent in two states or
       fewer (the "name fallback", ~3,678 patients, about half of ATC). The slide 4
       journey table was built on the NARROW definition (NPI + roster only), so the
       journey sees only ~3,924 ATC patients and shows almost no migration. This
       file tests the journey under each definition side by side so we can pick the
       honest one.

   HOW TO RUN
       The three base tables must already exist (ATC_CLASSIFIED_FINAL and
       ATC_TREATMENT_CLAIMS from the MASTER). This file only READS them - it does
       not rebuild anything. Run all, screenshot T1 through T4.

   WHAT EACH TEST ANSWERS
       T1  Narrow journey (current slide 4). The baseline, first claim site vs last
           claim site, NPI + roster only. Should reproduce 12,491 / 3,797 / 76 / 40.
       T2  Aligned journey. Same first-vs-last, but ATC now also includes the name
           fallback, so the journey uses the SAME definition as the 46% headline.
           This is the recommended fix. Read whether migration is still small.
       T3  Migration cohort (the deck's current 3,701 number). First claim site vs
           the patient's OVERALL classification. Shows what "3,701 moved to ATC"
           really measures - not a last-site trajectory, but a first-site vs
           where-they-were-classified cross. Explains the number on the slide today.
       T4  Reconciliation. ATC patients seen by each journey definition vs the 7,501
           headline. Confirms the aligned definition closes the gap.

   The name-fallback parent set is pulled straight from ATC_CLASSIFIED_FINAL
   (CLASS_HYBRID = name fallback AND CLASS_FINAL = ATC), so it already carries the
   two-state guard - no need to recompute the footprint here.
   ============================================================================ */


/* ---------------------------------------------------------------------------
   T1. NARROW journey - current slide 4 definition (NPI + roster only).
   Baseline. The four PATIENTS values sum to the journey population.
   --------------------------------------------------------------------------- */
WITH ranked AS (
    SELECT
        D_PATIENT_ID,
        IS_ATC_HCO,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE ASC,  D_PRIMARY_HCO_COMPILE_ID) AS RN_FIRST,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE DESC, D_PRIMARY_HCO_COMPILE_ID) AS RN_LAST
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
first_last AS (
    SELECT
        D_PATIENT_ID,
        MAX(CASE WHEN RN_FIRST = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
        MAX(CASE WHEN RN_LAST  = 1 THEN IS_ATC_HCO END) AS LAST_ATC
    FROM ranked
    GROUP BY 1
)
SELECT
    'T1 narrow'                                                                AS DEFINITION,
    CASE WHEN FIRST_ATC = 1 THEN 'Started at an ATC' ELSE 'Started non-ATC' END AS FIRST_SITE,
    CASE WHEN LAST_ATC  = 1 THEN 'Ended at an ATC'   ELSE 'Ended non-ATC'   END AS LAST_SITE,
    COUNT(*)                                           AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM first_last
GROUP BY 2, 3
ORDER BY 4 DESC;


/* ---------------------------------------------------------------------------
   T2. ALIGNED journey - add the name fallback so the journey matches the 46%
   headline. Recommended. Same first-vs-last logic, broader ATC flag.
   --------------------------------------------------------------------------- */
WITH name_fallback_parents AS (
    SELECT DISTINCT UPPER(TRIM(HCO_PARENT_NAME)) AS PARENT
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_HYBRID = 'ATC: name fallback'
      AND CLASS_FINAL  = 'ATC'
),
claims AS (
    SELECT
        t.D_PATIENT_ID,
        t.DATE_OF_SERVICE,
        t.D_PRIMARY_HCO_COMPILE_ID,
        CASE
            WHEN t.IS_ATC_HCO = 1                                             THEN 1
            WHEN UPPER(TRIM(t.HCO_PARENT_NAME)) IN
                 (SELECT PARENT FROM name_fallback_parents)                  THEN 1
            ELSE 0
        END AS IS_ATC_ALIGNED
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS t
),
ranked AS (
    SELECT
        D_PATIENT_ID,
        IS_ATC_ALIGNED,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE ASC,  D_PRIMARY_HCO_COMPILE_ID) AS RN_FIRST,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE DESC, D_PRIMARY_HCO_COMPILE_ID) AS RN_LAST
    FROM claims
),
first_last AS (
    SELECT
        D_PATIENT_ID,
        MAX(CASE WHEN RN_FIRST = 1 THEN IS_ATC_ALIGNED END) AS FIRST_ATC,
        MAX(CASE WHEN RN_LAST  = 1 THEN IS_ATC_ALIGNED END) AS LAST_ATC
    FROM ranked
    GROUP BY 1
)
SELECT
    'T2 aligned'                                                               AS DEFINITION,
    CASE WHEN FIRST_ATC = 1 THEN 'Started at an ATC' ELSE 'Started non-ATC' END AS FIRST_SITE,
    CASE WHEN LAST_ATC  = 1 THEN 'Ended at an ATC'   ELSE 'Ended non-ATC'   END AS LAST_SITE,
    COUNT(*)                                           AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM first_last
GROUP BY 2, 3
ORDER BY 4 DESC;


/* ---------------------------------------------------------------------------
   T3. MIGRATION COHORT - what the deck's 3,701 actually measures. First claim
   site (narrow) vs the patient's OVERALL classification (CLASS_FINAL, name
   fallback included). The "Started non-ATC / Classified ATC" cell should land
   near 3,701. This is a first-site vs classified cross, NOT a last-site journey.
   --------------------------------------------------------------------------- */
WITH ranked AS (
    SELECT
        D_PATIENT_ID,
        IS_ATC_HCO,
        ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID
                           ORDER BY DATE_OF_SERVICE ASC, D_PRIMARY_HCO_COMPILE_ID) AS RN
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
),
first_claim AS (
    SELECT
        D_PATIENT_ID,
        MAX(CASE WHEN RN = 1 THEN IS_ATC_HCO END) AS FIRST_ATC
    FROM ranked
    GROUP BY 1
)
SELECT
    'T3 migration cohort'                                                        AS DEFINITION,
    CASE WHEN fc.FIRST_ATC = 1 THEN 'Started at an ATC' ELSE 'Started non-ATC' END AS FIRST_SITE,
    CASE WHEN c.CLASS_FINAL = 'ATC' THEN 'Classified ATC' ELSE 'Classified non-ATC' END AS CLASSIFIED_AS,
    COUNT(*)                                           AS PATIENTS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM first_claim fc
JOIN COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL c
  ON fc.D_PATIENT_ID = c.D_PATIENT_ID
GROUP BY 2, 3
ORDER BY 4 DESC;


/* ---------------------------------------------------------------------------
   T4. RECONCILIATION - ATC patients each journey definition can see, against the
   7,501 headline. Narrow should sit near 3,924; aligned should climb toward
   7,501. Confirms the aligned definition actually closes the gap.
   --------------------------------------------------------------------------- */
WITH name_fallback_parents AS (
    SELECT DISTINCT UPPER(TRIM(HCO_PARENT_NAME)) AS PARENT
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_HYBRID = 'ATC: name fallback'
      AND CLASS_FINAL  = 'ATC'
),
flags AS (
    SELECT
        t.D_PATIENT_ID,
        MAX(t.IS_ATC_HCO) AS ANY_NARROW_ATC,
        MAX(CASE
                WHEN t.IS_ATC_HCO = 1                                            THEN 1
                WHEN UPPER(TRIM(t.HCO_PARENT_NAME)) IN
                     (SELECT PARENT FROM name_fallback_parents)                 THEN 1
                ELSE 0
            END) AS ANY_ALIGNED_ATC
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS t
    GROUP BY 1
)
SELECT
    (SELECT COUNT(DISTINCT D_PATIENT_ID)
       FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
      WHERE CLASS_FINAL = 'ATC')                       AS HEADLINE_ATC,
    SUM(ANY_NARROW_ATC)                                AS JOURNEY_ATC_NARROW,
    SUM(ANY_ALIGNED_ATC)                               AS JOURNEY_ATC_ALIGNED
FROM flags;
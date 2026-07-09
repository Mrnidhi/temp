/* =====================================================================
   CONTEST MASTER ANALYSIS  —  Q3 Enrollment Contest
   One script. Run each section, paste the output back labeled S1..S9.
   ---------------------------------------------------------------------
   Supersedes "Contest Opportunity Sizing.sql".
   Prereq: run git/NewCode.sql first (builds ATC_CLASSIFIED_FINAL,
   STATE_REGION_MAP). CTAM_ATC_ALIGNMENT_2026 already loaded.

   ⚠ PROXY: "patients" = metastatic-melanoma on Yervoy/Opdualag (McKesson
   claims) = the TIL-eligible MARKET PROXY (where future patients are),
   NOT actual Iovance enrollments. This sizes OPPORTUNITY + shows the
   distribution shape we use to set fair buckets/baselines. The real
   enrollment numbers come later from Infinity/CARES — the same method
   (Sections 6-7) then re-runs on that.

   HOW TO PASTE BACK: run top to bottom, copy each result, label it with
   its section number (S1, S2, ...). Small results — paste all rows.
   For S4/S6 (long) the top ~15 rows is plenty.
   ===================================================================== */


/* ====== S1. HEADLINE TOTALS (sanity) =============================== */
SELECT
    COUNT(DISTINCT D_PATIENT_ID)                                     AS ELIGIBLE_TOTAL,
    COUNT(DISTINCT IFF(CLASS_FINAL =  'ATC', D_PATIENT_ID, NULL))    AS ATC,
    COUNT(DISTINCT IFF(CLASS_FINAL <> 'ATC', D_PATIENT_ID, NULL))    AS UNTAPPED,
    ROUND(100.0 * COUNT(DISTINCT IFF(CLASS_FINAL='ATC', D_PATIENT_ID, NULL))
                / NULLIF(COUNT(DISTINCT D_PATIENT_ID),0), 1)         AS ATC_PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL;


/* ====== S2. OPPORTUNITY BY REGION (clean, all patients) =========== */
SELECT
    COALESCE(r.REGION,'Unmapped')                                        AS REGION,
    COUNT(DISTINCT a.D_PATIENT_ID)                                       AS ELIGIBLE,
    COUNT(DISTINCT IFF(a.CLASS_FINAL='ATC', a.D_PATIENT_ID, NULL))       AS ATC,
    COUNT(DISTINCT IFF(a.CLASS_FINAL<>'ATC', a.D_PATIENT_ID, NULL))      AS UNTAPPED,
    ROUND(100.0 * COUNT(DISTINCT IFF(a.CLASS_FINAL<>'ATC', a.D_PATIENT_ID, NULL))
                / NULLIF(COUNT(DISTINCT a.D_PATIENT_ID),0), 1)          AS UNTAPPED_PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
       ON a.PRIMARY_HCO_NPI_STATE = r.STATE
GROUP BY 1
ORDER BY ELIGIBLE DESC;


/* ====== S3. REGION DISTRIBUTION PROFILE (skew check) ============== */
WITH region_opp AS (
    SELECT COALESCE(r.REGION,'Unmapped') AS REGION,
           COUNT(DISTINCT IFF(a.CLASS_FINAL<>'ATC', a.D_PATIENT_ID, NULL)) AS UNTAPPED
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
    LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
           ON a.PRIMARY_HCO_NPI_STATE = r.STATE
    GROUP BY 1
)
SELECT COUNT(*)                                                   AS N_REGIONS,
       ROUND(AVG(UNTAPPED))                                       AS MEAN,
       MEDIAN(UNTAPPED)                                           AS MEDIAN,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY UNTAPPED)     AS P25,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY UNTAPPED)     AS P75,
       MIN(UNTAPPED)                                              AS MIN,
       MAX(UNTAPPED)                                              AS MAX,
       ROUND(AVG(UNTAPPED)/NULLIF(MEDIAN(UNTAPPED),0),2)          AS MEAN_MEDIAN_RATIO  -- >1.2 = right-skewed
FROM region_opp;


/* ====== S4. OPPORTUNITY BY STATE (top drivers — paste top ~15) ==== */
SELECT
    a.PRIMARY_HCO_NPI_STATE                                              AS STATE,
    COUNT(DISTINCT a.D_PATIENT_ID)                                       AS ELIGIBLE,
    COUNT(DISTINCT IFF(a.CLASS_FINAL='ATC', a.D_PATIENT_ID, NULL))       AS ATC,
    COUNT(DISTINCT IFF(a.CLASS_FINAL<>'ATC', a.D_PATIENT_ID, NULL))      AS UNTAPPED
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
GROUP BY 1
ORDER BY ELIGIBLE DESC;


/* ====== S5. OPPORTUNITY BY RAD REGION (sales-org lens) ============
   All patients, via a state -> RAD Region crosswalk from the roster
   (dominant region per state). Approx where a state splits regions. */
WITH state_to_rad AS (
    SELECT UPPER(TRIM("State")) AS STATE, MODE("RAD Region") AS RAD_REGION
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status"))='AUTHORIZED'
      AND "State" IS NOT NULL AND TRIM("State")<>''
      AND "RAD Region" IS NOT NULL AND TRIM("RAD Region")<>''
    GROUP BY 1
)
SELECT
    COALESCE(s.RAD_REGION,'(unmapped)')                                  AS RAD_REGION,
    COUNT(DISTINCT a.D_PATIENT_ID)                                       AS ELIGIBLE,
    COUNT(DISTINCT IFF(a.CLASS_FINAL='ATC', a.D_PATIENT_ID, NULL))       AS ATC,
    COUNT(DISTINCT IFF(a.CLASS_FINAL<>'ATC', a.D_PATIENT_ID, NULL))      AS UNTAPPED
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN state_to_rad s ON UPPER(TRIM(a.PRIMARY_HCO_NPI_STATE)) = s.STATE
GROUP BY 1
ORDER BY ELIGIBLE DESC;


/* ====== S6. ATC FOOTPRINT BY CTAM TERRITORY (more complete) =======
   Assigns each ATC patient to a territory by NPI first, else parent name.
   Recovers the big name-fallback centers (Fred Hutch, MSK, ...) the
   NPI-only join dropped. Parent->territory is approximate for multi-site
   parents. This is captured ATC volume (not untapped, not enrollments). */
WITH npi_terr AS (
    SELECT TRIM("NPI") AS NPI,
           MAX("CTAM Territory") AS TERR, MAX("CTAM Name") AS CTAM, MAX("RAD Region") AS RAD
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status"))='AUTHORIZED'
      AND "NPI" IS NOT NULL AND TRIM("NPI") NOT IN ('0','','NPI')
    GROUP BY 1
),
parent_terr AS (
    SELECT UPPER(TRIM("ATC HCO Parent Name (McKesson Claims)")) AS PARENT,
           MAX("CTAM Territory") AS TERR, MAX("CTAM Name") AS CTAM, MAX("RAD Region") AS RAD
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status"))='AUTHORIZED'
      AND "ATC HCO Parent Name (McKesson Claims)" IS NOT NULL
      AND TRIM("ATC HCO Parent Name (McKesson Claims)") NOT IN ('','null')
    GROUP BY 1
),
pat AS (
    SELECT a.D_PATIENT_ID,
           COALESCE(n.TERR, p.TERR) AS TERRITORY,
           COALESCE(n.CTAM, p.CTAM) AS CTAM,
           COALESCE(n.RAD,  p.RAD)  AS RAD_REGION
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
    LEFT JOIN npi_terr    n ON TRIM(a.D_PRIMARY_HCO_NPI) = n.NPI
    LEFT JOIN parent_terr p ON UPPER(TRIM(a.HCO_PARENT_NAME)) = p.PARENT
    WHERE a.CLASS_FINAL = 'ATC'
)
SELECT
    TERRITORY,
    ANY_VALUE(CTAM)                AS CTAM,
    ANY_VALUE(RAD_REGION)          AS RAD_REGION,
    COUNT(DISTINCT D_PATIENT_ID)   AS ATC_PATIENTS
FROM pat
WHERE TERRITORY IS NOT NULL
GROUP BY TERRITORY
ORDER BY ATC_PATIENTS DESC;


/* ====== S7. TERRITORY DISTRIBUTION PROFILE (the fairness evidence)
   Same assignment as S6, then profiles ATC_PATIENTS across territories.
   Mean vs median gap = how skewed territory size is = why we bucket. */
WITH npi_terr AS (
    SELECT TRIM("NPI") AS NPI, MAX("CTAM Territory") AS TERR
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status"))='AUTHORIZED'
      AND "NPI" IS NOT NULL AND TRIM("NPI") NOT IN ('0','','NPI') GROUP BY 1
),
parent_terr AS (
    SELECT UPPER(TRIM("ATC HCO Parent Name (McKesson Claims)")) AS PARENT, MAX("CTAM Territory") AS TERR
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status"))='AUTHORIZED'
      AND "ATC HCO Parent Name (McKesson Claims)" IS NOT NULL
      AND TRIM("ATC HCO Parent Name (McKesson Claims)") NOT IN ('','null') GROUP BY 1
),
terr_counts AS (
    SELECT COALESCE(n.TERR, p.TERR) AS TERRITORY, COUNT(DISTINCT a.D_PATIENT_ID) AS ATC_PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
    LEFT JOIN npi_terr    n ON TRIM(a.D_PRIMARY_HCO_NPI) = n.NPI
    LEFT JOIN parent_terr p ON UPPER(TRIM(a.HCO_PARENT_NAME)) = p.PARENT
    WHERE a.CLASS_FINAL='ATC' AND COALESCE(n.TERR,p.TERR) IS NOT NULL
    GROUP BY 1
)
SELECT COUNT(*)                                                    AS N_TERRITORIES,
       ROUND(AVG(ATC_PATIENTS))                                    AS MEAN,
       MEDIAN(ATC_PATIENTS)                                        AS MEDIAN,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ATC_PATIENTS)  AS P25,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ATC_PATIENTS)  AS P75,
       MIN(ATC_PATIENTS)                                           AS MIN,
       MAX(ATC_PATIENTS)                                           AS MAX,
       ROUND(AVG(ATC_PATIENTS)/NULLIF(MEDIAN(ATC_PATIENTS),0),2)   AS MEAN_MEDIAN_RATIO
FROM terr_counts;


/* ====== S8. STATE SPLITTABILITY (can claims resolve to territory?)
   If most states = 1 territory, claims can go to territory. If the big
   states split, territory truth must come from the enrollment data. */
SELECT UPPER(TRIM("State"))                     AS STATE,
       COUNT(DISTINCT "CTAM Territory")         AS TERRITORIES,
       LISTAGG(DISTINCT "CTAM Territory", ', ') AS WHICH
FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
WHERE UPPER(TRIM("Status"))='AUTHORIZED'
  AND "State" IS NOT NULL AND TRIM("State")<>''
  AND "CTAM Territory" IS NOT NULL
GROUP BY 1
ORDER BY TERRITORIES DESC, STATE;


/* ====== S9. DATA-QUALITY / COVERAGE (know the limits) =============
   How complete is the territory attribution + roster? */
WITH npi_terr AS (
    SELECT TRIM("NPI") AS NPI, MAX("CTAM Territory") AS TERR
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status"))='AUTHORIZED'
      AND "NPI" IS NOT NULL AND TRIM("NPI") NOT IN ('0','','NPI') GROUP BY 1
),
parent_terr AS (
    SELECT UPPER(TRIM("ATC HCO Parent Name (McKesson Claims)")) AS PARENT, MAX("CTAM Territory") AS TERR
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status"))='AUTHORIZED'
      AND "ATC HCO Parent Name (McKesson Claims)" IS NOT NULL
      AND TRIM("ATC HCO Parent Name (McKesson Claims)") NOT IN ('','null') GROUP BY 1
)
SELECT
    (SELECT COUNT(DISTINCT "CTAM Territory") FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
       WHERE UPPER(TRIM("Status"))='AUTHORIZED' AND "CTAM Territory" IS NOT NULL)      AS ROSTER_TERRITORIES,
    COUNT(DISTINCT IFF(a.CLASS_FINAL='ATC', a.D_PATIENT_ID, NULL))                      AS ATC_TOTAL,
    COUNT(DISTINCT IFF(a.CLASS_FINAL='ATC' AND (n.TERR IS NOT NULL OR p.TERR IS NOT NULL),
                       a.D_PATIENT_ID, NULL))                                          AS ATC_ASSIGNED_TO_TERR,
    ROUND(100.0 * COUNT(DISTINCT IFF(a.CLASS_FINAL='ATC' AND (n.TERR IS NOT NULL OR p.TERR IS NOT NULL), a.D_PATIENT_ID, NULL))
                / NULLIF(COUNT(DISTINCT IFF(a.CLASS_FINAL='ATC', a.D_PATIENT_ID, NULL)),0), 1) AS PCT_ATC_ASSIGNED,
    COUNT(DISTINCT IFF(a.PRIMARY_HCO_NPI_STATE IS NULL OR TRIM(a.PRIMARY_HCO_NPI_STATE)='',
                       a.D_PATIENT_ID, NULL))                                          AS PATIENTS_NO_STATE
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN npi_terr    n ON TRIM(a.D_PRIMARY_HCO_NPI) = n.NPI
LEFT JOIN parent_terr p ON UPPER(TRIM(a.HCO_PARENT_NAME)) = p.PARENT;
-- end of script (S1-S9 above)

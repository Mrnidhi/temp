/* =====================================================================
   CONTEST OPPORTUNITY SIZING  —  Q3 Enrollment Contest
   ---------------------------------------------------------------------
   Sizes the addressable melanoma market and the UNTAPPED (non-ATC) pool
   by region and by CTAM territory — the input for making the contest fair
   across uneven territories.

   RUNS ENTIRELY ON DATA ALREADY IN SNOWFLAKE — no new access needed.
   Prereq: run git/NewCode.sql first (builds ATC_CLASSIFIED_FINAL,
   STATE_REGION_MAP). CTAM_ATC_ALIGNMENT_2026 is already loaded.

   PROXY NOTE: patients = metastatic-melanoma on Yervoy/Opdualag (McKesson
   claims) = the TIL-eligible MARKET PROXY (where future patients are),
   NOT Iovance's actual enrollments. This sizes OPPORTUNITY, not performance.
   ===================================================================== */


/* ---- Q1. OPPORTUNITY BY REGION (clean, all patients) --------------- */
SELECT
    COALESCE(r.REGION, 'Unmapped')                                      AS REGION,
    COUNT(DISTINCT a.D_PATIENT_ID)                                      AS ELIGIBLE,
    COUNT(DISTINCT IFF(a.CLASS_FINAL =  'ATC', a.D_PATIENT_ID, NULL))   AS ATC,
    COUNT(DISTINCT IFF(a.CLASS_FINAL <> 'ATC', a.D_PATIENT_ID, NULL))   AS UNTAPPED,   -- the opportunity
    ROUND(100.0 * COUNT(DISTINCT IFF(a.CLASS_FINAL <> 'ATC', a.D_PATIENT_ID, NULL))
                / NULLIF(COUNT(DISTINCT a.D_PATIENT_ID), 0), 1)         AS UNTAPPED_PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r
       ON a.PRIMARY_HCO_NPI_STATE = r.STATE
GROUP BY 1
ORDER BY ELIGIBLE DESC;
-- Swap STATE_REGION_MAP for the roster's "RAD Region" if Kolin wants the sales-org lens.


/* ---- Q2. ATC FOOTPRINT BY CTAM TERRITORY (exact, uses the alignment)
   Captured ATC patients pinned to each territory via treating NPI.
   Exact for ATC volume; untapped-per-territory needs the enrollment
   numerator (see note at bottom), so region (Q1) is the clean untapped view. */
WITH npi_to_terr AS (
    SELECT TRIM("NPI")           AS NPI,
           MAX("CTAM Territory") AS TERRITORY,
           MAX("CTAM Name")      AS CTAM,
           MAX("RAD Region")     AS RAD_REGION
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status")) = 'AUTHORIZED'
      AND "NPI" IS NOT NULL AND TRIM("NPI") NOT IN ('0','','NPI')
    GROUP BY 1
)
SELECT
    t.TERRITORY,
    ANY_VALUE(t.CTAM)                  AS CTAM,
    ANY_VALUE(t.RAD_REGION)            AS RAD_REGION,
    COUNT(DISTINCT a.D_PATIENT_ID)     AS ATC_PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
JOIN npi_to_terr t ON TRIM(a.D_PRIMARY_HCO_NPI) = t.NPI
WHERE a.CLASS_FINAL = 'ATC'
GROUP BY t.TERRITORY
ORDER BY ATC_PATIENTS DESC;


/* ---- Q3. SANITY CHECK: does a state ever hold >1 territory? ---------
   If most states = 1 territory, we can push Q1's untapped pool down to
   territory level with just the claims. If not, we lean on region + the
   enrollment data for territory precision. */
SELECT UPPER(TRIM("State"))                     AS STATE,
       COUNT(DISTINCT "CTAM Territory")         AS TERRITORIES,
       LISTAGG(DISTINCT "CTAM Territory", ', ') AS WHICH
FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
WHERE UPPER(TRIM("Status")) = 'AUTHORIZED'
  AND "State" IS NOT NULL AND TRIM("State") <> ''
  AND "CTAM Territory" IS NOT NULL
GROUP BY 1
ORDER BY TERRITORIES DESC, STATE;


/* =====================================================================
   READ-OUT: UNTAPPED = the enrollment opportunity. If it's lopsided by
   region/territory, the contest must be normalized by opportunity (bucket
   or penetration), not scored on raw volume.
   To SCORE the contest we still need one thing: actual ENROLLMENTS by
   territory — which is the same CARES/Infinity data already coming for the
   PPR dashboard. Nothing else new required.
   ===================================================================== */
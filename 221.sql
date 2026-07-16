/* ==========================================================================
   STEP 1 - REBUILD ATC_CLASSIFIED_FINAL WITH THE ROSTER GAP CORRECTION
   Paste this whole file into Snowflake and run it. Then run the post-checks in
   "Verify roster gap correction.sql".

   This is Step 1 of git/NewCode.sql with the roster_gap_parent correction added.
   It REPLACES the existing ATC_CLASSIFIED_FINAL table (same as the original
   pipeline does), so everything downstream reads the corrected classification.

   Nothing else in NewCode.sql changes.
   ========================================================================== */

SET fallback_state_limit = 2;

CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL AS
WITH auth_npi AS (
    SELECT DISTINCT TRIM("NPI") AS NPI
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status")) = 'AUTHORIZED'
      AND "NPI" IS NOT NULL
      AND TRIM("NPI") NOT IN ('0', '', 'NPI')
),
auth_parent AS (
    SELECT DISTINCT UPPER(TRIM("ATC HCO Parent Name (McKesson Claims)")) AS PARENT
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status")) = 'AUTHORIZED'
      AND "ATC HCO Parent Name (McKesson Claims)" IS NOT NULL
      AND TRIM("ATC HCO Parent Name (McKesson Claims)") NOT IN ('', 'null')
),
-- Roster gap correction (2026-07-16).
-- These four organisations are missing from CTAM_ATC_ALIGNMENT_2026, so their
-- patients scored Non-ATC. Each confirmed against Infinity's authoritative ATC
-- master (file_Veeva_Komodo_ATC_Mapping, 93 accounts).
-- They bypass the fallback_state_limit guard deliberately: confirmed authorized,
-- not inferred from a fuzzy name match.
-- Retire this CTE once the source roster itself is fixed.
roster_gap_parent AS (
    SELECT PARENT FROM VALUES
        ('CITY OF HOPE'),
        ('NYU LANGONE HEALTH SYSTEM'),
        ('THE OHIO STATE UNIVERSITY WEXNER MEDICAL CENTER'),
        ('HOAG HOSPITAL NEWPORT BEACH')
    AS t(PARENT)
),
classified AS (
    SELECT
        p.*,
        CASE
            WHEN p.HCO_COMMUNITY_NETWORK IN (
                    'THE US ONCOLOGY NETWORK',
                    'ONE ONCOLOGY',
                    'AMERICAN ONCOLOGY NETWORK')
                THEN 'Non-ATC: Community Network'
            WHEN n.NPI IS NOT NULL
                THEN 'ATC: NPI confirmed'
            WHEN rg.PARENT IS NOT NULL
                THEN 'ATC: roster gap corrected'
            WHEN ap.PARENT IS NOT NULL
                THEN 'ATC: name fallback'
            WHEN EXISTS (
                    SELECT 1 FROM auth_parent x
                    WHERE UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%' || x.PARENT || '%'
                       OR x.PARENT LIKE '%' || UPPER(TRIM(p.HCO_PARENT_NAME)) || '%')
                THEN 'Needs Review'
            WHEN p.HCO_PARENT_NAME IS NULL
                THEN 'Non-ATC: Unknown'
            ELSE 'Non-ATC'
        END AS CLASS_HYBRID
    FROM COMPILE_DEV.PUBLIC.ATC_SOC_PATIENT_CLASSIFIED_2021_2025 p
    LEFT JOIN auth_npi    n  ON TRIM(p.D_PRIMARY_HCO_NPI) = n.NPI
    LEFT JOIN auth_parent ap ON UPPER(TRIM(p.HCO_PARENT_NAME)) = ap.PARENT
    LEFT JOIN roster_gap_parent rg ON UPPER(TRIM(p.HCO_PARENT_NAME)) = rg.PARENT
),
fallback_footprint AS (
    SELECT HCO_PARENT_NAME,
           COUNT(DISTINCT PRIMARY_HCO_NPI_STATE) AS PARENT_STATES
    FROM classified
    WHERE CLASS_HYBRID = 'ATC: name fallback'
    GROUP BY 1
)
SELECT
    c.*,
    f.PARENT_STATES,
    CASE
        WHEN c.CLASS_HYBRID = 'ATC: NPI confirmed'                                              THEN 'ATC'
        WHEN c.CLASS_HYBRID = 'ATC: roster gap corrected'                                       THEN 'ATC'
        WHEN c.CLASS_HYBRID = 'ATC: name fallback' AND f.PARENT_STATES <= $fallback_state_limit THEN 'ATC'
        WHEN c.CLASS_HYBRID = 'ATC: name fallback' AND f.PARENT_STATES >  $fallback_state_limit THEN 'Non-ATC: System sweep'
        WHEN c.CLASS_HYBRID = 'Needs Review'                                                    THEN 'Needs Review'
        ELSE c.CLASS_HYBRID
    END AS CLASS_FINAL
FROM classified c
LEFT JOIN fallback_footprint f
    ON c.HCO_PARENT_NAME = f.HCO_PARENT_NAME;
/* ============================================================================
   PATIENT DATA — the one table the dashboard needs.
   One row per patient, 17 columns that match the "Patient Data" tab headers.

   HOW TO USE
     1. If the base tables are not already built, run PART A of
        "Site of Care - FINAL Snowflake code (build + all slide outputs).sql"
        first (it builds ATC_CLASSIFIED_FINAL, ATC_TREATMENT_CLAIMS,
        STATE_REGION_MAP). If you built them earlier today, skip this.
     2. Run the query below.
     3. Export the result grid as CSV named  patient_data.csv
     4. Either paste it into the Patient Data tab (A4, keep the headers),
        or drop it next to build_workbook.py and run that script.
   ============================================================================ */

WITH claim_roll AS (
    SELECT D_PATIENT_ID,
           MIN(YEAR(DATE_OF_SERVICE))                                       AS FIRST_YEAR,
           COUNT(*)                                                         AS TREATMENT_CLAIMS,
           MAX(CASE WHEN DRUG = 'Yervoy'   THEN 1 ELSE 0 END)               AS YERVOY,
           MAX(CASE WHEN DRUG = 'Opdualag' THEN 1 ELSE 0 END)               AS OPDUALAG,
           DATEDIFF('day', MIN(FIRST_DX_DATE), MIN(DATE_OF_SERVICE))        AS DAYS_DX_TO_TX
    FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    GROUP BY 1
),
first_last AS (
    SELECT D_PATIENT_ID,
           MAX(CASE WHEN rn_first = 1 THEN IS_ATC_HCO END) AS FIRST_ATC,
           MAX(CASE WHEN rn_last  = 1 THEN IS_ATC_HCO END) AS LAST_ATC
    FROM (
        SELECT D_PATIENT_ID, IS_ATC_HCO,
               ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE ASC,  D_PRIMARY_HCO_COMPILE_ID) AS rn_first,
               ROW_NUMBER() OVER (PARTITION BY D_PATIENT_ID ORDER BY DATE_OF_SERVICE DESC, D_PRIMARY_HCO_COMPILE_ID) AS rn_last
        FROM COMPILE_DEV.PUBLIC.ATC_TREATMENT_CLAIMS
    )
    GROUP BY 1
)
SELECT
    c.D_PATIENT_ID                                                          AS patient_id,
    CASE WHEN c.CLASS_FINAL = 'ATC'                                  THEN 'ATC'
         WHEN c.CLASS_FINAL = 'Non-ATC: Community Network'           THEN 'Non-ATC: Community network'
         WHEN c.CLASS_FINAL IN ('Non-ATC: Unknown','Needs Review')   THEN 'Non-ATC: Other'
         ELSE 'Non-ATC: Hospital' END                                      AS site_bucket,
    CASE WHEN c.CLASS_FINAL = 'ATC' THEN 1 ELSE 0 END                      AS is_atc,
    c.CLASS_HYBRID                                                          AS class_hybrid,
    CASE WHEN c.CLASS_HYBRID = 'ATC: NPI confirmed'        THEN 'NPI-confirmed'
         WHEN c.CLASS_HYBRID = 'ATC: roster gap corrected' THEN 'Roster-confirmed'
         WHEN c.CLASS_HYBRID = 'ATC: name fallback'        THEN 'Name-matched'
         ELSE '-' END                                                      AS match_basis,
    COALESCE(NULLIF(TRIM(c.HCO_PARENT_NAME), ''), 'Unknown / unmapped')     AS account_parent,
    COALESCE(c.HCO_COMMUNITY_NETWORK,
             CASE WHEN c.CLASS_FINAL = 'ATC' THEN '-' ELSE 'Independent / Other' END) AS community_network,
    c.PRIMARY_HCO_NPI_STATE                                                 AS state,
    COALESCE(r.REGION, 'Unmapped')                                         AS region,
    cr.FIRST_YEAR                                                          AS first_year,
    fl.FIRST_ATC                                                           AS started_atc,
    CASE WHEN fl.FIRST_ATC = 1 THEN 'ATC' ELSE 'Non-ATC' END              AS first_site,
    CASE WHEN fl.LAST_ATC  = 1 THEN 'ATC' ELSE 'Non-ATC' END              AS last_site,
    cr.DAYS_DX_TO_TX                                                       AS days_dx_to_tx,
    COALESCE(cr.TREATMENT_CLAIMS, 0)                                       AS treatment_claims,
    COALESCE(cr.YERVOY, 0)                                                 AS yervoy,
    COALESCE(cr.OPDUALAG, 0)                                               AS opdualag
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL c
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r ON c.PRIMARY_HCO_NPI_STATE = r.STATE
LEFT JOIN claim_roll  cr ON c.D_PATIENT_ID = cr.D_PATIENT_ID
LEFT JOIN first_last  fl ON c.D_PATIENT_ID = fl.D_PATIENT_ID;

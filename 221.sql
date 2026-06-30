CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_HYBRID AS
WITH auth_npi AS (
    SELECT DISTINCT TRIM("NPI") AS NPI
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status")) = 'AUTHORIZED'
      AND "NPI" IS NOT NULL AND TRIM("NPI") NOT IN ('0','','NPI')
),
auth_parent AS (
    SELECT DISTINCT UPPER(TRIM("ATC HCO Parent Name (McKesson Claims)")) AS PARENT
    FROM COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026
    WHERE UPPER(TRIM("Status")) = 'AUTHORIZED'
      AND "ATC HCO Parent Name (McKesson Claims)" IS NOT NULL
      AND TRIM("ATC HCO Parent Name (McKesson Claims)") NOT IN ('','null')
)
SELECT
    p.*,
    CASE
        -- community network always wins, it's leakage by definition
        WHEN p.HCO_COMMUNITY_NETWORK IN
             ('THE US ONCOLOGY NETWORK','ONE ONCOLOGY','AMERICAN ONCOLOGY NETWORK')
            THEN 'Non-ATC: Community Network'
        -- rung 1: trustworthy NPI match
        WHEN n.NPI IS NOT NULL
            THEN 'ATC: NPI confirmed'
        -- rung 2: exact authorized-parent fallback when NPI missing
        WHEN ap.PARENT IS NOT NULL
            THEN 'ATC: name fallback'
        -- rung 3: fuzzy near-miss on an authorized parent
        WHEN EXISTS (
            SELECT 1 FROM auth_parent x
            WHERE UPPER(TRIM(p.HCO_PARENT_NAME)) LIKE '%' || x.PARENT || '%'
               OR x.PARENT LIKE '%' || UPPER(TRIM(p.HCO_PARENT_NAME)) || '%'
        ) THEN 'Needs Review'
        WHEN p.HCO_PARENT_NAME IS NULL
            THEN 'Non-ATC: Unknown'
        ELSE 'Non-ATC'
    END AS CLASS_HYBRID
FROM COMPILE_DEV.PUBLIC.ATC_SOC_PATIENT_CLASSIFIED_2021_2025 p
LEFT JOIN auth_npi    n  ON TRIM(p.D_PRIMARY_HCO_NPI) = n.NPI
LEFT JOIN auth_parent ap ON UPPER(TRIM(p.HCO_PARENT_NAME)) = ap.PARENT;



SELECT CLASS_HYBRID,
       COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
       ROUND(100.0*COUNT(DISTINCT D_PATIENT_ID)/SUM(COUNT(DISTINCT D_PATIENT_ID)) OVER(),1) AS PCT
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_HYBRID
GROUP BY 1 ORDER BY 2 DESC;
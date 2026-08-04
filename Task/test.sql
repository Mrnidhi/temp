/* ============================================================================
   The two ATCs that need a decision

   One small grid, meant to be screenshotted into an email. Read only.

   Everything else on the list matched. These two did not, and both are the
   same shape of problem: Compile holds more than one organisation that could
   reasonably be the centre, they sit under different HCOs, and picking the
   wrong one would send the payer mix work to the wrong place.

   One row per HCO, because the HCO is what actually goes in the sheet.
   ============================================================================ */

WITH candidates AS (
    SELECT
        CASE WHEN f.FACILITY_STATE = 'SD' THEN 'Avera McKennan Hospital'
             ELSE                              'TriHealth'
        END AS ATC_ON_YOUR_LIST,
        CASE WHEN f.FACILITY_STATE = 'SD' THEN '1325 S Cliff Ave, Sioux Falls SD'
             ELSE                              '625 Eden Park Dr, Cincinnati OH'
        END AS ADDRESS_ON_YOUR_LIST,
        f.FACILITY_NAME           AS COMPILE_FACILITY,
        f.FACILITY_ADDRESS_LINE_1 AS COMPILE_ADDRESS,
        f.FACILITY_CITY           AS COMPILE_CITY,
        h.HCO_NAME                AS COMPILE_HCO,
        h.D_HCO_COMPILE_ID        AS HCO_ID
    FROM COMPILE_PROVIDER360.ENTITIES.IOV2501_FACILITY_ATTRIBUTES f
    LEFT JOIN COMPILE_PROVIDER360.RELATIONSHIPS.IOV2501_HCO_FULL_HIERARCHY h
           ON f.D_FACILITY_COMPILE_ID = h.D_FACILITY_COMPILE_ID
    WHERE
        -- Avera. The transplant institute is one building from the address on
        -- the list; the other Avera entity is on a different street entirely.
        (f.FACILITY_STATE = 'SD' AND UPPER(f.FACILITY_NAME) LIKE 'AVERA MCKENNAN%')
        -- TriHealth. The address on the list is a corporate office, so these
        -- are the two TriHealth hospitals Compile holds in Cincinnati.
     OR (f.FACILITY_STATE = 'OH'
         AND (UPPER(f.FACILITY_NAME) LIKE '%GOOD SAMARITAN HOSPITAL OF CINCINNATI%'
           OR UPPER(f.FACILITY_NAME) LIKE 'BETHESDA NORTH%'))
)
SELECT *
FROM candidates
-- One row per organisation. Good Samaritan has several buildings and showing
-- all of them would make the question look messier than it is.
QUALIFY ROW_NUMBER() OVER (PARTITION BY HCO_ID ORDER BY COMPILE_ADDRESS) = 1
ORDER BY ATC_ON_YOUR_LIST, COMPILE_FACILITY;

/* ============================================================================
   TEST - ATC to Compile crosswalk verification
   Read only. Nothing here creates, replaces or drops anything, so Run All is
   safe and can be repeated as often as you like.

   BEFORE RUNNING THIS
       Re-run Step 3 and Step 4 of the main file first, so the tables carry the
       corrected tier and sort rules. T0 tells you whether that actually
       happened, so if you forgot, you will find out in the first grid rather
       than after reading nine of them.

   WHAT TO SEND BACK
       One screenshot per numbered block, in order. Each is kept narrow enough
       to be readable in a photo. If a grid scrolls, the rows that matter are
       sorted to the top on purpose.

   WHAT EACH ONE SETTLES
       T0  did the corrected build actually run
       T1  every row, address in the sheet against address in Compile   <- the important one
       T2  city and zip disagreements
       T3  how the 22 rows distribute across the tiers
       T4  HCO coverage, and an independent proof the HCO join is right
       T5  the review worklist, every candidate for every unconfirmed row
       T6  why UF Health found nothing
       T7  the non-hospital matches, in full
       T8  rows where the NPI and the address disagree with each other
   ============================================================================ */


/* ---------------------------------------------------------------------------
   T0. Build freshness. LAST_ALTERED must be later than the moment you re-ran
       Steps 3 and 4. If it is not, the grids below describe the OLD logic and
       everything after this is misleading.
   --------------------------------------------------------------------------- */
SELECT
    TABLE_NAME,
    ROW_COUNT,
    LAST_ALTERED
FROM COMPILE_DEV.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'PUBLIC'
  AND TABLE_NAME LIKE 'ATC_XWALK%'
ORDER BY TABLE_NAME;


/* ---------------------------------------------------------------------------
   T1. THE IMPORTANT ONE. Every ATC, the address the business owner supplied
       against the address on the facility that was picked.

       Sorted worst first, so if the screenshot cuts off, the rows I need are
       still in frame. ADDR_SIM is 0 to 100. Anything below about 90 needs a
       human to look at it; 100 means the two addresses normalised identically.
   --------------------------------------------------------------------------- */
SELECT
    SHEET_ROW,
    LEFT(ATC_NAME, 34)      AS ATC_NAME,
    LEFT(ATC_ADDRESS, 24)   AS SHEET_ADDRESS,
    LEFT(FAC_ADDR_NORM, 24) AS COMPILE_ADDRESS,
    ADDR_SIM,
    NAME_SIM,
    MATCH_TIER,
    LEFT(MATCH_STATUS, 26)  AS MATCH_STATUS
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
ORDER BY ADDR_SIM NULLS FIRST, SHEET_ROW;


/* ---------------------------------------------------------------------------
   T2. City and zip disagreements on rows that DID match. This is the Gilbert
       versus Phoenix question answered for the whole list at once.

       A row here is not automatically a bad match. The match was made on the
       street, and Compile usually carries the address of the real building
       while a sheet can carry a mailing or campus address. It is a list to
       take back to the owner, not a list to delete.
   --------------------------------------------------------------------------- */
SELECT
    SHEET_ROW,
    LEFT(ATC_NAME, 30) AS ATC_NAME,
    ATC_CITY           AS SHEET_CITY,
    FAC_CITY           AS COMPILE_CITY,
    ATC_ZIP5           AS SHEET_ZIP,
    FAC_ZIP5           AS COMPILE_ZIP,
    ADDR_SIM,
    MATCH_TIER
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
WHERE D_FACILITY_COMPILE_ID IS NOT NULL
  AND (ATC_CITY <> FAC_CITY OR ATC_ZIP5 <> FAC_ZIP5)
ORDER BY SHEET_ROW;


/* ---------------------------------------------------------------------------
   T3. Tier distribution after the correction. Compare against the run of
       2026-08-04, which was tier1 13, tier2 6, tier3 1, tier5 1, no match 1.
       Tier 1 should now be SMALLER, because it demands the zip as well as the
       NPI, and the rows it loses should surface at tier 6.
   --------------------------------------------------------------------------- */
SELECT
    COALESCE(MATCH_TIER, 0) AS MATCH_TIER,
    CASE COALESCE(MATCH_TIER, 0)
        WHEN 0 THEN 'no match at all'
        WHEN 1 THEN 'NPI + zip agree'
        WHEN 2 THEN 'zip + full address'
        WHEN 3 THEN 'zip + number + street'
        WHEN 4 THEN 'city + number + street'
        WHEN 5 THEN 'state + number + close address'
        WHEN 6 THEN 'NPI agrees, ADDRESS DOES NOT'
        WHEN 7 THEN 'name only, never pasted'
    END AS MEANING,
    COUNT(*) AS ATCS
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
GROUP BY 1, 2
ORDER BY 1;


/* ---------------------------------------------------------------------------
   T4. HCO coverage, plus an independent proof that the HCO join is correct.

       The facility ID turned out to be a composite: LOC-xxxxx+H-yyyyy, and the
       part after the plus IS the HCO ID. So the facility ID already carries the
       answer, and splitting it gives a second route to the same value that
       never touches the hierarchy table.

       ID_SUFFIX_MATCHES_HCO must be true on every row that matched. If it is,
       the join in Step 4 is proven right for the whole list, not just for the
       four rows the owner filled in by hand.
   --------------------------------------------------------------------------- */
SELECT
    SHEET_ROW,
    LEFT(ATC_NAME, 30)                                AS ATC_NAME,
    D_HCO_COMPILE_ID,
    LEFT(HCO_NAME, 30)                                AS HCO_NAME,
    SPLIT_PART(D_FACILITY_COMPILE_ID, '+', 2)         AS ID_SUFFIX,
    SPLIT_PART(D_FACILITY_COMPILE_ID, '+', 2)
        = D_HCO_COMPILE_ID                            AS ID_SUFFIX_MATCHES_HCO
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
WHERE D_FACILITY_COMPILE_ID IS NOT NULL
ORDER BY ID_SUFFIX_MATCHES_HCO, SHEET_ROW;


/* ---------------------------------------------------------------------------
   T5. The review worklist. Every candidate facility for every ATC that is not
       a clean, location-confirmed match, so a choice can be made on evidence
       instead of on the sort order.

       PICK says which one the query took. Read the addresses, not the names.
   --------------------------------------------------------------------------- */
SELECT
    c.SHEET_ROW,
    LEFT(m.ATC_NAME, 26)       AS ATC_NAME,
    LEFT(m.ATC_ADDRESS, 20)    AS SHEET_ADDRESS,
    LEFT(c.FACILITY_NAME, 28)  AS CANDIDATE_NAME,
    LEFT(c.FAC_ADDR_NORM, 20)  AS CANDIDATE_ADDRESS,
    c.FAC_CITY,
    c.FAC_ZIP5,
    c.FACILITY_TYPE,
    c.ADDR_SIM,
    c.MATCH_TIER,
    CASE WHEN c.FACILITY_ID = m.D_FACILITY_COMPILE_ID THEN 'PICKED' ELSE '' END AS PICK
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_CANDIDATES c
INNER JOIN COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED m ON c.SHEET_ROW = m.SHEET_ROW
WHERE m.MATCH_STATUS <> 'OK'
ORDER BY c.SHEET_ROW, c.MATCH_TIER, c.ADDR_SIM DESC;


/* ---------------------------------------------------------------------------
   T6. Why UF Health Cancer Center found nothing. 2033 Mowry Rd, Gainesville FL
       32610. This looks in the facility table directly, with no matching logic
       in the way, so it separates "the building is not in Compile" from "our
       matching rules could not reach it".
   --------------------------------------------------------------------------- */
SELECT
    D_FACILITY_COMPILE_ID,
    LEFT(FACILITY_NAME, 40) AS FACILITY_NAME,
    FACILITY_TYPE,
    FACILITY_ADDRESS_LINE_1,
    FACILITY_CITY,
    FACILITY_ZIP_5
FROM COMPILE_PROVIDER360.ENTITIES.IOV2501_FACILITY_ATTRIBUTES
WHERE FACILITY_STATE = 'FL'
  AND (FACILITY_ZIP_5 = '32610'
       OR UPPER(FACILITY_CITY) = 'GAINESVILLE')
ORDER BY FACILITY_TYPE, FACILITY_NAME
LIMIT 40;


/* ---------------------------------------------------------------------------
   T7. Every ATC whose best match is not typed HOSPITALS, with its address
       similarity beside it. A high ADDR_SIM here means the type is the only
       thing unusual and the row is fine; a low one means the type flag is
       pointing at a genuine problem.
   --------------------------------------------------------------------------- */
SELECT
    SHEET_ROW,
    LEFT(ATC_NAME, 30)      AS ATC_NAME,
    LEFT(FACILITY_NAME, 34) AS FACILITY_NAME,
    FACILITY_TYPE,
    ADDR_SIM,
    MATCH_TIER
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
WHERE D_FACILITY_COMPILE_ID IS NOT NULL
  AND FACILITY_TYPE <> 'HOSPITALS'
ORDER BY ADDR_SIM, SHEET_ROW;


/* ---------------------------------------------------------------------------
   T8. Rows where the NPI points one way and the address points another.

       For every ATC with a real NPI, this shows the facility the NPI leads to
       beside the facility the address leads to. Where they differ, the address
       wins under your rule, and this grid is the evidence for saying so.
   --------------------------------------------------------------------------- */
WITH by_npi AS (
    SELECT
        m.SHEET_ROW,
        c.FACILITY_ID  AS NPI_FACILITY_ID,
        c.FAC_ADDR_NORM AS NPI_ADDRESS,
        c.ADDR_SIM      AS NPI_ADDR_SIM
    FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED m
    INNER JOIN COMPILE_DEV.PUBLIC.ATC_XWALK_CANDIDATES c
            ON m.SHEET_ROW = c.SHEET_ROW
    WHERE m.ATC_NPI IS NOT NULL
      AND c.MATCH_TIER IN (1, 6)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY m.SHEET_ROW
                               ORDER BY c.ADDR_SIM DESC, c.FACILITY_ID) = 1
)
SELECT
    m.SHEET_ROW,
    LEFT(m.ATC_NAME, 26)    AS ATC_NAME,
    LEFT(m.ATC_ADDRESS, 20) AS SHEET_ADDRESS,
    LEFT(n.NPI_ADDRESS, 20) AS ADDRESS_THE_NPI_LEADS_TO,
    n.NPI_ADDR_SIM,
    LEFT(m.FAC_ADDR_NORM, 20) AS ADDRESS_WE_PICKED,
    m.ADDR_SIM              AS PICKED_ADDR_SIM,
    m.MATCH_TIER
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED m
INNER JOIN by_npi n ON m.SHEET_ROW = n.SHEET_ROW
ORDER BY n.NPI_ADDR_SIM, m.SHEET_ROW;

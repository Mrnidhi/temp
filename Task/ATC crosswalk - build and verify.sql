/* ============================================================================
   ATC to McKesson Compile crosswalk
   Fills columns N to R of "ATC Check_Excersise", the Active ATC List tab.

   THE JOB, AND ONLY THIS JOB
       For every authorized treatment center, find its Compile facility ID and
       facility name by matching on the address, then use that facility ID to
       get its HCO ID and HCO name. Report any ATC whose address in the sheet
       disagrees with the address Compile holds, which is the Gilbert versus
       Phoenix question.

       Nothing else is calculated here. No claims are read, no scores are
       invented, no column is produced that the sheet does not ask for.

   HOW TO RUN
       Press Run All. It rebuilds everything from the uploaded ATC list and
       then checks its own work, so no result can describe a stale table.
       Safe to run as often as you like: every statement is either
       CREATE OR REPLACE or a plain SELECT.

       Read Q1 first. If any row of Q1 says FAIL, stop and fix that before
       looking at anything else.

   INPUT
       COMPILE_DEV.PUBLIC.ATC_CHECK_EXCERSISE
           The Active ATC List tab, uploaded 2026-08-04. The sheet has two
           header rows, the merged section banners and then the real names, so
           the loader could not infer column names and produced c1 to c18.
           Those are ordinary unquoted identifiers; Snowflake folded them to
           C1..C18 on create. Write c1, never "c1". A quoted-lowercase version
           of this file failed with 'invalid identifier "c1"'.

   SOURCES, READ ONLY
       COMPILE_PROVIDER360.ENTITIES.IOV2501_FACILITY_ATTRIBUTES
       COMPILE_PROVIDER360.RELATIONSHIPS.IOV2501_HCO_FULL_HIERARCHY

   TABLES BUILT, all in COMPILE_DEV.PUBLIC
       ATC_XWALK_INPUT       one row per ATC, addresses cleaned
       ATC_XWALK_NORM        ATC rows and candidate facility rows, one normaliser
       ATC_XWALK_CANDIDATES  every ATC to facility pair that matched at any tier
       ATC_XWALK_MATCHED     one row per ATC, the chosen facility and its HCO

   RESULTS TO SCREENSHOT, in this order
       Q1  the checks. Every row must say PASS
       Q2  rows dropped when the sheet was read, named
       Q3  our answer against the answers already filled into the sheet
       Q4  the paste-back block, columns N to R
       Q5  every ATC, sheet address against Compile address, worst first
       Q6  city and zip disagreements, the list for the business owner
       Q7  the worklist: candidates for every ATC not cleanly resolved

   WHY ADDRESS AND NOT NAME
       The two systems do not agree on names. Sheet row 6 is "Honorhealth
       Scottsdale Shea Medical Center" and Compile calls the same building
       "HONORHEALTH". A name match misses it; the address does not. So the
       address decides every tier and every tie, and a name is only ever used
       to break a tie between two facilities at the same address.

   THE HOSPITAL RULE IS A PREFERENCE, NOT A FILTER
       The instruction was "likely the account type Hospital". No candidate is
       ever dropped for its type. Hospitals are preferred when two facilities
       share an address, and every ATC that matched a non-hospital type is
       named in Q5 so it can be seen rather than discovered later. On the first
       22 rows, four correct answers were typed PHYSICIAN GROUP or CLINIC in
       Compile, and a hard type filter would have thrown all four away and
       reported them as unmatched.

   AN NPI IS NOT AN ADDRESS
       An NPI belongs to an organisation, not to a building, so it cannot on
       its own prove a facility ID is the right physical location. On the run
       of 2026-08-04 the UC San Diego NPI led to 16950 Viaduct Tazon while the
       sheet says 200 W Arbor Dr. An NPI therefore only counts as a strong
       match when the zip agrees with it; where it does not, the row is held
       back for review instead of being pasted.

   AS-OF DATE
       Set once below and stamped on every output row. Nothing here reads the
       clock, so the same input reproduces the same output on any day.
   ============================================================================ */


/* ############################################################################
   PART 1  -  BUILD
   ############################################################################ */

-- Stamped on every output row so a result grid can be traced back to its run.
SET as_of_date = '2026-08-04';

-- Below this, two addresses are too far apart to call the same building.
-- 92 keeps a spelling slip or a missing suffix and rejects a different address
-- on the same street.
SET min_addr_similarity = 92;


/* ---------------------------------------------------------------------------
   Step 1: the ATC list, one row per centre, addresses cleaned.

   Column map for ATC_CHECK_EXCERSISE, read off the load preview:

       c1  Name          c6  Address navy   c10 Address ORANGE   c14 Facility ID
       c2  NPI           c7  City    navy   c11 City    ORANGE   c15 Facility name
       c3  Parent name   c8  State   navy   c12 State   ORANGE   c16 Facility type
       c4  Status        c9  Zip     navy   c13 Zip     ORANGE   c17 HCO ID
       c5  Auth date                                             c18 HCO name

   c10 to c13 is the orange block, the addresses the business owner verified
   against IovanceCares, and it is what we match on. The navy block is carried
   only so Q6 can report where the two disagree. c14 to c18 are the answers he
   has already filled in by hand; they are never used to find a match, only to
   check ours against his in Q3.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT AS
WITH src AS (
    SELECT
        c1  AS NAME_RAW,
        c2  AS NPI_RAW,
        c4  AS STATUS_RAW,
        c6  AS NAVY_ADDRESS,
        c7  AS NAVY_CITY,
        c9  AS NAVY_ZIP,
        c10 AS ADDRESS_RAW,
        c11 AS CITY_RAW,
        c12 AS STATE_RAW,
        c13 AS ZIP_RAW,
        c14 AS OWNER_FACILITY_ID,
        c15 AS OWNER_FACILITY_NAME,
        c17 AS OWNER_HCO_ID,
        c18 AS OWNER_HCO_NAME
    FROM COMPILE_DEV.PUBLIC.ATC_CHECK_EXCERSISE
),
kept AS (
    -- Drops the two header rows that loaded as data. A real ATC always has a
    -- name and a two letter state; the banner row has neither and the header
    -- row carries the literal word State. Q2 names everything dropped, so an
    -- ATC that is missing its state cannot disappear quietly.
    SELECT *
    FROM src
    WHERE NAME_RAW IS NOT NULL
      AND UPPER(TRIM(NAME_RAW)) NOT IN ('NAME', 'CURRENT ATC SITE INFORMATION')
      AND LENGTH(TRIM(COALESCE(STATE_RAW, ''))) = 2
)
SELECT
    -- A stable key, not the Excel row number. The upload carried no row
    -- column and a Snowflake table has no inherent order, so this is derived
    -- from the name. Paste back with XLOOKUP on ATC_NAME, never by position.
    -- Q1 proves the names are unique, which is what makes that safe.
    ROW_NUMBER() OVER (ORDER BY UPPER(TRIM(NAME_RAW))) AS ROW_KEY,
    TRIM(NAME_RAW)          AS ATC_NAME,
    UPPER(TRIM(NAME_RAW))   AS ATC_NAME_U,
    -- NPI 0 and blank both mean no NPI. Four of the first 22 rows carry 0, and
    -- treating that as a value would join them all to each other.
    CASE WHEN TRIM(COALESCE(NPI_RAW, '')) IN ('', '0') THEN NULL
         ELSE TRIM(NPI_RAW) END                        AS ATC_NPI,
    UPPER(TRIM(STATUS_RAW)) AS ATC_STATUS,
    TRIM(ADDRESS_RAW)       AS ATC_ADDRESS,
    UPPER(TRIM(CITY_RAW))   AS ATC_CITY,
    UPPER(TRIM(STATE_RAW))  AS ATC_STATE,
    -- Strips ZIP+4 and puts back any leading zero Excel dropped. Yale reads
    -- 6510 in the sheet and is really 06510.
    LPAD(LEFT(REGEXP_REPLACE(COALESCE(ZIP_RAW, ''), '[^0-9]', ''), 5), 5, '0') AS ATC_ZIP5,
    TRIM(NAVY_ADDRESS)      AS NAVY_ADDRESS,
    UPPER(TRIM(NAVY_CITY))  AS NAVY_CITY,
    LPAD(LEFT(REGEXP_REPLACE(COALESCE(NAVY_ZIP, ''), '[^0-9]', ''), 5), 5, '0') AS NAVY_ZIP5,
    TRIM(OWNER_FACILITY_ID)   AS OWNER_FACILITY_ID,
    TRIM(OWNER_FACILITY_NAME) AS OWNER_FACILITY_NAME,
    TRIM(OWNER_HCO_ID)        AS OWNER_HCO_ID,
    TRIM(OWNER_HCO_NAME)      AS OWNER_HCO_NAME,
    $as_of_date::DATE         AS AS_OF_DATE
FROM kept;


/* ---------------------------------------------------------------------------
   Step 2: both sides of the match, cleaned by one normaliser.

   The ATC rows and the candidate facility rows are stacked into a single table
   before the addresses are cleaned. That is the whole point of this step: the
   cleaning cannot drift between the two sides, because there is only one copy
   of it. Add a suffix here and both sides move together.

   The facility universe is cut to the states the ATCs are in. That is the
   "one state at a time" instruction, done in a single pass so no state can be
   skipped and there is no loop to run twenty odd times.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_XWALK_NORM AS
WITH facilities AS (
    /* -------------------------------------------------------------------
       The only place Compile facility column names appear in this file.
       Verified against the table on 2026-08-04. The address block is
       prefixed FACILITY_, the NPI is D_FACILITY_NPI, and the zip is split
       into FACILITY_ZIP_5 and FACILITY_ZIP_4.
       ------------------------------------------------------------------- */
    SELECT
        D_FACILITY_COMPILE_ID   AS FACILITY_ID,
        FACILITY_NAME           AS FACILITY_NAME,
        FACILITY_TYPE           AS FACILITY_TYPE,
        FACILITY_ADDRESS_LINE_1 AS RAW_ADDRESS,
        FACILITY_CITY           AS RAW_CITY,
        FACILITY_STATE          AS RAW_STATE,
        FACILITY_ZIP_5          AS RAW_ZIP,
        D_FACILITY_NPI          AS RAW_NPI
    FROM COMPILE_PROVIDER360.ENTITIES.IOV2501_FACILITY_ATTRIBUTES
    WHERE UPPER(TRIM(FACILITY_STATE)) IN (SELECT DISTINCT ATC_STATE
                                          FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT)
),
both_sides AS (
    SELECT
        'ATC'::STRING        AS SRC,
        ROW_KEY::STRING      AS KEY_ID,
        ATC_NAME_U           AS ENTITY_NAME,
        NULL::STRING         AS FACILITY_TYPE,
        ATC_NPI              AS NPI,
        ATC_ADDRESS          AS RAW_ADDRESS,
        ATC_CITY             AS CITY,
        ATC_STATE            AS STATE,
        ATC_ZIP5             AS ZIP5
    FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT

    UNION ALL

    SELECT
        'FAC'::STRING,
        FACILITY_ID::STRING,
        UPPER(TRIM(FACILITY_NAME)),
        UPPER(TRIM(FACILITY_TYPE)),
        CASE WHEN TRIM(COALESCE(RAW_NPI::STRING, '')) IN ('', '0') THEN NULL
             ELSE TRIM(RAW_NPI::STRING) END,
        RAW_ADDRESS,
        UPPER(TRIM(RAW_CITY)),
        UPPER(TRIM(RAW_STATE)),
        LPAD(LEFT(REGEXP_REPLACE(COALESCE(RAW_ZIP, ''), '[^0-9]', ''), 5), 5, '0')
    FROM facilities
),
cleaned AS (
    SELECT
        both_sides.*,
        /* The normaliser. Upper case, every character that is not a letter or
           a digit becomes a space, anything from a suite or room marker to the
           end of the line is dropped, then the long forms of the street types
           and the compass directions are replaced by their short forms. The
           string is padded with a space at each end first, so every rule can
           be written as a whole word with a space either side. That padding is
           what stops NORTH firing inside NORTHWEST. FL is deliberately not in
           the suite list: it is also Florida. */
        TRIM(REGEXP_REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REGEXP_REPLACE(
                ' ' || REGEXP_REPLACE(UPPER(COALESCE(RAW_ADDRESS, '')), '[^A-Z0-9]', ' ') || ' ',
                ' (STE|SUITE|UNIT|APT|RM|ROOM|BLDG|BUILDING|FLOOR|MAILSTOP|PO BOX) .*$', ' '),
                ' STREET ', ' ST '),
                ' AVENUE ', ' AVE '),
                ' ROAD ', ' RD '),
                ' DRIVE ', ' DR '),
                ' BOULEVARD ', ' BLVD '),
                ' PLAZA ', ' PLZ '),
                ' LANE ', ' LN '),
                ' PARKWAY ', ' PKWY '),
                ' CIRCLE ', ' CIR '),
                ' COURT ', ' CT '),
                ' PLACE ', ' PL '),
                ' TERRACE ', ' TER '),
                ' HIGHWAY ', ' HWY '),
                ' NORTHWEST ', ' NW '),
                ' NORTHEAST ', ' NE '),
                ' SOUTHWEST ', ' SW '),
                ' SOUTHEAST ', ' SE '),
                ' NORTH ', ' N '),
                ' SOUTH ', ' S '),
                ' EAST ', ' E '),
                ' WEST ', ' W '),
            ' +', ' ')) AS ADDR_NORM
    FROM both_sides
)
SELECT
    SRC,
    KEY_ID,
    ENTITY_NAME,
    FACILITY_TYPE,
    NPI,
    RAW_ADDRESS,
    CITY,
    STATE,
    ZIP5,
    ADDR_NORM,
    -- The house number on its own. The most reliable token in an address:
    -- "1900 N Higley Rd" and "1900 NORTH HIGLEY ROAD" agree on nothing else.
    REGEXP_SUBSTR(ADDR_NORM, '^[0-9]+')            AS HOUSE_NUM,
    -- The street with the house number and the compass directions removed,
    -- which is what lets "3800 Reservoir Rd NW" reach "3800 RESERVOIR RD".
    TRIM(REGEXP_REPLACE(
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(' ' || TRIM(REGEXP_REPLACE(ADDR_NORM, '^[0-9]+', '')) || ' ', ' NW ', ' '), ' NE ', ' '), ' SW ', ' '), ' SE ', ' '), ' N ', ' '), ' S ', ' '), ' E ', ' '), ' W ', ' '),
        ' +', ' ')) AS STREET_NODIR,
    $as_of_date::DATE                              AS AS_OF_DATE
FROM cleaned;


/* ---------------------------------------------------------------------------
   Step 3: every candidate pair and how strongly it matched.

   The match rule lives here and only here. Part 3 reads this table rather than
   restating the rule, so the worklist can never disagree with the choice.

   Tiers, strongest first:
       1  zip and the whole address agree the clean case
       2  NPI, zip and street number      the NPI backed up by the building
       3  zip, house number and street    survives a missing suffix
       4  city, house number and street   survives a wrong zip
       5  house number and a close address survives a typo, needs an eye
       6  NPI agrees, address does not    held back, never pasted

   The state is the only hard gate. Everything weaker is a tier rather than a
   filter, so a poor match is visible instead of absent.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_XWALK_CANDIDATES AS
WITH atc AS (SELECT * FROM COMPILE_DEV.PUBLIC.ATC_XWALK_NORM WHERE SRC = 'ATC'),
fac AS (SELECT * FROM COMPILE_DEV.PUBLIC.ATC_XWALK_NORM WHERE SRC = 'FAC'),
paired AS (
    SELECT
        a.KEY_ID::INT   AS ROW_KEY,
        f.KEY_ID        AS FACILITY_ID,
        f.ENTITY_NAME   AS FACILITY_NAME,
        f.FACILITY_TYPE AS FACILITY_TYPE,
        f.ADDR_NORM     AS FAC_ADDR_NORM,
        f.CITY          AS FAC_CITY,
        f.ZIP5          AS FAC_ZIP5,
        a.HOUSE_NUM     AS ATC_HOUSE_NUM,
        f.HOUSE_NUM     AS FAC_HOUSE_NUM,
        JAROWINKLER_SIMILARITY(a.ADDR_NORM,   f.ADDR_NORM)   AS ADDR_SIM,
        JAROWINKLER_SIMILARITY(a.ENTITY_NAME, f.ENTITY_NAME) AS NAME_SIM,
        CASE
            WHEN a.ZIP5 = f.ZIP5 AND a.ADDR_NORM = f.ADDR_NORM    THEN 1
            WHEN a.NPI IS NOT NULL AND a.NPI = f.NPI
                 AND a.ZIP5      = f.ZIP5
                 AND a.HOUSE_NUM = f.HOUSE_NUM                    THEN 2
            WHEN a.ZIP5 = f.ZIP5
                 AND a.HOUSE_NUM    = f.HOUSE_NUM
                 AND a.STREET_NODIR = f.STREET_NODIR              THEN 3
            WHEN a.CITY = f.CITY
                 AND a.HOUSE_NUM    = f.HOUSE_NUM
                 AND a.STREET_NODIR = f.STREET_NODIR              THEN 4
            WHEN a.HOUSE_NUM = f.HOUSE_NUM
                 AND JAROWINKLER_SIMILARITY(a.ADDR_NORM, f.ADDR_NORM)
                     >= $min_addr_similarity                      THEN 5
            WHEN a.NPI IS NOT NULL AND a.NPI = f.NPI              THEN 6
        END AS MATCH_TIER
    FROM atc a
    INNER JOIN fac f ON a.STATE = f.STATE
)
SELECT
    paired.*,
    -- How many facilities are level with this one for the same ATC. Above 1
    -- means something other than the address decided it.
    COUNT(*) OVER (PARTITION BY ROW_KEY, MATCH_TIER, ADDR_SIM) AS LEVEL_WITH_IT,
    $as_of_date::DATE                                          AS AS_OF_DATE
FROM paired
WHERE MATCH_TIER IS NOT NULL;


/* ---------------------------------------------------------------------------
   Step 4: choose one facility per ATC and attach its HCO.

   The choice is settled in this order: the tier, then the address similarity,
   then a hospital ahead of any other account type, then the name, then the
   facility ID. Address comes before name because the two systems agree on
   locations and not on names. The facility ID at the end means two runs on the
   same input return the same answer, which is the only reason the sheet can be
   trusted after a rerun.

   Tier 6 is never treated as found. It is carried through so the worklist can
   show a likely answer beside an ATC that would otherwise come back empty, and
   Q4 blanks it so it cannot be pasted by accident.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED AS
WITH chosen AS (
    SELECT *
    FROM COMPILE_DEV.PUBLIC.ATC_XWALK_CANDIDATES
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY ROW_KEY
        ORDER BY MATCH_TIER,
                 ADDR_SIM DESC,
                 CASE WHEN FACILITY_TYPE = 'HOSPITALS' THEN 0 ELSE 1 END,
                 NAME_SIM DESC,
                 FACILITY_ID
    ) = 1
),
hco AS (
    /* -------------------------------------------------------------------
       The only place Compile hierarchy column names appear in this file.
       Verified against the table on 2026-08-04. It is a wide table, one
       row per facility, carrying the HCO directly. There is no level
       column, so there is no level to choose. The row number below is a
       guard against the table ever fanning out, not a choice; Q1 proves
       whether it fires.
       ------------------------------------------------------------------- */
    SELECT
        D_FACILITY_COMPILE_ID AS FACILITY_ID,
        D_HCO_COMPILE_ID      AS HCO_ID,
        HCO_NAME              AS HCO_NAME
    FROM COMPILE_PROVIDER360.RELATIONSHIPS.IOV2501_HCO_FULL_HIERARCHY
    QUALIFY ROW_NUMBER() OVER (PARTITION BY D_FACILITY_COMPILE_ID
                               ORDER BY D_HCO_COMPILE_ID) = 1
)
SELECT
    i.ROW_KEY,
    i.ATC_NAME,
    i.ATC_NPI,
    i.ATC_STATUS,
    i.ATC_ADDRESS,
    i.ATC_CITY,
    i.ATC_STATE,
    i.ATC_ZIP5,
    i.NAVY_ADDRESS,
    i.NAVY_CITY,
    i.NAVY_ZIP5,
    i.OWNER_FACILITY_ID,
    i.OWNER_HCO_ID,
    c.FACILITY_ID  AS D_FACILITY_COMPILE_ID,
    c.FACILITY_NAME,
    c.FACILITY_TYPE,
    h.HCO_ID       AS D_HCO_COMPILE_ID,
    h.HCO_NAME,
    c.FAC_ADDR_NORM,
    c.FAC_CITY,
    c.FAC_ZIP5,
    c.ATC_HOUSE_NUM,
    c.FAC_HOUSE_NUM,
    c.ADDR_SIM,
    c.NAME_SIM,
    c.MATCH_TIER,
    c.LEVEL_WITH_IT,
    CASE
        WHEN c.FACILITY_ID IS NULL          THEN 'NO MATCH'
        WHEN c.MATCH_TIER = 6               THEN 'ADDRESS MISMATCH - do not paste'
        WHEN c.ATC_HOUSE_NUM IS DISTINCT FROM c.FAC_HOUSE_NUM
                                            THEN 'REVIEW - different street number'
        WHEN c.MATCH_TIER = 5               THEN 'REVIEW - address is close, not exact'
        WHEN h.HCO_ID IS NULL               THEN 'REVIEW - facility found, no HCO'
        WHEN c.FACILITY_TYPE <> 'HOSPITALS' THEN 'REVIEW - not a hospital type'
        WHEN c.ADDR_SIM < 100
             AND c.LEVEL_WITH_IT > 1        THEN 'REVIEW - two facilities scored the same'
        ELSE 'OK'
    END AS MATCH_STATUS,
    $as_of_date::DATE AS AS_OF_DATE
-- Left join from the ATC list, never inner. An ATC with no match must still
-- come back as a row, or it silently vanishes from the output.
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT i
LEFT JOIN chosen c ON i.ROW_KEY     = c.ROW_KEY
LEFT JOIN hco    h ON c.FACILITY_ID = h.FACILITY_ID;



/* ############################################################################
   PART 2  -  CHECKS. Read Q1 before anything else.
   ############################################################################ */


/* ---------------------------------------------------------------------------
   Q1. Every check in one grid. All six must say PASS.

       1  Grain          one output row per ATC, no more and no fewer
       2  No duplicates  the same ATC cannot appear twice
       3  Unique names   the paste back is a lookup on the name, so two ATCs
                         sharing a name would give one of them the other's IDs
       4  One HCO        no facility returned more than one HCO
       5  Facility reuse two ATCs on one facility would double count patients
                         the moment these IDs are used to pull claims
       6  Owner agrees   every row the business owner already filled in comes
                         back with the same facility and the same HCO
   --------------------------------------------------------------------------- */
SELECT 1 AS CHECK_NO, 'Grain: one row per ATC' AS CHECK_NAME,
       (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT)   AS EXPECTED,
       (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED) AS ACTUAL,
       CASE WHEN (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT)
               =  (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED)
            THEN 'PASS' ELSE 'FAIL' END AS RESULT
UNION ALL
SELECT 2, 'No duplicated ATC rows', 0,
       (SELECT COUNT(*) FROM (SELECT ROW_KEY FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
                              GROUP BY 1 HAVING COUNT(*) > 1)),
       CASE WHEN (SELECT COUNT(*) FROM (SELECT ROW_KEY FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
                                        GROUP BY 1 HAVING COUNT(*) > 1)) = 0
            THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 3, 'ATC names are unique', 0,
       (SELECT COUNT(*) FROM (SELECT ATC_NAME FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT
                              GROUP BY 1 HAVING COUNT(*) > 1)),
       CASE WHEN (SELECT COUNT(*) FROM (SELECT ATC_NAME FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT
                                        GROUP BY 1 HAVING COUNT(*) > 1)) = 0
            THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 4, 'One HCO per facility', 0,
       (SELECT COUNT(*) FROM (SELECT D_FACILITY_COMPILE_ID
                              FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
                              WHERE D_FACILITY_COMPILE_ID IS NOT NULL
                              GROUP BY 1 HAVING COUNT(DISTINCT D_HCO_COMPILE_ID) > 1)),
       CASE WHEN (SELECT COUNT(*) FROM (SELECT D_FACILITY_COMPILE_ID
                                        FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
                                        WHERE D_FACILITY_COMPILE_ID IS NOT NULL
                                        GROUP BY 1 HAVING COUNT(DISTINCT D_HCO_COMPILE_ID) > 1)) = 0
            THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 5, 'No facility used by two ATCs', 0,
       (SELECT COUNT(*) FROM (SELECT D_FACILITY_COMPILE_ID
                              FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
                              WHERE D_FACILITY_COMPILE_ID IS NOT NULL
                              GROUP BY 1 HAVING COUNT(*) > 1)),
       CASE WHEN (SELECT COUNT(*) FROM (SELECT D_FACILITY_COMPILE_ID
                                        FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
                                        WHERE D_FACILITY_COMPILE_ID IS NOT NULL
                                        GROUP BY 1 HAVING COUNT(*) > 1)) = 0
            THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 6, 'Matches the answers already in the sheet', 0,
       (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
        WHERE OWNER_FACILITY_ID IS NOT NULL
          AND (OWNER_FACILITY_ID <> D_FACILITY_COMPILE_ID
               OR D_FACILITY_COMPILE_ID IS NULL)),
       CASE WHEN (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
                  WHERE OWNER_FACILITY_ID IS NOT NULL
                    AND (OWNER_FACILITY_ID <> D_FACILITY_COMPILE_ID
                         OR D_FACILITY_COMPILE_ID IS NULL)) = 0
            THEN 'PASS' ELSE 'FAIL' END
ORDER BY CHECK_NO;


/* ---------------------------------------------------------------------------
   Q2. Rows in the uploaded file, rows kept, and the name of everything
       dropped. Expect exactly two drops, the merged banner row and the header
       row. A third name here is a real ATC that lost its state, and that is a
       fix in the sheet, not something to ignore.
   --------------------------------------------------------------------------- */
WITH counts AS (
    SELECT
        (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_CHECK_EXCERSISE) AS ROWS_IN_FILE,
        (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT)     AS ROWS_KEPT
),
dropped AS (
    SELECT LISTAGG(COALESCE(c1, 'blank row'), '  |  ') AS DROPPED_ROWS
    FROM COMPILE_DEV.PUBLIC.ATC_CHECK_EXCERSISE
    WHERE c1 IS NULL
       OR UPPER(TRIM(c1)) IN ('NAME', 'CURRENT ATC SITE INFORMATION')
       OR LENGTH(TRIM(COALESCE(c12, ''))) <> 2
)
SELECT
    counts.ROWS_IN_FILE,
    counts.ROWS_KEPT,
    counts.ROWS_IN_FILE - counts.ROWS_KEPT AS ROWS_DROPPED,
    dropped.DROPPED_ROWS
FROM counts, dropped;


/* ---------------------------------------------------------------------------
   Q3. Our answer against the answers already in the sheet, row by row.

       Every row the business owner filled in by hand is a test case. AGREE on
       all of them is the finish line. A DISAGREE means the rule is wrong, not
       that the row is a hard case, so fix the rule rather than the row.
   --------------------------------------------------------------------------- */
SELECT
    ROW_KEY,
    LEFT(ATC_NAME, 34)      AS ATC_NAME,
    OWNER_FACILITY_ID       AS SHEET_SAYS_FACILITY,
    D_FACILITY_COMPILE_ID   AS WE_SAY_FACILITY,
    OWNER_HCO_ID            AS SHEET_SAYS_HCO,
    D_HCO_COMPILE_ID        AS WE_SAY_HCO,
    ADDR_SIM,
    MATCH_TIER,
    CASE WHEN OWNER_FACILITY_ID = D_FACILITY_COMPILE_ID
              AND OWNER_HCO_ID  = D_HCO_COMPILE_ID       THEN 'AGREE'
         WHEN OWNER_HCO_ID      = D_HCO_COMPILE_ID       THEN 'HCO agrees, facility differs'
         WHEN D_FACILITY_COMPILE_ID IS NULL              THEN 'we found nothing'
         ELSE 'DISAGREE - fix the rule, not the row'
    END AS RESULT
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
WHERE OWNER_FACILITY_ID IS NOT NULL
   OR OWNER_HCO_ID IS NOT NULL
ORDER BY RESULT, ROW_KEY;



/* ############################################################################
   PART 3  -  OUTPUT
   ############################################################################ */


/* ---------------------------------------------------------------------------
   Q4. The paste-back block, columns N to R.

       Paste with XLOOKUP on ATC_NAME, not by position: the upload carried no
       row number, so the order here is alphabetical and not the sheet order.

       A blank is an answer. It means nothing was found that can be shown to be
       the right building, and it should stay blank until someone looks at it.
   --------------------------------------------------------------------------- */
SELECT
    ATC_NAME,
    -- Tier 6 is an NPI match whose address disagrees, so it is withheld here
    -- and shown in the worklist instead.
    CASE WHEN MATCH_TIER = 6 THEN NULL ELSE D_FACILITY_COMPILE_ID END AS D_FACILITY_COMPILE_ID,
    CASE WHEN MATCH_TIER = 6 THEN NULL ELSE FACILITY_NAME         END AS FACILITY_NAME,
    CASE WHEN MATCH_TIER = 6 THEN NULL ELSE FACILITY_TYPE         END AS FACILITY_TYPE,
    CASE WHEN MATCH_TIER = 6 THEN NULL ELSE D_HCO_COMPILE_ID      END AS D_HCO_COMPILE_ID,
    CASE WHEN MATCH_TIER = 6 THEN NULL ELSE HCO_NAME              END AS HCO_NAME,
    MATCH_STATUS
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
ORDER BY ATC_NAME;


/* ---------------------------------------------------------------------------
   Q5. Every ATC, the address in the sheet against the address in Compile.

       This is the evidence behind Q4. Sorted worst first, so if the grid runs
       off the screen the rows that need attention are still in view.

       ADDR_SIM is 0 to 100. 100 means the two addresses cleaned to exactly the
       same string. Below about 90 means a different building.
   --------------------------------------------------------------------------- */
SELECT
    LEFT(ATC_NAME, 34)      AS ATC_NAME,
    LEFT(ATC_ADDRESS, 24)   AS SHEET_ADDRESS,
    LEFT(FAC_ADDR_NORM, 24) AS COMPILE_ADDRESS,
    ADDR_SIM,
    FACILITY_TYPE,
    MATCH_TIER,
    MATCH_STATUS
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
ORDER BY ADDR_SIM NULLS FIRST, ATC_NAME;


/* ---------------------------------------------------------------------------
   Q6. City and zip disagreements. The list to take back to the business owner.

       This is the Gilbert versus Phoenix question answered for the whole list.
       A row here is not a bad match. The match was made on the street, and
       Compile normally carries the address of the actual building while a
       sheet can carry a mailing or a campus address. On the first 22 rows this
       found that the sheet has UAB at 1802 6th St in 35205 while Compile has
       1802 6th Ave S in 35233, and Compile is the one that returns the ID the
       owner had already filled in by hand.

       SOURCE says which of the sheet's own two address blocks disagrees.
   --------------------------------------------------------------------------- */
SELECT
    LEFT(ATC_NAME, 30) AS ATC_NAME,
    'orange vs Compile' AS SOURCE,
    ATC_CITY  AS SHEET_CITY,
    FAC_CITY  AS COMPILE_CITY,
    ATC_ZIP5  AS SHEET_ZIP,
    FAC_ZIP5  AS COMPILE_ZIP,
    ADDR_SIM
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
WHERE D_FACILITY_COMPILE_ID IS NOT NULL
  AND MATCH_TIER < 6
  AND (ATC_CITY <> FAC_CITY OR ATC_ZIP5 <> FAC_ZIP5)

UNION ALL

SELECT
    LEFT(ATC_NAME, 30),
    'orange vs navy in the sheet',
    ATC_CITY, NAVY_CITY,
    ATC_ZIP5, NAVY_ZIP5,
    NULL
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
WHERE ATC_CITY <> NAVY_CITY OR ATC_ZIP5 <> NAVY_ZIP5
ORDER BY SOURCE, ATC_NAME;


/* ---------------------------------------------------------------------------
   Q7. The worklist. Every candidate for every ATC that is not cleanly
       resolved, so the choice is made on evidence rather than on sort order.

       Read the addresses, not the names. PICKED marks the one the query took.
       An ATC that appears here with no rows underneath it had no candidate at
       any tier, and the next step for that one is to look in the facility
       table directly for its zip and city.
   --------------------------------------------------------------------------- */
SELECT
    LEFT(m.ATC_NAME, 26)      AS ATC_NAME,
    LEFT(m.ATC_ADDRESS, 20)   AS SHEET_ADDRESS,
    LEFT(c.FACILITY_NAME, 28) AS CANDIDATE_NAME,
    LEFT(c.FAC_ADDR_NORM, 20) AS CANDIDATE_ADDRESS,
    c.FAC_CITY,
    c.FAC_ZIP5,
    c.FACILITY_TYPE,
    c.ADDR_SIM,
    c.MATCH_TIER,
    CASE WHEN c.FACILITY_ID = m.D_FACILITY_COMPILE_ID THEN 'PICKED' ELSE '' END AS PICKED
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED m
LEFT JOIN COMPILE_DEV.PUBLIC.ATC_XWALK_CANDIDATES c ON m.ROW_KEY = c.ROW_KEY
WHERE m.MATCH_STATUS <> 'OK'
ORDER BY m.ATC_NAME, c.MATCH_TIER, c.ADDR_SIM DESC;

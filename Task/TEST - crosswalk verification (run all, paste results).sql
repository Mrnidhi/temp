/* ============================================================================
   TEST - ATC to Compile crosswalk, build and verify in one file

   Press Run All. There is nothing to do before it and nothing to do after it.

   It rebuilds all four tables from the ATC list, then runs nine checks over
   what it just built, so no grid below can ever describe a stale table. Safe to
   repeat as often as you like; every statement is CREATE OR REPLACE or SELECT.

   THE ONLY THING YOU MAINTAIN
       The ATC list itself, in BUILD STEP 1. The seed carries sheet rows 3 to 24.
       Paste rows 25 onward into the marked spot and Run All again.

   THIS FILE IS A COPY
       Build steps 1 to 4 are byte-identical to the main crosswalk file. If you
       edit one, re-copy into the other, or the two will quietly disagree.

   WHAT TO SEND BACK
       One screenshot per numbered T block, in order. Each is kept narrow enough
       to read in a photo, and where a grid scrolls, the rows that matter are
       sorted to the top on purpose.

   WHAT EACH ONE SETTLES
       T0  the four tables, their row counts, and when they were just rebuilt
       T1  every row, address in the sheet against address in Compile   <- the important one
       T2  city and zip disagreements
       T3  how the rows distribute across the tiers
       T4  HCO coverage, and an independent proof the HCO join is right
       T5  the review worklist, every candidate for every unconfirmed row
       T6  why UF Health found nothing
       T7  the non-hospital matches, in full
       T8  rows where the NPI and the address disagree with each other
   ============================================================================ */


/* ############################################################################
   BUILD  -  Steps 1 to 4. Identical to PART A of the main file.
   ############################################################################ */


-- Stamped on every output row so a result grid can always be traced back to the
-- run that produced it. Change it when the source sheet changes, not otherwise.
SET as_of_date = '2026-08-04';

-- Two ATCs in one building is possible but rare, so a facility claimed by more
-- than this many ATCs stops the run rather than being accepted.
SET max_atcs_per_facility = 1;

-- Below this, a name similarity is only ever a review suggestion, never a match.
SET min_name_similarity = 90;

-- Below this, a fuzzy address is not a match either. 92 keeps a suffix or a
-- spelling slip and rejects a different building on the same street.
SET min_addr_similarity = 92;


/* ---------------------------------------------------------------------------
   Step 1: the ATC list, one row per ATC, addresses cleaned.

   SHEET_ROW is the Excel row number and it is what makes the paste-back safe.
   Every output in Part B is ordered by it, so columns N to R land next to the
   right hospital even where a match is missing.

   Addresses come from the orange "Website Information" block, columns J to M,
   not the navy block, because those are the ones Kolin verified against
   IovanceCares. Where the two blocks disagree, B4 says so.

   OPTION A is the one to use once the sheet is uploaded, and the only version
   that carries all 93 rows without typing. OPTION B is the working seed: the 22
   rows readable off the screenshots. Use one, not both.
   --------------------------------------------------------------------------- */

CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT AS
WITH raw AS (

    /* ---- OPTION A: sheet uploaded to Snowflake. Preferred. -----------------
       Upload the Active ATC List tab as COMPILE_DEV.PUBLIC.ATC_ADDRESS_INPUT_2026
       with the header row intact, then swap the comment markers so this block is
       live and OPTION B is commented out. Column contract:
           "Sheet Row", "Name", "NPI", "Status", "Address", "City", "State", "Zip"
       where Address to Zip are the ORANGE columns J to M. Add "Sheet Row" as a
       helper column in Excel first (=ROW()); deriving it from a sort order here
       would silently reorder the paste-back.

    SELECT
        "Sheet Row"::INT AS SHEET_ROW,
        "Name"           AS ATC_NAME,
        "NPI"            AS ATC_NPI,
        "Status"         AS ATC_STATUS,
        "Address"        AS RAW_ADDRESS,
        "City"           AS RAW_CITY,
        "State"          AS RAW_STATE,
        "Zip"            AS RAW_ZIP
    FROM COMPILE_DEV.PUBLIC.ATC_ADDRESS_INPUT_2026
    ------------------------------------------------------------------------ */

    /* ---- OPTION B: inline seed. Rows 3 to 24, read off the screenshots. Add
       rows 25 onward straight from the sheet, same column order, one line each.
       SHEET_ROW must stay equal to the real Excel row number. --------------- */
    SELECT * FROM VALUES
        ( 3, 'O Neal Comprehensive Cancer Center At UAB',   '0',          'Authorized', '1802 6th St.',         'Birmingham',    'AL', '35205'),
        ( 4, 'Banner Gateway Medical Center',               '1699884858', 'Authorized', '1900 N Higley Rd',     'Gilbert',       'AZ', '85234'),
        ( 5, 'Mayo Clinic Hospital-Phoenix Arizona',        '1154392231', 'Authorized', '5777 E Mayo Blvd',     'Phoenix',       'AZ', '85054'),
        ( 6, 'Honorhealth Scottsdale Shea Medical Center',  '1386608859', 'Authorized', '9003 E Shea Blvd',     'Scottsdale',    'AZ', '85260'),
        ( 7, 'HOAG Memorial Hospital Presbyterian',         '1518951300', 'Authorized', '1 Hoag Dr',            'Newport Beach', 'CA', '92663'),
        ( 8, 'Kaiser Permanente Vallejo Medical Center',    '1336222397', 'Authorized', '975 Sereno Dr',        'Vallejo',       'CA', '94589'),
        ( 9, 'UCSF Medical Center',                         '1447396684', 'Authorized', '505 Parnassus Ave',    'San Francisco', 'CA', '94143'),
        (10, 'Cedars-Sinai Medical Center',                 '1083785489', 'Authorized', '8700 Beverly Blvd',    'Los Angeles',   'CA', '90048'),
        (11, 'USC Norris Comprehensive Cancer Center',      '1013514199', 'Authorized', '1500 San Pablo St',    'Los Angeles',   'CA', '90033'),
        (12, 'UC San Diego Medical Center',                 '1659864247', 'Authorized', '200 W Arbor Dr',       'San Diego',     'CA', '92103'),
        (13, 'City Of Hope Duarte Cancer Center',           '1851416374', 'Authorized', '1500 E Duarte Rd',     'Duarte',        'CA', '91010'),
        (14, 'UCLA - Santa Monica',                         '1427055839', 'ON HOLD',    '1250 16th St',         'Santa Monica',  'CA', '90404'),
        (15, 'Ronald Reagan UCLA Medical Center',           '1902803315', 'Authorized', '757 Westwood Plz',     'Los Angeles',   'CA', '90095'),
        (16, 'Stanford Hospital',                           '1871543215', 'Authorized', '300 Pasteur Dr',       'Palo Alto',     'CA', '94304'),
        (17, 'The Colorado Blood Cancer Institute',         '0',          'Authorized', '1721 E 19th Ave',      'Denver',        'CO', '80218'),
        (18, 'UC Health University Of Colorado Hospital',   '1982944054', 'Authorized', '12605 E 16th Ave',     'Aurora',        'CO', '80045'),
        (19, 'Yale-New Haven Hospital',                     '1477178127', 'Authorized', '20 York St',           'New Haven',     'CT', '6510'),
        (20, 'Medstar Georgetown University Hospital',      '1427145176', 'Authorized', '3800 Reservoir Rd NW', 'Washington',    'DC', '20007'),
        (21, 'Adventhealth Cancer Institute',               '0',          'Authorized', '2501 N Orange Ave',    'Orlando',       'FL', '32804'),
        (22, 'University Of Miami-Sylvester Comprehensive', '1679660617', 'Authorized', '1475 NW 12th Ave',     'Miami',         'FL', '33136'),
        (23, 'Mayo Clinic Jacksonville FL',                 '1174143986', 'Authorized', '4500 San Pablo Rd S',  'Jacksonville',  'FL', '32224'),
        (24, 'UF Health Cancer Center',                     '0',          'ON HOLD',    '2033 Mowry Rd',        'Gainesville',   'FL', '32610')
        -- <<< PASTE ROWS 25 ONWARD HERE >>>
    AS t(SHEET_ROW, ATC_NAME, ATC_NPI, ATC_STATUS, RAW_ADDRESS, RAW_CITY, RAW_STATE, RAW_ZIP)
)
SELECT
    SHEET_ROW::INT                AS SHEET_ROW,
    TRIM(ATC_NAME)                AS ATC_NAME,
    UPPER(TRIM(ATC_NAME))         AS ATC_NAME_U,
    -- NPI 0 and blank both mean "no NPI". Kept as a match key only where real,
    -- because 0 appears on four of the first 22 rows and would join them to
    -- each other. Same rule as the site of care pipeline.
    CASE WHEN TRIM(COALESCE(ATC_NPI, '')) IN ('', '0', 'NPI') THEN NULL
         ELSE TRIM(ATC_NPI) END   AS ATC_NPI,
    UPPER(TRIM(ATC_STATUS))       AS ATC_STATUS,
    TRIM(RAW_ADDRESS)             AS RAW_ADDRESS,
    UPPER(TRIM(RAW_CITY))         AS ATC_CITY,
    UPPER(TRIM(RAW_STATE))        AS ATC_STATE,
    -- Strips ZIP+4 and restores any leading zero Excel dropped. Row 19 is the
    -- live case: 6510 becomes 06510.
    LPAD(LEFT(REGEXP_REPLACE(COALESCE(RAW_ZIP, ''), '[^0-9]', ''), 5), 5, '0') AS ATC_ZIP5,
    $as_of_date::DATE             AS AS_OF_DATE
FROM raw;


/* ---------------------------------------------------------------------------
   Step 2: both sides of the match, run through ONE normaliser.

   Stacking the ATC rows and the facility rows into a single table before
   normalising is the whole point of this step: the cleaning cannot drift
   between the two sides, because there is only one copy of it. If a suffix or a
   directional needs adding, it is added here, once, and both sides move
   together.

   The facility universe is cut to the states the ATCs are in. That is the
   "state at a time" instruction, done in a single pass.
   --------------------------------------------------------------------------- */

CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_XWALK_NORM AS
WITH fac_raw AS (
    /* ####################################################################
       THE ONLY PLACE COMPILE FACILITY COLUMN NAMES APPEAR IN THIS FILE.
       Names VERIFIED against PART 0A on 2026-08-04: the table returns 18
       columns and the address block is prefixed FACILITY_, not bare.
       Notes from that column list:
         - FACILITY_ZIP_5 is already five digits, with ZIP_4 held separately,
           so the LPAD downstream is a no-op on this side and only does work
           on the ATC side where Excel ate Yale's leading zero.
         - FACILITY_ADDRESS_LINE_2 exists, so suites and floors are unlikely
           to be sitting in line 1. Line 1 alone is the right match key.
         - ACTIVE_FLAG and FACILITY_TYPE_LEVEL_1/2/3 also exist and are NOT
           used. Kolin asked for a match on address with the account type
           likely Hospital, and nothing else. Left here as a note only.
       #################################################################### */
    SELECT
        D_FACILITY_COMPILE_ID          AS FACILITY_ID,
        FACILITY_NAME                  AS FACILITY_NAME,
        FACILITY_TYPE                  AS FACILITY_TYPE,
        FACILITY_ADDRESS_LINE_1        AS RAW_ADDRESS,
        FACILITY_CITY                  AS RAW_CITY,
        FACILITY_STATE                 AS RAW_STATE,
        FACILITY_ZIP_5                 AS RAW_ZIP,
        D_FACILITY_NPI                 AS FACILITY_NPI
    FROM COMPILE_PROVIDER360.ENTITIES.IOV2501_FACILITY_ATTRIBUTES
    WHERE UPPER(TRIM(FACILITY_STATE)) IN (SELECT DISTINCT ATC_STATE
                                          FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT)
),
both_sides AS (
    SELECT
        'ATC'::STRING          AS SRC,
        SHEET_ROW::STRING      AS KEY_ID,
        ATC_NAME_U             AS ENTITY_NAME,
        NULL::STRING           AS FACILITY_TYPE,
        ATC_NPI                AS NPI,
        RAW_ADDRESS            AS RAW_ADDRESS,
        ATC_CITY               AS CITY,
        ATC_STATE              AS STATE,
        ATC_ZIP5               AS ZIP5
    FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT

    UNION ALL

    SELECT
        'FAC'::STRING,
        FACILITY_ID::STRING,
        UPPER(TRIM(FACILITY_NAME)),
        UPPER(TRIM(FACILITY_TYPE)),
        CASE WHEN TRIM(COALESCE(FACILITY_NPI::STRING, '')) IN ('', '0') THEN NULL
             ELSE TRIM(FACILITY_NPI::STRING) END,
        RAW_ADDRESS,
        UPPER(TRIM(RAW_CITY)),
        UPPER(TRIM(RAW_STATE)),
        LPAD(LEFT(REGEXP_REPLACE(COALESCE(RAW_ZIP, ''), '[^0-9]', ''), 5), 5, '0')
    FROM fac_raw
),
/* The normaliser runs in stages so the rules stay readable and the parentheses
   stay countable. Each stage carries the working string forward as A. */
n0 AS (
    -- Upper case, anything that is not a letter or a digit becomes a space, and
    -- the whole string is space-padded so every later rule can be written as a
    -- whole word with a space either side. That padding is what stops ' NORTH '
    -- firing inside ' NORTHWEST '.
    SELECT b.*,
           ' ' || REGEXP_REPLACE(UPPER(COALESCE(RAW_ADDRESS, '')), '[^A-Z0-9]', ' ') || ' ' AS A
    FROM both_sides b
),
n1 AS (
    -- Everything from a suite or room marker onward is dropped. Compile carries
    -- them, the sheet mostly does not, and they are never part of the building.
    -- FL is deliberately absent from this list: it is also Florida.
    SELECT n0.* EXCLUDE A,
           REGEXP_REPLACE(A, ' (STE|SUITE|UNIT|APT|RM|ROOM|BLDG|BUILDING|MAILSTOP|MAIL STOP|PO BOX) .*$', ' ') AS A
    FROM n0
),
n2 AS (
    SELECT n1.* EXCLUDE A,
           REPLACE(REPLACE(REPLACE(REPLACE(A,
               ' STREET ',    ' ST '),
               ' AVENUE ',    ' AVE '),
               ' ROAD ',      ' RD '),
               ' DRIVE ',     ' DR ') AS A
    FROM n1
),
n3 AS (
    SELECT n2.* EXCLUDE A,
           REPLACE(REPLACE(REPLACE(REPLACE(A,
               ' BOULEVARD ', ' BLVD '),
               ' PLAZA ',     ' PLZ '),
               ' LANE ',      ' LN '),
               ' PARKWAY ',   ' PKWY ') AS A
    FROM n2
),
n4 AS (
    SELECT n3.* EXCLUDE A,
           REPLACE(REPLACE(REPLACE(REPLACE(A,
               ' CIRCLE ',    ' CIR '),
               ' COURT ',     ' CT '),
               ' PLACE ',     ' PL '),
               ' TERRACE ',   ' TER ') AS A
    FROM n3
),
n5 AS (
    SELECT n4.* EXCLUDE A,
           REPLACE(REPLACE(REPLACE(REPLACE(A,
               ' HIGHWAY ',   ' HWY '),
               ' NORTHWEST ', ' NW '),
               ' NORTHEAST ', ' NE '),
               ' SOUTHWEST ', ' SW ') AS A
    FROM n4
),
n6 AS (
    SELECT n5.* EXCLUDE A,
           REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(A,
               ' SOUTHEAST ', ' SE '),
               ' NORTH ',     ' N '),
               ' SOUTH ',     ' S '),
               ' EAST ',      ' E '),
               ' WEST ',      ' W ') AS A
    FROM n5
),
n7 AS (
    SELECT n6.* EXCLUDE A,
           TRIM(REGEXP_REPLACE(A, ' +', ' ')) AS ADDR_NORM
    FROM n6
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
    -- The house number alone. The single most reliable token in an address:
    -- "1900 N Higley Rd" and "1900 NORTH HIGLEY ROAD" agree on nothing else.
    REGEXP_SUBSTR(ADDR_NORM, '^[0-9]+')                        AS HOUSE_NUM,
    -- The street with the house number stripped.
    TRIM(REGEXP_REPLACE(ADDR_NORM, '^[0-9]+', ''))             AS STREET_CORE,
    -- The street with directionals stripped as well, for the looser tiers. This
    -- is what lets "3800 Reservoir Rd NW" reach "3800 RESERVOIR RD".
    TRIM(REGEXP_REPLACE(
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            ' ' || TRIM(REGEXP_REPLACE(ADDR_NORM, '^[0-9]+', '')) || ' ',
            ' NW ', ' '), ' NE ', ' '), ' SW ', ' '), ' SE ', ' '),
            ' N ',  ' '), ' S ',  ' '), ' E ',  ' '), ' W ',  ' '),
        ' +', ' '))                                            AS STREET_NODIR,
    $as_of_date::DATE                                          AS AS_OF_DATE
FROM n7;


/* ---------------------------------------------------------------------------
   Step 3: every candidate pair, with its tier. The match rule lives HERE and
   only here - Part B reads this table rather than restating the CASE, so the
   runner-up list in B3 can never drift from the pick in Step 4.

   Tiers, strongest first. A lower number is a better match:
       1  NPI + zip agree               the NPI corroborated by a location
       2  zip + full normalised address the clean case
       3  zip + number + street         survives a suffix or directional gap
       4  city + number + street        survives a wrong zip
       5  state + number + close address survives a typo, needs an eye on it
       6  NPI agrees, ADDRESS DOES NOT  review only, never pasted
       7  close name only               suggestion, never trusted

   State is the only hard gate. Everything softer is a tier, not a filter, so a
   weak match is visible rather than absent.
   --------------------------------------------------------------------------- */

CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_XWALK_CANDIDATES AS
WITH atc AS (SELECT * FROM COMPILE_DEV.PUBLIC.ATC_XWALK_NORM WHERE SRC = 'ATC'),
fac AS (SELECT * FROM COMPILE_DEV.PUBLIC.ATC_XWALK_NORM WHERE SRC = 'FAC'),
paired AS (
    SELECT
        a.KEY_ID::INT   AS SHEET_ROW,
        a.ENTITY_NAME   AS ATC_NAME_U,
        a.ADDR_NORM     AS ATC_ADDR_NORM,
        a.CITY          AS ATC_CITY,
        a.ZIP5          AS ATC_ZIP5,
        f.KEY_ID        AS FACILITY_ID,
        f.ENTITY_NAME   AS FACILITY_NAME,
        f.FACILITY_TYPE AS FACILITY_TYPE,
        f.ADDR_NORM     AS FAC_ADDR_NORM,
        f.CITY          AS FAC_CITY,
        f.ZIP5          AS FAC_ZIP5,
        JAROWINKLER_SIMILARITY(a.ENTITY_NAME, f.ENTITY_NAME) AS NAME_SIM,
        JAROWINKLER_SIMILARITY(a.ADDR_NORM,   f.ADDR_NORM)   AS ADDR_SIM,
        CASE
            -- An NPI is registered to an ORGANISATION, not to a building, so on
            -- its own it cannot prove the ID belongs to this physical location.
            -- It is only tier 1 when the zip corroborates it. Run of 2026-08-04
            -- is why: UC San Diego matched on NPI alone at tier 1 and landed on
            -- 16950 VIADUCT TAZON against a sheet address of 200 W ARBOR DR,
            -- address similarity 47. That is the Gilbert-versus-Phoenix failure
            -- the exercise exists to prevent.
            WHEN a.NPI IS NOT NULL AND a.NPI = f.NPI
                 AND a.ZIP5 = f.ZIP5                                  THEN 1
            WHEN a.ZIP5 = f.ZIP5 AND a.ADDR_NORM = f.ADDR_NORM        THEN 2
            WHEN a.ZIP5 = f.ZIP5
                 AND a.HOUSE_NUM    = f.HOUSE_NUM
                 AND a.STREET_NODIR = f.STREET_NODIR                  THEN 3
            WHEN a.CITY = f.CITY
                 AND a.HOUSE_NUM    = f.HOUSE_NUM
                 AND a.STREET_NODIR = f.STREET_NODIR                  THEN 4
            WHEN a.HOUSE_NUM = f.HOUSE_NUM
                 AND JAROWINKLER_SIMILARITY(a.ADDR_NORM, f.ADDR_NORM)
                     >= $min_addr_similarity                          THEN 5
            -- NPI agrees but the address does NOT. Kept so the row is visible
            -- and never silently dropped, but it is a review, not an answer.
            WHEN a.NPI IS NOT NULL AND a.NPI = f.NPI                  THEN 6
            WHEN JAROWINKLER_SIMILARITY(a.ENTITY_NAME, f.ENTITY_NAME)
                     >= $min_name_similarity                          THEN 7
        END AS MATCH_TIER
    FROM atc a
    INNER JOIN fac f ON a.STATE = f.STATE
)
SELECT
    p.*,
    -- How many other facilities tie with this one at the same tier for the same
    -- ATC. Anything above 1 means the sort order decided it, not the data.
    COUNT(*) OVER (PARTITION BY SHEET_ROW, MATCH_TIER) AS TIED_AT_TIER,
    $as_of_date::DATE                                  AS AS_OF_DATE
FROM paired p
WHERE MATCH_TIER IS NOT NULL;


/* ---------------------------------------------------------------------------
   Step 4: pick one candidate per ATC and attach the HCO. One row per ATC always.

   The pick is fully deterministic: tier, then hospitals ahead of other types,
   then name similarity, then address similarity, then the facility ID as the
   final tiebreak. Two runs on the same inputs return the same IDs, which is the
   only reason the sheet can be trusted after a rerun.

   Tiers 6 and 7 are never treated as found. They are carried through so B2 can
   show a likely answer beside an ATC that would otherwise come back empty, and
   B1 blanks the ID so neither can be pasted by accident.
   --------------------------------------------------------------------------- */

CREATE OR REPLACE TRANSIENT TABLE COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED AS
WITH picked AS (
    SELECT *
    FROM COMPILE_DEV.PUBLIC.ATC_XWALK_CANDIDATES
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY SHEET_ROW
        ORDER BY MATCH_TIER,
                 -- ADDRESS BEFORE NAME. The whole point of the exercise is that
                 -- names do not agree across the two systems and locations do.
                 -- This was the wrong way round on the 2026-08-04 run, which is
                 -- how a candidate scoring 86 on name and 47 on address beat
                 -- better-located ones.
                 ADDR_SIM DESC,
                 -- A preference, not a filter. C4 reports what it cost.
                 CASE WHEN FACILITY_TYPE = 'HOSPITALS' THEN 0 ELSE 1 END,
                 NAME_SIM DESC,
                 FACILITY_ID
    ) = 1
),
hco_raw AS (
    /* ####################################################################
       THE ONLY PLACE COMPILE HIERARCHY COLUMN NAMES APPEAR IN THIS FILE.
       Names VERIFIED against PART 0B on 2026-08-04. The table is WIDE, not
       long: 29 columns, one row per facility, carrying D_HCO_COMPILE_ID and
       HCO_NAME directly plus a twelve-level parent chain in
       D_LEVEL_1_COMPILE_ID / LEVEL_1_NAME through LEVEL_12.

       There is NO level column, so there is nothing to pick a level from -
       the HCO is simply on the row. The dedup below is a guard, not a
       choice: if the table really is one row per facility it changes
       nothing, and C3B proves whether that holds. Ordered by HCO_ID so the
       guard is deterministic if it ever does fire.

       LEVEL_1_NAME through LEVEL_12_NAME are the parent chain, which is
       where sheet column C, "ATC HCO Parent Name (McKesson Claims)", would
       be found. Not pulled through: the sheet asks for five columns and
       already has the parent. Worth revisiting as a cross-check.
       #################################################################### */
    SELECT
        D_FACILITY_COMPILE_ID AS FACILITY_ID,
        D_HCO_COMPILE_ID      AS HCO_ID,
        HCO_NAME              AS HCO_NAME
    FROM COMPILE_PROVIDER360.RELATIONSHIPS.IOV2501_HCO_FULL_HIERARCHY
),
hco AS (
    SELECT *
    FROM hco_raw
    QUALIFY ROW_NUMBER() OVER (PARTITION BY FACILITY_ID ORDER BY HCO_ID) = 1
)
SELECT
    i.SHEET_ROW,
    i.ATC_NAME,
    i.ATC_NPI,
    i.ATC_STATUS,
    i.RAW_ADDRESS      AS ATC_ADDRESS,
    i.ATC_CITY,
    i.ATC_STATE,
    i.ATC_ZIP5,
    p.FACILITY_ID      AS D_FACILITY_COMPILE_ID,
    p.FACILITY_NAME,
    p.FACILITY_TYPE,
    h.HCO_ID           AS D_HCO_COMPILE_ID,
    h.HCO_NAME,
    p.MATCH_TIER,
    p.NAME_SIM,
    p.ADDR_SIM,
    p.TIED_AT_TIER,
    p.FAC_CITY,
    p.FAC_ZIP5,
    p.FAC_ADDR_NORM,
    CASE
        WHEN p.FACILITY_ID IS NULL          THEN 'NO MATCH'
        WHEN p.MATCH_TIER = 7               THEN 'NAME SUGGESTION ONLY - DO NOT PASTE'
        WHEN p.MATCH_TIER = 6               THEN 'ADDRESS MISMATCH - NPI agrees, location does not'
        WHEN p.MATCH_TIER = 5               THEN 'REVIEW - fuzzy address'
        WHEN h.HCO_ID IS NULL               THEN 'REVIEW - facility found, no HCO'
        WHEN p.FACILITY_TYPE <> 'HOSPITALS' THEN 'REVIEW - non-hospital type'
        WHEN p.TIED_AT_TIER > 1             THEN 'REVIEW - tie broken by sort order'
        ELSE 'OK'
    END AS MATCH_STATUS,
    $as_of_date::DATE AS AS_OF_DATE
-- LEFT JOIN from the input, never INNER. An ATC with no match must still come
-- back as a row, or the paste-back shifts up and every ID below the gap lands
-- on the wrong hospital - the one failure here that looks perfectly fine in
-- Excel.
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT i
LEFT JOIN picked p ON i.SHEET_ROW    = p.SHEET_ROW
LEFT JOIN hco    h ON p.FACILITY_ID  = h.FACILITY_ID;


/* ############################################################################
   CHECKS  -  everything below only reads what was just built.
   ############################################################################ */


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

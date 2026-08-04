/* ============================================================================
   ATC to McKesson Compile Crosswalk - facility ID, facility name, HCO ID, HCO name
   MASTER FILE: fills columns N to R of "ATC Check_Excersise" (Active ATC List).

   HOW TO RUN
       Column names are now VERIFIED against both source tables, read off
       PART 0A and 0B on 2026-08-04, so PART 0 is a re-check rather than a gate.
       Run statements one at a time, PART 0 first, then PART A top to bottom,
       then PART C, then PART B. Do not paste PART B output into the sheet
       until every check in PART C says PASS.

       Part A builds four transient tables, Part B returns the paste-back
       blocks, Part C is the QA. If either source table ever changes shape, the
       column names live in exactly two blocks, both marked with a #### banner,
       one in Step 2 and one in Step 4. Every other line reads the aliases.

   WHAT THIS DOES, AND ONLY THIS
       Kolin's instruction, verbatim in scope: get facility ID and name from
       IOV2501_FACILITY_ATTRIBUTES matching on address, likely account type
       Hospital, then use the facility ID to get HCO ID and name from
       IOV2501_HCO_FULL_HIERARCHY. Nothing beyond that is scored, filtered or
       ranked here. ACTIVE_FLAG and the facility type levels exist in the
       source and are deliberately unused.

   Business question:
       For each authorized treatment center, what is its McKesson Compile
       facility ID and HCO ID, matched on address rather than name, so claims
       can be pulled for the ATC network by ID for the payer mix work.

   SOURCE TABLES (read only)
       COMPILE_PROVIDER360.ENTITIES.IOV2501_FACILITY_ATTRIBUTES     facility, address, type
       COMPILE_PROVIDER360.RELATIONSHIPS.IOV2501_HCO_FULL_HIERARCHY facility to HCO
       COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS            second, independent HCO path

   BASE TABLES (built in Part A, all in COMPILE_DEV.PUBLIC)
       ATC_XWALK_INPUT       one row per ATC, addresses cleaned, sheet row kept
       ATC_XWALK_NORM        ATC rows and candidate facility rows, one normaliser
       ATC_XWALK_CANDIDATES  every ATC-to-facility pair that matched at any tier
       ATC_XWALK_MATCHED     one row per ATC, best pick, tier, HCO attached

   SHEET ALIGNMENT
       B1  columns N to R          the paste-back block, in sheet row order
       B2  needs review            every ATC that did not match cleanly
       B3  runner-up candidates    where the pick was close, so you can overrule it
       B4  address disagreements   Compile city or zip differs from the sheet
       B5  match tier summary      what the run actually achieved

   WHY ADDRESS AND NOT NAME
       Kolin asked for IDs rather than names because the names do not agree
       across systems. Row 6 of the sheet is "Honorhealth Scottsdale Shea Medical
       Center" and the Compile facility name he already filled in against it is
       "HONORHEALTH". A name match would have missed it; the address matched.

   ONE PASS, NOT ONE STATE AT A TIME
       The instruction was to pull all accounts in a state and match, state by
       state. Step 2 does the same thing in one pass by restricting the facility
       universe to the states that actually appear in the ATC list, so there is
       no loop to run twenty-odd times and no chance of a state being skipped.

   THE HOSPITAL FILTER IS A PREFERENCE, NOT A FILTER
       The instruction was "likely the account type Hospital". This file never
       drops a non-hospital candidate. Hospitals are preferred in the ranking and
       anything that matched on a non-hospital type is listed by name in C4. If a
       real ATC is typed as a clinic or a cancer center in Compile, a hard filter
       would have returned no match and the run would have looked like clean work
       with a hole in it.

   KNOWN INPUT ISSUES, found reading the sheet, both handled in Step 1
       Row 19  Yale-New Haven zip reads 6510. Excel ate the leading zero; the
               real zip is 06510. Every zip is re-padded to five digits, so this
               would have failed a zip match and now will not.
       Row 16  Stanford Hospital. Column G says Stanford, column K says Palo
               Alto. Same building, two city names. This is the Gilbert versus
               Phoenix problem again, so the match never requires the city to
               agree at the top tiers, and B4 lists every disagreement it finds.

   AS-OF DATE
       Set once below and stamped on every output row. Nothing in this file reads
       the clock, so a rerun next month reproduces this run exactly.
   ============================================================================ */


/* ############################################################################
   PART 0  -  PREFLIGHT. Run this alone and read it before anything else.
   ############################################################################ */


/* ---------------------------------------------------------------------------
   0A. Columns of the facility table. Everything in Step 2 depends on these
       names being right. Read the list, then fix Step 2 if it disagrees.
   --------------------------------------------------------------------------- */
SELECT COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
FROM COMPILE_PROVIDER360.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ENTITIES'
  AND TABLE_NAME   = 'IOV2501_FACILITY_ATTRIBUTES'
ORDER BY ORDINAL_POSITION;


/* ---------------------------------------------------------------------------
   0B. Columns of the hierarchy table. Same reason, for Step 4.
   --------------------------------------------------------------------------- */
SELECT COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
FROM COMPILE_PROVIDER360.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'RELATIONSHIPS'
  AND TABLE_NAME   = 'IOV2501_HCO_FULL_HIERARCHY'
ORDER BY ORDINAL_POSITION;


/* ---------------------------------------------------------------------------
   0C. Every account type in the facility table, with a count. Before preferring
       HOSPITALS over everything else we should see what the other values even
       are. If cancer centers carry a type of their own, that value belongs in
       the ranking rule in Step 3.
   --------------------------------------------------------------------------- */
SELECT
    FACILITY_TYPE,
    COUNT(*) AS FACILITIES
FROM COMPILE_PROVIDER360.ENTITIES.IOV2501_FACILITY_ATTRIBUTES
GROUP BY 1
ORDER BY 2 DESC;


/* ---------------------------------------------------------------------------
   0D. Sample the hierarchy so the facility ID format is visible before the
       join is written against it. Five rows is enough.

       This is here because a lookup by a single pasted ID returned nothing on
       the first attempt, and an empty grid does not say whether the ID was
       wrong, the format differs, or the facility genuinely has no HCO row.
       Reading five real rows answers all three at once.

       What to check: does D_FACILITY_COMPILE_ID here look like the LOC-...
       values in sheet column N, and is D_HCO_COMPILE_ID populated.
   --------------------------------------------------------------------------- */
SELECT
    D_FACILITY_COMPILE_ID,
    FACILITY_NAME,
    D_HCO_COMPILE_ID,
    HCO_NAME,
    LEVEL_1_NAME,
    LEVEL_2_NAME
FROM COMPILE_PROVIDER360.RELATIONSHIPS.IOV2501_HCO_FULL_HIERARCHY
LIMIT 5;


/* ---------------------------------------------------------------------------
   0E. One row per facility, or several? The Step 4 join assumes one. If this
       returns 0, the join cannot fan out and the dedup guard never fires.
   --------------------------------------------------------------------------- */
SELECT COUNT(*) AS FACILITIES_WITH_MORE_THAN_ONE_ROW
FROM (
    SELECT D_FACILITY_COMPILE_ID
    FROM COMPILE_PROVIDER360.RELATIONSHIPS.IOV2501_HCO_FULL_HIERARCHY
    GROUP BY 1
    HAVING COUNT(*) > 1
);



/* ############################################################################
   PART A  -  BUILD THE FOUR BASE TABLES
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
   PART B  -  OUTPUTS. Nothing here writes. Run PART C first, paste after.
   ############################################################################ */


/* ---------------------------------------------------------------------------
   B1. The paste-back block, columns N to R.

   Ordered by SHEET_ROW so it lines up with the workbook exactly. Copy the five
   middle columns only. A blank means no usable match was found, and a blank is
   the correct answer: do not fill one in by hand without noting in the sheet
   that it was done by hand.
   --------------------------------------------------------------------------- */
SELECT
    SHEET_ROW,
    ATC_NAME,
    -- Tiers 6 and 7 are not location-confirmed: 6 is an NPI match whose address
    -- disagrees, 7 is a name guess. Both are withheld from the paste block and
    -- shown in B2 instead. Everything else that matched is here.
    CASE WHEN MATCH_TIER >= 6 THEN NULL ELSE D_FACILITY_COMPILE_ID END AS D_FACILITY_COMPILE_ID, -- N
    CASE WHEN MATCH_TIER >= 6 THEN NULL ELSE FACILITY_NAME         END AS FACILITY_NAME,         -- O
    CASE WHEN MATCH_TIER >= 6 THEN NULL ELSE FACILITY_TYPE         END AS FACILITY_TYPE,         -- P
    CASE WHEN MATCH_TIER >= 6 THEN NULL ELSE D_HCO_COMPILE_ID      END AS D_HCO_COMPILE_ID,      -- Q
    CASE WHEN MATCH_TIER >= 6 THEN NULL ELSE HCO_NAME              END AS HCO_NAME,              -- R
    MATCH_TIER,
    MATCH_STATUS
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
ORDER BY SHEET_ROW;


/* ---------------------------------------------------------------------------
   B2. Needs review. Everything that is not a clean, hospital-typed,
       HCO-carrying, untied match. This is the list to work through by hand and
       the list to take back to Kolin, rather than quietly guessing at it.
   --------------------------------------------------------------------------- */
SELECT
    SHEET_ROW,
    ATC_NAME,
    ATC_ADDRESS,
    ATC_CITY,
    ATC_STATE,
    ATC_ZIP5,
    MATCH_STATUS,
    MATCH_TIER,
    D_FACILITY_COMPILE_ID,
    FACILITY_NAME,
    FACILITY_TYPE,
    FAC_ADDR_NORM,
    NAME_SIM,
    ADDR_SIM
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
WHERE MATCH_STATUS <> 'OK'
ORDER BY MATCH_TIER NULLS FIRST, SHEET_ROW;


/* ---------------------------------------------------------------------------
   B3. Runner-up candidates, for any ATC where more than one facility tied at
       the winning tier. These are the rows where the sort order decided it
       rather than the data, so they are the ones worth overruling by eye.
       Reads the candidate table, so it cannot disagree with the pick.
   --------------------------------------------------------------------------- */
SELECT
    c.SHEET_ROW,
    m.ATC_NAME,
    c.FACILITY_ID,
    c.FACILITY_NAME,
    c.FACILITY_TYPE,
    c.FAC_ADDR_NORM,
    c.FAC_CITY,
    c.FAC_ZIP5,
    c.NAME_SIM,
    c.ADDR_SIM,
    c.MATCH_TIER,
    CASE WHEN c.FACILITY_ID = m.D_FACILITY_COMPILE_ID THEN 'PICKED' ELSE 'runner-up' END AS PICK
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_CANDIDATES c
INNER JOIN COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED m
        ON c.SHEET_ROW  = m.SHEET_ROW
       AND c.MATCH_TIER = m.MATCH_TIER
WHERE m.TIED_AT_TIER > 1
ORDER BY c.SHEET_ROW, PICK, c.NAME_SIM DESC;


/* ---------------------------------------------------------------------------
   B4. Address disagreements. Where the ATC matched but Compile puts it in a
       different city or zip than the sheet does.

       This is the Gilbert versus Phoenix question answered for every row at
       once. A disagreement here is not a bad match - the match was made on the
       street - and it is usually the SHEET that is wrong, since Compile carries
       the address of the actual building. Take this list back before the orange
       columns are treated as final.
   --------------------------------------------------------------------------- */
SELECT
    SHEET_ROW,
    ATC_NAME,
    ATC_CITY  AS SHEET_CITY,
    FAC_CITY  AS COMPILE_CITY,
    ATC_ZIP5  AS SHEET_ZIP,
    FAC_ZIP5  AS COMPILE_ZIP,
    ATC_ADDRESS,
    FAC_ADDR_NORM,
    MATCH_TIER,
    CASE WHEN ATC_CITY <> FAC_CITY AND ATC_ZIP5 <> FAC_ZIP5 THEN 'CITY AND ZIP DIFFER'
         WHEN ATC_CITY <> FAC_CITY                          THEN 'CITY DIFFERS'
         ELSE 'ZIP DIFFERS'
    END AS DISAGREEMENT
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
WHERE D_FACILITY_COMPILE_ID IS NOT NULL
  AND MATCH_TIER < 6   -- tiers 6 and 7 are not location-confirmed
  AND (ATC_CITY <> FAC_CITY OR ATC_ZIP5 <> FAC_ZIP5)
ORDER BY SHEET_ROW;


/* ---------------------------------------------------------------------------
   B5. What the run achieved, by tier. Read this before B1.
   --------------------------------------------------------------------------- */
SELECT
    COALESCE(MATCH_TIER, 0) AS MATCH_TIER,
    CASE COALESCE(MATCH_TIER, 0)
        WHEN 0 THEN 'no match at all'
        WHEN 1 THEN 'NPI equal'
        WHEN 2 THEN 'zip + full address'
        WHEN 3 THEN 'zip + number + street'
        WHEN 4 THEN 'city + number + street'
        WHEN 5 THEN 'state + number + close address'
        WHEN 6 THEN 'NPI agrees, address does not - not pasted'
        WHEN 7 THEN 'name suggestion only, not pasted'
    END AS TIER_MEANING,
    COUNT(*) AS ATCS,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS PCT_OF_LIST
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
GROUP BY 1, 2
ORDER BY 1;



/* ############################################################################
   PART C  -  QA. Every one of these passes before B1 goes in the sheet.

   C1 to C3 fail loudly. A failing check throws a Snowflake error whose message
   carries the reason and the counts, rather than returning a FAIL row that is
   easy to scroll past. The trick is TO_NUMBER on a string built from a column,
   so it cannot be folded away at compile time and the message survives.
   ############################################################################ */


/* ---------------------------------------------------------------------------
   C1. Rows in equals rows out, exactly.

       Closed form: ATC_XWALK_MATCHED has exactly as many rows as
       ATC_XWALK_INPUT, no more and no fewer. One row per ATC is the grain, held
       by the LEFT JOIN from the input plus one picked row per SHEET_ROW. If
       this fails, the paste-back is misaligned and every ID below the break
       sits on the wrong hospital.
   --------------------------------------------------------------------------- */
WITH c AS (
    SELECT
        (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT)   AS ROWS_IN,
        (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED) AS ROWS_OUT
)
SELECT
    ROWS_IN,
    ROWS_OUT,
    CASE WHEN ROWS_IN = ROWS_OUT THEN 'PASS'
         ELSE TO_VARCHAR(TO_NUMBER('FAIL C1 grain broken: ' || ROWS_IN
                                   || ' ATCs in, ' || ROWS_OUT || ' rows out'))
    END AS CHECK_RESULT
FROM c;


/* ---------------------------------------------------------------------------
   C2. No ATC appears twice. Same failure mode as C1, different cause.
   --------------------------------------------------------------------------- */
WITH d AS (
    SELECT COUNT(*) AS BAD
    FROM (
        SELECT SHEET_ROW
        FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
        GROUP BY 1
        HAVING COUNT(*) > 1
    )
)
SELECT
    BAD AS DUPLICATED_ATCS,
    CASE WHEN BAD = 0 THEN 'PASS'
         ELSE TO_VARCHAR(TO_NUMBER('FAIL C2: ' || BAD || ' ATC rows duplicated in the output'))
    END AS CHECK_RESULT
FROM d;


/* ---------------------------------------------------------------------------
   C3A. No facility ID claimed by more than one ATC.

        Two ATCs on one Compile facility means either a genuine shared campus
        or, far more likely, a bad match that will double-count patients the
        moment these IDs are used to pull claims. It stops the run on purpose.
   --------------------------------------------------------------------------- */
WITH d AS (
    SELECT COUNT(*) AS BAD
    FROM (
        SELECT D_FACILITY_COMPILE_ID
        FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
        WHERE D_FACILITY_COMPILE_ID IS NOT NULL
        GROUP BY 1
        HAVING COUNT(*) > $max_atcs_per_facility
    )
)
SELECT
    BAD AS SHARED_FACILITIES,
    CASE WHEN BAD = 0 THEN 'PASS'
         ELSE TO_VARCHAR(TO_NUMBER('FAIL C3A: ' || BAD
                                   || ' facility IDs claimed by more than one ATC'))
    END AS CHECK_RESULT
FROM d;

-- If C3A failed, this names them.
SELECT
    D_FACILITY_COMPILE_ID,
    FACILITY_NAME,
    COUNT(*)                                    AS ATC_COUNT,
    LISTAGG(ATC_NAME, ' | ')
        WITHIN GROUP (ORDER BY SHEET_ROW)       AS ATCS_SHARING_IT
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
WHERE D_FACILITY_COMPILE_ID IS NOT NULL
GROUP BY 1, 2
HAVING COUNT(*) > 1
ORDER BY 3 DESC;


/* ---------------------------------------------------------------------------
   C3B. One HCO per facility. If the hierarchy has no level column and the
        QUALIFY in Step 4 was removed, this is what proves the join did not
        quietly fan a facility out into several HCO rows.
   --------------------------------------------------------------------------- */
SELECT
    COUNT(*)                                       AS FACILITIES_WITH_MULTIPLE_HCOS,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'REVIEW - see 0E' END AS CHECK_RESULT
FROM (
    SELECT D_FACILITY_COMPILE_ID
    FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
    WHERE D_FACILITY_COMPILE_ID IS NOT NULL
    GROUP BY 1
    HAVING COUNT(DISTINCT D_HCO_COMPILE_ID) > 1
);


/* ---------------------------------------------------------------------------
   C4. What the hospital preference actually cost.

       Every ATC whose best match is not typed HOSPITALS, listed by name. These
       are the rows a hard "account type = Hospital" filter would have thrown
       away, and the run would have reported them as unmatched rather than as
       filtered. Report, do not drop.
   --------------------------------------------------------------------------- */
SELECT
    SHEET_ROW,
    ATC_NAME,
    FACILITY_NAME,
    FACILITY_TYPE,
    MATCH_TIER,
    D_FACILITY_COMPILE_ID
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
WHERE D_FACILITY_COMPILE_ID IS NOT NULL
  AND FACILITY_TYPE <> 'HOSPITALS'
ORDER BY SHEET_ROW;


/* ---------------------------------------------------------------------------
   C5. Reproduce the four rows Kolin already filled in.

       He populated rows 3 to 6 by hand. Those four are the only ground truth
       there is, so this query has to return exactly what he got before the
       other 89 are trusted. Type the expected IDs in from the sheet, not from
       anything transcribed here - the screenshot cut the strings off mid-value.

       A MISMATCH means the pick rule or the HCO level is wrong. Fix the rule.
       Do not special-case the row.
   --------------------------------------------------------------------------- */
WITH expected AS (
    SELECT * FROM VALUES
        (3, 'PASTE_CELL_N3', 'PASTE_CELL_Q3'),
        (4, 'PASTE_CELL_N4', 'PASTE_CELL_Q4'),
        (5, 'PASTE_CELL_N5', 'PASTE_CELL_Q5'),
        (6, 'PASTE_CELL_N6', 'PASTE_CELL_Q6')
    AS e(SHEET_ROW, EXPECTED_FACILITY_ID, EXPECTED_HCO_ID)
)
SELECT
    e.SHEET_ROW,
    m.ATC_NAME,
    e.EXPECTED_FACILITY_ID,
    m.D_FACILITY_COMPILE_ID AS GOT_FACILITY_ID,
    e.EXPECTED_HCO_ID,
    m.D_HCO_COMPILE_ID      AS GOT_HCO_ID,
    m.MATCH_TIER,
    CASE WHEN e.EXPECTED_FACILITY_ID = m.D_FACILITY_COMPILE_ID
          AND e.EXPECTED_HCO_ID      = m.D_HCO_COMPILE_ID THEN 'PASS'
         ELSE 'MISMATCH - fix the rule, not the row'
    END AS CHECK_RESULT
FROM expected e
LEFT JOIN COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED m ON e.SHEET_ROW = m.SHEET_ROW
ORDER BY e.SHEET_ROW;


/* ---------------------------------------------------------------------------
   C6. Second, independent route to the HCO ID, through the claims.

       The site of care pipeline already reads D_PRIMARY_HCO_NPI next to
       D_PRIMARY_HCO_COMPILE_ID on every medical claim. So for any ATC with a
       real NPI there is a second way to reach the HCO ID that never touches the
       Provider360 hierarchy at all.

       Two routes to the same value exist here on purpose, and this is the check
       that proves they agree. A disagreement usually means the hierarchy is
       returning the parent system where the claims return the hospital.

       The NPI list is pushed into the claims scan so this stays cheap - without
       it this reads the whole claims table.
   --------------------------------------------------------------------------- */
WITH atc_npis AS (
    SELECT DISTINCT ATC_NPI
    FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
    WHERE ATC_NPI IS NOT NULL
),
claims_hco AS (
    SELECT DISTINCT
        TRIM(D_PRIMARY_HCO_NPI)  AS NPI,
        D_PRIMARY_HCO_COMPILE_ID AS CLAIMS_HCO_ID
    FROM COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS
    WHERE TRIM(D_PRIMARY_HCO_NPI) IN (SELECT ATC_NPI FROM atc_npis)
      AND DATE_OF_SERVICE >= DATE '2021-01-01'
      AND DATE_OF_SERVICE <  DATE '2026-01-01'
)
SELECT
    m.SHEET_ROW,
    m.ATC_NAME,
    m.ATC_NPI,
    m.D_HCO_COMPILE_ID AS HIERARCHY_HCO_ID,
    c.CLAIMS_HCO_ID,
    CASE WHEN c.CLAIMS_HCO_ID IS NULL              THEN 'no claims for this NPI'
         WHEN m.D_HCO_COMPILE_ID IS NULL           THEN 'hierarchy returned nothing'
         WHEN m.D_HCO_COMPILE_ID = c.CLAIMS_HCO_ID THEN 'AGREE'
         ELSE 'DISAGREE - hierarchy and claims give different HCOs'
    END AS CHECK_RESULT
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED m
LEFT JOIN claims_hco c ON m.ATC_NPI = c.NPI
WHERE m.ATC_NPI IS NOT NULL
ORDER BY m.SHEET_ROW;


/* ---------------------------------------------------------------------------
   C7. Provenance. What ran, against what, on what date.
   --------------------------------------------------------------------------- */
SELECT
    $as_of_date::DATE                                              AS AS_OF_DATE,
    'ATC Check_Excersise / Active ATC List, orange columns J to M' AS INPUT_SOURCE,
    'COMPILE_PROVIDER360.ENTITIES.IOV2501_FACILITY_ATTRIBUTES'     AS FACILITY_SOURCE,
    'COMPILE_PROVIDER360.RELATIONSHIPS.IOV2501_HCO_FULL_HIERARCHY' AS HCO_SOURCE,
    $min_name_similarity                                           AS MIN_NAME_SIMILARITY,
    $min_addr_similarity                                           AS MIN_ADDR_SIMILARITY,
    (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_XWALK_INPUT)      AS ATCS_IN,
    (SELECT COUNT(*) FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
      WHERE MATCH_STATUS = 'OK')                                   AS ATCS_CLEANLY_MATCHED;

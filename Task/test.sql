/* ============================================================================
   TEST - what does Compile actually hold for the ATCs that found nothing

   Run this after "ATC crosswalk - build and verify.sql", which is what creates
   ATC_XWALK_MATCHED. Read only, safe to repeat.

   WHY
       Five ATCs came back NO MATCH: no candidate at any tier. That could mean
       two different things and the crosswalk cannot tell them apart:
         a) the building genuinely is not in Compile, or
         b) it is there under an address our matching rules could not reach.

       This looks straight at the facility table with no matching logic in the
       way, listing every hospital Compile holds in that ATC's own city. If the
       right building is in the list, take its ID by hand. If the list has
       nothing that fits, the answer is (a) and that row goes back to the
       business owner rather than being guessed at.

   WHAT TO SEND BACK
       The whole grid. Read the addresses beside ATC_ADDRESS, not the names.

   NOTE ON THE HOSPITAL FILTER
       Restricted to FACILITY_TYPE = 'HOSPITALS' only to keep the grid short
       enough to read. All five of these ATCs are hospitals by name. If one of
       them turns up nothing here, delete that line and run it again before
       concluding the building is absent, because Compile types plenty of real
       hospitals as CLINIC or PHYSICIAN GROUP.
   ============================================================================ */

SELECT
    m.ATC_NAME,
    m.ATC_ADDRESS,
    m.ATC_CITY,
    m.ATC_ZIP5,
    f.D_FACILITY_COMPILE_ID,
    f.FACILITY_NAME,
    f.FACILITY_TYPE,
    f.FACILITY_ADDRESS_LINE_1,
    f.FACILITY_ZIP_5
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED m
INNER JOIN COMPILE_PROVIDER360.ENTITIES.IOV2501_FACILITY_ATTRIBUTES f
        ON UPPER(TRIM(f.FACILITY_CITY))  = m.ATC_CITY
       AND UPPER(TRIM(f.FACILITY_STATE)) = m.ATC_STATE
WHERE m.MATCH_STATUS = 'NO MATCH'
  AND f.FACILITY_TYPE = 'HOSPITALS'
ORDER BY m.ATC_NAME, f.FACILITY_NAME;

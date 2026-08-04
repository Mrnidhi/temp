/* ============================================================================
   TEST - what to paste and what still needs a decision

   Run after "ATC crosswalk - build and verify.sql", which is what creates
   ATC_XWALK_MATCHED. Read only, safe to repeat.

   T1 is the one to work from. T2 is kept as reference for how the five
   unmatched centres were resolved.
   ============================================================================ */


/* ---------------------------------------------------------------------------
   T1. Every ATC with a plain instruction beside it.

       ACTION says one of three things:

         PASTE          the address matched, put the five columns in the sheet.
                        This includes rows flagged "not a hospital type" and
                        "address is close": in both cases the building is right
                        and only Compile's account type or its spelling of the
                        street is unusual. Mayo Jacksonville sits at exactly
                        4500 San Pablo Rd S and is filed as PHYSICIAN GROUP;
                        that is Compile's filing habit, not a bad match.

         DECIDE         two facilities scored the same, or the address is too
                        far off to accept on its own. Open the worklist, read
                        the candidate addresses, choose one.

         DO NOT PASTE   no candidate at all, or the only candidate is a
                        different building. Leave the cells blank and take the
                        question back rather than guessing.

       The 90 threshold is not arbitrary. Everything at 90 or above in the run
       of 2026-08-04 was the same building with a formatting difference, and
       everything below it was a different building on the same campus.
   --------------------------------------------------------------------------- */
SELECT
    ATC_NAME,
    D_FACILITY_COMPILE_ID,
    FACILITY_NAME,
    FACILITY_TYPE,
    D_HCO_COMPILE_ID,
    HCO_NAME,
    ADDR_SIM,
    MATCH_STATUS,
    CASE
        WHEN MATCH_STATUS IN ('NO MATCH', 'ADDRESS MISMATCH - do not paste')
            THEN 'DO NOT PASTE'
        WHEN MATCH_STATUS = 'REVIEW - two facilities scored the same'
            THEN 'DECIDE - see worklist'
        WHEN ADDR_SIM >= 90
            THEN 'PASTE'
        ELSE 'DECIDE - see worklist'
    END AS ACTION
FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
ORDER BY ACTION, ATC_NAME;


/* ---------------------------------------------------------------------------
   T2. Reference. What Compile actually holds for the centres that found
       nothing, with no matching logic in the way.

       This is how the five blanks were worked on 2026-08-04. Four were
       resolved by hand from this grid and one was sent back:

         UF Health Cancer Center    SHANDS TEACHING HOSPITAL, 1600 SW Archer Rd.
                                    All three Shands rows carry the same HCO, so
                                    the HCO is certain whichever building is used.
                                    2033 Mowry Rd is the research building and
                                    Compile does not carry it.
         Uk Albert B Chandler       UNIVERSITY OF KENTUCKY, 800 Rose St. The
                                    hospital's real address; 1000 S Limestone in
                                    the sheet is the campus mailing address. Take
                                    the university, not UK HOSPITAL CLINICAL LAB,
                                    which shares the location under another HCO.
         UofL Health-Jewish         JEWISH HOSPITAL, 217 E Chestnut St. Same block
                                    as 200 Abraham Flexner Way.
         Avera McKennan             AVERA MCKENNAN, 1000 E 23rd St. Lower
                                    confidence. AVERA MCKENNAN TRANSPLANT sits at
                                    1315 S Cliff Ave, one door from the sheet's
                                    1325, but under a different HCO, and the plain
                                    hospital is the entity claims run through.
         TriHealth                  Not resolved. 625 Eden Park Dr is a corporate
                                    office and Compile has no facility there.
                                    TriHealth's hospitals here are Good Samaritan
                                    and Bethesda North; which one is authorized is
                                    a question for the business owner.

       Restricted to HOSPITALS to keep the grid readable. If a centre returns
       nothing, delete that line and run again before concluding it is absent,
       because Compile files plenty of real hospitals as CLINIC or PHYSICIAN
       GROUP.
   --------------------------------------------------------------------------- */
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

/* ============================================================================
   ATC to Compile crosswalk - the final record

   Run after "ATC crosswalk - build and verify.sql", which is what builds
   ATC_XWALK_MATCHED. Read only, one statement, safe to repeat.

   WHAT THIS IS
       One row per ATC, the four columns the sheet asks for, and a plain
       instruction beside each. Download it with the arrow above the result
       grid and keep the CSV: it is the record of what went into the workbook
       on 2026-08-04 and why, including the rows that were decided by hand.

   HOW TO READ FINAL_ACTION
       PASTE              put the four columns in the sheet as they are
       PASTE WITH NOTE    the ID is right, but the address in the sheet is
                          wrong and the business owner should be told
       RESOLVE BY HAND    the crosswalk found nothing; NOTE says which facility
                          to use and where it came from
       ASK KOLIN          genuinely ambiguous, leave the cells blank

   WHERE THE HAND DECISIONS CAME FROM
       Every override below was read out of the facility table directly, by
       listing every hospital Compile holds in that ATC's own city and reading
       the addresses. None of them were guessed from the names.

   COUNT ON 2026-08-04
       97 ATCs. 95 fill in, 2 go back to the business owner.
   ============================================================================ */

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
        /* Found nothing. The right facility was identified by hand from the
           facility table and is named in NOTE. */
        WHEN UPPER(ATC_NAME) LIKE 'UF HEALTH CANCER CENTER%'      THEN 'RESOLVE BY HAND'
        WHEN UPPER(ATC_NAME) LIKE 'UK ALBERT B CHANDLER%'         THEN 'RESOLVE BY HAND'
        WHEN UPPER(ATC_NAME) LIKE 'UNIVERSITY OF LOUISVILLE%'     THEN 'RESOLVE BY HAND'

        /* Genuinely ambiguous. Not ours to decide. */
        WHEN UPPER(ATC_NAME) LIKE 'AVERA MCKENNAN%'               THEN 'ASK KOLIN'
        WHEN UPPER(ATC_NAME) LIKE 'TRIHEALTH%'                    THEN 'ASK KOLIN'

        /* Right hospital, wrong address in the sheet. */
        WHEN UPPER(ATC_NAME) LIKE 'NORTHWELL HEALTH%'             THEN 'PASTE WITH NOTE'
        WHEN UPPER(ATC_NAME) LIKE 'OHIO STATE UNIVERSITY WEXNER%' THEN 'PASTE WITH NOTE'
        WHEN UPPER(ATC_NAME) LIKE 'O NEAL COMPREHENSIVE%'         THEN 'PASTE WITH NOTE'

        /* Everything else the crosswalk resolved. The four rows that scored
           below 90 are here on purpose: in each one the facility name and the
           HCO name match the centre exactly and only the way the address is
           written differs. */
        ELSE 'PASTE'
    END AS FINAL_ACTION,

    CASE
        WHEN UPPER(ATC_NAME) LIKE 'UF HEALTH CANCER CENTER%'
            THEN 'Use SHANDS TEACHING HOSPITAL AND CLINICS INC at 1600 SW Archer Rd, 32610. All three Shands buildings share one HCO, so the HCO is certain. 2033 Mowry Rd is the research building and Compile does not hold it.'
        WHEN UPPER(ATC_NAME) LIKE 'UK ALBERT B CHANDLER%'
            THEN 'Use UNIVERSITY OF KENTUCKY at 800 Rose St, 40536, which is the hospital''s real address. 1000 S Limestone in the sheet is the campus mailing address. Do not take UK HOSPITAL CLINICAL LAB, which shares the same location under a different HCO.'
        WHEN UPPER(ATC_NAME) LIKE 'UNIVERSITY OF LOUISVILLE%'
            THEN 'Use JEWISH HOSPITAL at 217 E Chestnut St, 40202. Same block as the 200 Abraham Flexner Way in the sheet, and the only Jewish Hospital Compile holds in Louisville.'

        WHEN UPPER(ATC_NAME) LIKE 'AVERA MCKENNAN%'
            THEN 'Two candidates under different HCOs. AVERA MCKENNAN TRANSPLANT INSTITUTE sits at 1315 S Cliff Ave, one building from the 1325 S Cliff Ave in the sheet. AVERA MCKENNAN sits at 1000 E 23rd St, a different street. Address says the transplant institute; which entity is authorized is a question for Kolin.'
        WHEN UPPER(ATC_NAME) LIKE 'TRIHEALTH%'
            THEN 'The 625 Eden Park Dr in the sheet is a corporate office and Compile holds no facility there. TriHealth''s two hospitals in Cincinnati are THE GOOD SAMARITAN HOSPITAL OF CINCINNATI and BETHESDA NORTH HOSPITAL. Which one is the authorized site is a question for Kolin.'

        WHEN UPPER(ATC_NAME) LIKE 'NORTHWELL HEALTH%'
            THEN 'Facility and HCO are both NORTH SHORE UNIVERSITY HOSPITAL, so the ID is right. The sheet says 800 Community Dr; the hospital is at 300 Community Dr. The sheet is the thing to correct.'
        WHEN UPPER(ATC_NAME) LIKE 'OHIO STATE UNIVERSITY WEXNER%'
            THEN 'Facility is OHIO STATE UNIVERSITY HOSPITALS and the HCO is The Ohio State University Wexner Medical Center, so the ID is right. The sheet says 520 W 10th Ave; the main hospital is at 410 W 10th Ave. Same street.'
        WHEN UPPER(ATC_NAME) LIKE 'O NEAL COMPREHENSIVE%'
            THEN 'Returns exactly the ID the business owner had already filled in by hand. The sheet says 1802 6th St in 35205; Compile says 1802 6th Ave S in 35233, and Compile is right.'

        WHEN UPPER(ATC_NAME) LIKE 'BARNES-JEWISH%'
            THEN 'Scores low only because the sheet puts the hospital''s name in the address field rather than a street. Facility and HCO are both BARNES-JEWISH HOSPITAL.'
        WHEN UPPER(ATC_NAME) LIKE 'JERSEY SHORE%'
            THEN 'Same building. The sheet writes 1945 State Route 33, Compile writes 1945 RTE 33.'
        WHEN UPPER(ATC_NAME) LIKE 'MAYO CLINIC HOSPITAL-ROCHESTER%'
            THEN 'Same building. The sheet writes 201 Center St W, Compile writes 201 W Center St.'
        WHEN UPPER(ATC_NAME) LIKE 'CITY OF HOPE DUARTE%'
            THEN 'Same building. Compile drops the E from 1500 E Duarte Rd. The HCO is the Helford hospital, which is the licensed hospital on that campus.'

        WHEN FACILITY_TYPE <> 'HOSPITALS'
            THEN 'Address matches exactly. Compile files this one as ' || FACILITY_TYPE || ' rather than HOSPITALS, which is its filing habit and not a bad match.'
        ELSE NULL
    END AS NOTE,

    AS_OF_DATE

FROM COMPILE_DEV.PUBLIC.ATC_XWALK_MATCHED
ORDER BY FINAL_ACTION, ATC_NAME;

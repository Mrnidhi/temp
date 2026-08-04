/* ============================================================================
   The three ATCs filled in by hand

   Run in Snowflake. Read only, one statement.

   WHY THIS EXISTS
       The crosswalk found no candidate at any tier for five centres. Three of
       them were resolved by reading the facility table directly, listing every
       hospital Compile holds in that centre's own city and reading the
       addresses. None was guessed from a name. This query returns those three
       so the values can be copied into the workbook rather than typed.

       The other two, TriHealth and Avera McKennan, are genuinely ambiguous and
       are questions for the business owner. Their cells stay empty.

   WHY IT LOOKS THEM UP BY ADDRESS RATHER THAN BY ID
       So no facility ID has to be transcribed by hand. Transcribing an ID by
       eye is exactly the kind of error that would be invisible afterwards.

   WHAT TO DO WITH IT
       Three rows come back. Copy columns 2 to 6 of each into N to R of the
       workbook row named in the first column.

       If any of the three returns more than one row, or none at all, stop and
       look at it before pasting anything.

   THE THREE, AND WHERE THEY CAME FROM
       Row 24  UF Health Cancer Center
               Shands Teaching Hospital and Clinics at 1600 SW Archer Rd.
               All three Shands buildings share one HCO, so the HCO is certain
               whichever is used. The 2033 Mowry Rd on the sheet is the
               research building and Compile does not hold it.

       Row 38  Uk Albert B Chandler Hospital
               University of Kentucky at 800 Rose St, which is the hospital's
               real address. The 1000 S Limestone on the sheet is a campus
               mailing address. Deliberately not UK Hospital Clinical Lab,
               which sits at the same location under a different HCO.

       Row 39  University Of Louisville Health-Jewish Hospital
               Jewish Hospital at 217 E Chestnut St, the same block as the
               200 Abraham Flexner Way on the sheet, and the only Jewish
               Hospital Compile holds in Louisville.
   ============================================================================ */

SELECT
    CASE WHEN f.FACILITY_ZIP_5 = '32610' THEN 'ROW 24 - UF Health'
         WHEN f.FACILITY_ZIP_5 = '40536' THEN 'ROW 38 - UK Chandler'
         ELSE                                  'ROW 39 - UofL Jewish'
    END AS PUT_IT_HERE,
    f.D_FACILITY_COMPILE_ID,
    f.FACILITY_NAME,
    f.FACILITY_TYPE,
    h.D_HCO_COMPILE_ID,
    h.HCO_NAME
FROM COMPILE_PROVIDER360.ENTITIES.IOV2501_FACILITY_ATTRIBUTES f
LEFT JOIN COMPILE_PROVIDER360.RELATIONSHIPS.IOV2501_HCO_FULL_HIERARCHY h
       ON f.D_FACILITY_COMPILE_ID = h.D_FACILITY_COMPILE_ID
WHERE (f.FACILITY_ZIP_5 = '32610'
       AND UPPER(f.FACILITY_ADDRESS_LINE_1) LIKE '1600 SW ARCHER%')
   OR (f.FACILITY_ZIP_5 = '40536'
       AND UPPER(f.FACILITY_NAME)           LIKE 'UNIVERSITY OF KENTUCKY%'
       AND UPPER(f.FACILITY_ADDRESS_LINE_1) LIKE '800 ROSE%')
   OR (f.FACILITY_ZIP_5 = '40202'
       AND UPPER(f.FACILITY_NAME)           LIKE 'JEWISH HOSPITAL%'
       AND UPPER(f.FACILITY_ADDRESS_LINE_1) LIKE '217 E CHESTNUT%')
ORDER BY PUT_IT_HERE;

/* STEP 2 of 2. Run in SNOWFLAKE.

   Searches the NON-ATC population for every one of Infinity's 93 authorized ATC
   accounts. Anything this returns is a parent we scored as non-ATC whose name
   matches a real ATC = a roster gap.

   Matching is by distinctive name token (no shared ID across the two systems).
   Some hits will be false positives or multi-site systems where only ONE site is
   an ATC (Kaiser, Providence, St Luke, Baylor). MATCHED_TOKEN is returned so each
   row can be judged rather than trusted blindly. Paste back all rows. */

WITH atc_tokens AS (
    SELECT TOKEN FROM VALUES
        ('ADVENTHEALTH'), ('ADVOCATE'), ('AVERA'), ('BANNER'), ('BARNES-JEWISH'),
        ('BAYLOR'), ('BETH ISRAEL'), ('CEDARS'), ('CITY OF HOPE'), ('CLEVELAND CLINIC'),
        ('COLUMBIA UNIVERSITY'), ('COMMUNITY HEALTH NETWORK'), ('COOPER UNIVERSITY'),
        ('COREWELL'), ('FARBER'), ('DUKE'), ('EMORY'), ('FOX CHASE'), ('HUTCHINSON'),
        ('FROEDTERT'), ('HOAG'), ('HACKENSACK'), ('HONORHEALTH'),
        ('UNIVERSITY OF PENNSYLVANIA'), ('HOUSTON METHODIST'), ('INTERMOUNTAIN'),
        ('JERSEY SHORE'), ('HOPKINS'), ('KAISER'), ('KARMANOS'), ('LEHIGH'),
        ('FAIRVIEW'), ('HOLLINGS'), ('MASSACHUSETTS GENERAL'), ('MAYO'), ('MEDSTAR'),
        ('GEORGETOWN'), ('SLOAN'), ('MOFFITT'), ('MONTEFIORE'), ('LANGONE'),
        ('NEBRASKA MEDICAL'), ('WEILL CORNELL'), ('NEW YORK-PRESBYTERIAN'),
        ('NORTHSIDE'), ('NORTHWELL'), ('NOVANT'), ('UAB'), ('O NEAL'), ('OHSU'),
        ('OREGON HEALTH'), ('OCHSNER'), ('WEXNER'), ('OHIO STATE'), ('ORLANDO HEALTH'),
        ('PROVIDENCE'), ('LURIE'), ('NORTHWESTERN'), ('UCLA'), ('ROSWELL'), ('RUSH'),
        ('SARAH CANNON'), ('ST LUKE'), ('STANFORD'), ('COLORADO BLOOD'), ('JEFFERSON'),
        ('TRIHEALTH'), ('UNIVERSITY OF COLORADO'), ('UC SAN DIEGO'), ('UCSF'),
        ('UF HEALTH'), ('UPMC'), ('NORRIS'), ('UT SOUTHWESTERN'), ('UW HEALTH'),
        ('CHANDLER'), ('UNIVERSITY HOSPITALS CLEVELAND'), ('UNIVERSITY OF CHICAGO'),
        ('UNIVERSITY OF CINCINNATI'), ('UNIVERSITY OF IOWA'), ('UNIVERSITY OF KANSAS'),
        ('UNIVERSITY OF LOUISVILLE'), ('UNIVERSITY OF MARYLAND'), ('SYLVESTER'),
        ('UNIVERSITY OF NORTH CAROLINA'), ('UNIVERSITY OF OKLAHOMA'),
        ('UNIVERSITY OF TENNESSEE'), ('MD ANDERSON'), ('HUNTSMAN'), ('VCU'),
        ('VIRGINIA COMMONWEALTH'), ('VANDERBILT'), ('WEST PENN'), ('YALE')
    AS t(TOKEN)
),
nonatc AS (
    SELECT
        COALESCE(NULLIF(TRIM(HCO_PARENT_NAME), ''), 'Unknown / unmapped') AS PARENT,
        COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
    FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
    WHERE CLASS_FINAL LIKE 'Non-ATC%'
    GROUP BY 1
)
SELECT
    n.PARENT,
    n.PATIENTS,
    LISTAGG(DISTINCT t.TOKEN, ', ') AS MATCHED_TOKEN
FROM nonatc n
JOIN atc_tokens t
    ON UPPER(n.PARENT) LIKE '%' || t.TOKEN || '%'
GROUP BY n.PARENT, n.PATIENTS
ORDER BY n.PATIENTS DESC;
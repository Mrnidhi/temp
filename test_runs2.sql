/* ============================================================================
   Infinity - check flagged accounts against the authoritative ATC list
   Run in INFINITY (not Snowflake).

   file_Veeva_Komodo_ATC_Mapping is the ATC account master. This searches it for
   the big accounts our Snowflake result flagged as "non-ATC" (C2) or "100%
   satellite" (C5b). Any account that shows up here IS a real ATC, which means
   the Snowflake roster missed it (a list gap), not true leakage.

   Match is by NAME (no shared ID across the two systems), so we search by
   distinctive tokens. Paste back both results.
   ============================================================================ */

-- Q1: how big is the ATC universe (for context)
SELECT COUNT(*) AS ROWS, COUNT(DISTINCT VEEVA_NAME) AS DISTINCT_ATC_ACCOUNTS
FROM file_Veeva_Komodo_ATC_Mapping;


-- Q2: do our flagged accounts appear in the ATC list?
SELECT VEEVA_NAME, CITY, STATE, TERRITORY, REGION, ATC_SEGMENT, PPS_STATUS
FROM file_Veeva_Komodo_ATC_Mapping
WHERE UPPER(VEEVA_NAME) LIKE '%MICHIGAN%'          -- top non-ATC (531 pts)
   OR UPPER(VEEVA_NAME) LIKE '%CITY OF HOPE%'       -- 298
   OR UPPER(VEEVA_NAME) LIKE '%LANGONE%'            -- NYU, 216
   OR UPPER(VEEVA_NAME) LIKE '%TEXAS ONCOLOGY%'     -- 211
   OR UPPER(VEEVA_NAME) LIKE '%FLORIDA CANCER%'     -- 197
   OR UPPER(VEEVA_NAME) LIKE '%DARTMOUTH%'          -- 189
   OR UPPER(VEEVA_NAME) LIKE '%INDIANA UNIVERSITY%' -- 188
   OR UPPER(VEEVA_NAME) LIKE '%SUTTER%'             -- 186
   OR UPPER(VEEVA_NAME) LIKE '%KAISER%'             -- 166
   OR UPPER(VEEVA_NAME) LIKE '%UNIVERSITY OF VIRGINIA%' -- 138
   OR UPPER(VEEVA_NAME) LIKE '%BAPTIST%'            -- 138 + 134
   OR UPPER(VEEVA_NAME) LIKE '%HARTFORD%'           -- 109
   OR UPPER(VEEVA_NAME) LIKE '%COMMONSPIRIT%'       -- 100
   OR UPPER(VEEVA_NAME) LIKE '%AMERICAN ONCOLOGY%'  -- 92
   OR UPPER(VEEVA_NAME) LIKE '%SPARTANBURG%'        -- 89
   OR UPPER(VEEVA_NAME) LIKE '%KETTERING%'          -- 85
   OR UPPER(VEEVA_NAME) LIKE '%PROVIDENCE%'         -- 85
   OR UPPER(VEEVA_NAME) LIKE '%CLEARVIEW%'          -- 234 (likely NOT an ATC - imaging)
   -- a few 100%-satellite parents, to confirm they are real ATCs:
   OR UPPER(VEEVA_NAME) LIKE '%SLOAN%'              -- MSK
   OR UPPER(VEEVA_NAME) LIKE '%HUTCHINSON%'         -- Fred Hutch
   OR UPPER(VEEVA_NAME) LIKE '%CLEVELAND CLINIC%'
   OR UPPER(VEEVA_NAME) LIKE '%BANNER%'
   OR UPPER(VEEVA_NAME) LIKE '%JEFFERSON%'
ORDER BY VEEVA_NAME;
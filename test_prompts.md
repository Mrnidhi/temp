Build an Excel workbook: "ATC Site of Care — Patient Counts.xlsx" for a CEO request (row per ATC with patient counts, an opportunity view, and a methodology summary). Use openpyxl, Arial font throughout, and after building, recalculate the formulas. This is the real deliverable — no "SAMPLE" labels, and use the full query output (every row), not a subset.

Step 1 — run these three Snowflake queries (the base tables already exist):

-- Q_SUMMARY : site-of-care split (must tie to the deck: ATC 7,501 / Hospital 7,100 / Community 1,317 / Other 328 / total 16,246)
WITH bucketed AS (
  SELECT D_PATIENT_ID,
    CASE WHEN CLASS_FINAL = 'ATC' THEN 'ATC Network'
         WHEN CLASS_FINAL = 'Non-ATC: Community Network' THEN 'Non-ATC: Community network'
         WHEN CLASS_FINAL IN ('Non-ATC: Unknown','Needs Review') THEN 'Non-ATC: Other'
         ELSE 'Non-ATC: Hospital' END AS SITE_OF_CARE
  FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
)
SELECT SITE_OF_CARE, COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS
FROM bucketed GROUP BY 1 ORDER BY PATIENTS DESC;

-- Q_ATC : one row per ATC parent account (this is the core deliverable). Sum of PATIENTS ~ 7,501.
SELECT HCO_PARENT_NAME AS ATC_ACCOUNT,
       COUNT(DISTINCT D_PATIENT_ID) AS PATIENTS,
       COUNT(DISTINCT PRIMARY_HCO_NPI_STATE) AS STATES,
       CASE WHEN COUNT_IF(CLASS_HYBRID = 'ATC: NPI confirmed') > 0 THEN 'NPI-confirmed'
            WHEN COUNT_IF(CLASS_HYBRID = 'ATC: roster gap corrected') > 0 THEN 'Roster-confirmed'
            ELSE 'Name-matched' END AS MATCH_BASIS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL
WHERE CLASS_FINAL = 'ATC'
GROUP BY 1 ORDER BY PATIENTS DESC;

-- Q_UNTAPPED : largest non-ATC accounts by region. Sum of PATIENTS ~ 8,745.
SELECT COALESCE(NULLIF(TRIM(a.HCO_PARENT_NAME),''),'Unknown / unmapped') AS ACCOUNT,
       r.REGION,
       COUNT(DISTINCT a.D_PATIENT_ID) AS PATIENTS
FROM COMPILE_DEV.PUBLIC.ATC_CLASSIFIED_FINAL a
LEFT JOIN COMPILE_DEV.PUBLIC.STATE_REGION_MAP r ON a.PRIMARY_HCO_NPI_STATE = r.STATE
WHERE a.CLASS_FINAL <> 'ATC'
GROUP BY 1, 2 ORDER BY PATIENTS DESC;
Step 2 — build the workbook, 4 tabs:

Summary — columns: Site of Care | Patients | % of total. Rows from Q_SUMMARY (ATC Network, Non-ATC: Hospital, Non-ATC: Community network, Non-ATC: Other) + a Total row using =SUM(). The % column is a formula (=Patients/Total), formatted 0.0%. Add a source line: "McKesson (Compile) medical claims, 2021–2025."
ATC accounts — columns: ATC Account (Parent) | Patients | States | Match basis | % of ATC. All rows from Q_ATC, sorted by Patients desc. "% of ATC" is a formula = Patients / the ATC total on the Summary tab, formatted 0.0%. Add a Total row (=SUM).
Untapped opportunity — columns: Non-ATC Account (Parent) | Region | Patients | % of non-ATC. All rows from Q_UNTAPPED. "% of non-ATC" = Patients / non-ATC total (Hospital+Community+Other from Summary), formatted 0.0%.
Methodology & sources — a two-column label/value sheet with: Data source (McKesson Compile claims, IOV2501_MEDICAL_CLAIMS); Time window (2021–2025); Population (metastatic melanoma on Yervoy or Opdualag); Total patients (16,246); ATC definition (site rolls up to an authorized ATC parent — matched by NPI, the roster, or HCO parent name where NPI is missing; includes satellites); Patient assignment (counted once, at the site with the most treatment claims); ATC share (~46%; a large share rests on name-matching — no fully updated ATC roster with NPIs yet — so counts flagged "Name-matched" are close estimates; the NPI/roster-confirmed floor is materially lower); Correction (Jul 2026: City of Hope, NYU Langone, Ohio State Wexner, Hoag reconciled into ATC). Paste the three queries above at the bottom as documentation.
Formatting: navy bold titles, green header row with white text, #,##0 for patient counts, 0.0% for percentages, thin borders on tables, gridlines off, sensible column widths. Only use Excel-2007-safe functions (SUM, division) — no XLOOKUP/UNIQUE/etc.

Verify: sum of Q_ATC ≈ 7,501 and ties to the Summary ATC row; sum of Q_UNTAPPED ≈ 8,745; grand total 16,246. Flag if anything doesn't reconcile.


Build a simple Excel workbook — three tabs, no charts, clean and plain. This is for my
manager: he asked for a row for each ATC with its patient count, plus a short note on the
data. Keep all wording plain and human, not marketing-speak. Don't invent numbers — take
them from my data.

I have the patient data (one row per patient) showing, for each patient: whether they were
treated at an ATC or not, the ATC / account name (parent), and their state.

Tab 1 — "ATC Patient Counts"
- One row per ATC (parent account) with the number of patients treated there, sorted most
  to fewest. Add a "% of ATC" column and a total row at the bottom.
- Small line at the top: "Metastatic melanoma patients on Yervoy or Opdualag — McKesson
  claims, 2021 to 2025."

Tab 2 — "Where the rest go (potential)"
- The largest non-ATC accounts — the places our patients go instead — one row each with the
  patient count. Top 20 is plenty, plus a total. This is the "potential at an ATC" the CEO
  asked about.

Tab 3 — "Data & method"  (plain bullet lines)
  • Data: McKesson (Compile) medical claims, 2021 to 2025.
  • Patients: metastatic melanoma treated with Yervoy or Opdualag — 16,246 in all.
  • What counts as an ATC: the site rolls up to its authorized parent, so satellites count
    too. We match on the provider NPI first, then the parent name, and count each patient
    once at the site where they had the most claims.
  • The split: 7,501 patients (about 46%) are treated in the ATC Network; the other 8,745
    are not.
  • One fix: City of Hope, NYU Langone, Ohio State (Wexner) and Hoag were missing from the
    roster and were added back — 566 patients.
  • How solid it is: a confirmed NPI is the firm floor; the rest is matched by parent name,
    which we keep because it catches the satellites.
  • Handle with care: these are counts by organization, not by patient — round or hold back
    anything under about 11 patients before it goes outside.

Formatting: Arial, bold header row, numbers right-aligned, thin borders, one clean table per
tab. Nothing fancy. If my data gives different totals, use those.





Hi Tim,

Yes, that segmentation is possible. Each claim carries the site level account under its parent, and the analysis already tags every ATC claim as either the primary authorized location or a satellite site that rolls up to the same parent. So for any parent ATC, the claims can be split into primary ATC versus ATC satellites.

This breakdown will be added per parent account in the next version of the workbook, alongside the roster update.

Thanks,
Srinidhi
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

Thank you for the workbook, it was exactly what was needed.

On the question: the original matching was done by account name from the claims data, so the unmatched sites were mostly those listed under a different health system parent name. The full list has now been reconciled against the roster.

Findings: 11 of the roster sites had patients classified as non-ATC, about 399 patients in total. The largest are Indiana University Health (188), Mayo Clinic (56), and Intermountain (55). Kaiser, Providence, and the Colorado Blood site matched at the system level only, and since only one location in each system is authorized, those are being split by site before counting. That could add up to 260 more patients.

With these corrections the ATC share moves from about 46% to roughly 48.5%, possibly closer to 50% once the site level check is complete.

The opposite direction was also verified: the largest non-ATC accounts, such as University of Michigan and Texas Oncology, are not on the roster and were classified correctly, so the remainder of the analysis holds.

The roster will be used as the source list going forward and all downstream outputs will be updated accordingly.

Thanks,
Srinidhi
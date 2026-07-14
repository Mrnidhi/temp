Context: This is my enrollment contest scorer. I want you to make it clean, reliable, and genuinely professional-looking — like a careful analyst built it, not AI. Make every change on this active sheet only; you may read from other tabs but never edit, rename, or reformat them. Work through the sections below, show me each change, and explain it in plain English. After each section, confirm the winners, side prizes, and payouts still recalculate.

SECTION A — Reliability and correctness

Guard every empty row. Wrap all calculated cells in each territory row so they return blank when the territory name is empty, e.g. =IF(TerritoryCell="","",<formula>). Empty rows must show nothing and be ignored by the PERCENTILE tier cutoffs and every SUMPRODUCT range. Confirm the tier cutoffs match the real (non-blank) territories only.
Protect against divide-by-zero. Any territory with a baseline of 0 (no history) must not error. Wrap % Growth in IFERROR so it returns blank, and flag that row "NO BASELINE" so I know it needs a flat target instead of growth scoring.
One side prize per group, with a real tiebreaker. Rank side-prize eligibility by pull-through, breaking ties first by raw TTP count, then by contest enrollments, and flag only rank 1 as "SIDE." A row flagged "CHECK" (bad TTP data) must be excluded from side-prize eligibility. Confirm no tier ends up with two side prizes.
Prevent a 3-way payout. Make the Place tiebreaker fully resolve (Final Score, then % growth, then contest enrollments) so no tier can ever mark more than 2 as PAID.
Keep pull-through capped at 100% and keep the CHECK flag for any row where TTPs exceed enrollments.
SECTION B — Make the open design choices safe and switchable (don't hard-lock them)
6. RAD budget. The RADs are marked PAID but have no money — the territory pot is fully spent. Add a separate "RAD prize pot" cell in settings and pay RAD 1st and 2nd from it, so RAD prizes never cannibalize the territory pot. Add a Payout column to the RAD table.
7. Side-prize metric toggle. In settings, add a labelled cell "Side prize basis" with two options — "conversion rate" or "pull-through count." Have the side-prize logic read that cell so I can switch the metric without rebuilding. Default it to "conversion rate."
8. Small-territory handling. Keep the "LOW BASE" flag, and add a settings note that flagged territories are pending a decision (flat target or merged tier). Don't change their scoring yet — just make them clearly visible with conditional formatting.

SECTION C — Humanize and polish (make it look real, not AI)
9. Fix all headers. No truncation — write full, clear headers in sentence case: "Growth rank", "Final score", "Pull-through %", etc.
10. Rewrite every note as a complete sentence. Remove the row-2 fragment and the broken notes block. Replace with a short, clean methodology note in full sentences covering baseline, tiers, scoring, side prize, and payout.
11. Consistent formatting. One decimal for enrollment counts, whole numbers for percentages, currency for payouts, and align numbers right. Use subtle conditional formatting: green for PAID, a soft highlight for SIDE, amber for CHECK and LOW BASE.
12. Add a clean header block: a title, a one-line "what this sheet does," a "Data as of [date]" cell, and a short "To run the live contest, update these cells" note listing the quarter columns, contest dates, and contest-enrollment source. Freeze the header rows and the Territory column so it scrolls cleanly.
13. Remove anything that isn't used — stray helper columns, leftover 0% rows, or filler text. Keep only what's needed to read and trust the sheet.

When you're done, give me a one-paragraph summary of what changed and confirm the whole sheet recalculates with no errors. Everything stays on this active sheet.


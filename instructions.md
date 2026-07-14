Context: This is my enrollment contest scorer. It works, but it has a few bugs and needs cleanup. Fix the items below on this active sheet only — you may read from the ATC Enrollments and ATC TTPs tabs, but do not edit, rename, or reformat any other tab. Show me each change and explain it in plain English.

Fix 1 — Pull-through can't exceed 100%. Right now some rows show pull-through over 100%, which is impossible (TTPs are a subset of enrollments). Change the Pull-through formula to cap at 100%: =IFERROR(MIN(TTP/Contest, 1), 0). Also add a small "Data check" column that flags "CHECK" whenever TTPs are greater than Contest enrollments, so bad source data is visible.

Fix 2 — Repair the RAD bucket ranks. In the RAD table, Vol Rank, Growth Rank, and Final Score all show 1.0 for every RAD — the formulas are broken. Rebuild them so they rank across all RADs as one group:

Vol Rank = =SUMPRODUCT((AllRAD_VolGrowth > thisVolGrowth)*1)+1
Growth Rank = =SUMPRODUCT((AllRAD_%Growth > this%Growth)*1)+1
Final Score = =AVERAGE(VolRank, GrowthRank)
Make sure the ranges cover only the RAD rows and use absolute references so they don't drift.
Fix 3 — Make the payout shares display honestly. The share cells show 17% and 7% but the payouts actually use 16.66% and 6.66%. Set the share cells to the true values (0.1666 and 0.0666) and format them to show two decimals, so what's displayed matches what's calculated. Confirm the three tiers still total 100% of the pot.

Fix 4 — Expand to 28 territories. There should be 28 territories, not 24. Add 4 more territory rows (leave the names and quarterly numbers blank for me to fill from the real roster), and extend every formula and every SUMPRODUCT/PERCENTILE range down so the whole table and the tier cutoffs correctly include all 28 rows.

Fix 5 — Flag the near-zero small territories. Add a "Baseline flag" column that marks "LOW BASE" for any territory whose baseline is below 3. Don't change how they're scored — just flag them, so I can see which territories are too small for percent-growth scoring to be reliable.

Fix 6 — Fix the test so the baseline doesn't overlap the contest window. For testing on the 2025 Aug–Sep window, the baseline quarters must end before that window. Set the trailing quarters to the four quarters immediately before the contest start, with no overlap, and update the settings note to show which quarters are used.

Fix 7 — Clean up the styling (make it look human, not AI-generated). Remove the "Formula / Block → Plain English" legend block with the half-sentence descriptions. Replace it with a short, clean 4-line note in plain English explaining baseline, tiers, scoring, and payout. Use sentence case headers, consistent number formats (one decimal for counts, whole numbers for percentages), and remove any filler text. Keep only what's needed to read and trust the sheet.

After each fix, tell me what changed and confirm the winners and payouts still recalculate correctly. Everything stays on this active sheet.
Context: My enrollment contest scorer works, but it has three issues to fix. Make all changes on this active sheet only — read from other tabs if needed, but don't edit, rename, or reformat any other tab. Show me each change and explain it.

Fix 1 — One side prize per tier (there's currently a tie). Capping pull-through at 100% made several territories tie at exactly 100%, so more than one is getting flagged "SIDE" in the same tier. Add a tiebreaker so only one wins per tier:

Create a side-prize rank: =SUMPRODUCT((TierCol=thisTier)*(ContestCol>=MinEnroll)*((PullCol>thisPull)+(PullCol=thisPull)*(TTPCol>thisTTP)))+1
This ranks eligible territories by pull-through, and breaks ties by the higher raw TTP count.
Then set Side Prize = =IF(AND(Contest>=MinEnroll, sidePrizeRank=1),"SIDE",""), so exactly one territory per tier is flagged. Confirm each tier ends up with only one side prize, and the payout total goes back to 100% of the pot.
Fix 2 — Stop the blank placeholder rows from distorting everything. The 4 empty rows I added toward 28 territories are being counted as size 0, which is dragging the tier percentile cutoffs down and adding phantom rows to the rankings. Fix this by wrapping every calculated cell in each territory row so it returns blank when the territory name is empty — for example Size = =IF(TerritoryCell="","",AVERAGE(quarters)), and the same guard on Baseline, Tier, growth, ranks, place, pull-through, side prize, and payout. Empty rows should show nothing and be ignored by the PERCENTILE cutoffs and all the SUMPRODUCT ranges. Confirm the Tier 2 cutoff goes back to what it was with only the 24 real territories.

Fix 3 — Rewrite the notes as real sentences. The notes block still has broken fragments ("contest window, averaged and scaled to two", "territories compete together"). Replace it with four clean, complete sentences in plain English:

Baseline: each territory's average quarterly enrollments over the trailing quarters, scaled to the two-month window.
Tiers: territories are split into three size groups so they only compete against similar-sized peers.
Scoring: ranked within their tier on volume growth and percent growth, averaged; the top two are paid.
Side prize: goes to the best enrollment-to-TTP pull-through in each tier, among territories that meet the minimum enrollment threshold.
After each fix, confirm the winners, side prizes, and payouts recalculate correctly. Everything stays on this active sheet.
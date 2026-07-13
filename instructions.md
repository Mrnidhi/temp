# Excel Copilot Prompts — Contest Scoring

Paste these into Excel's Copilot **with the Contest Scoring tab active**. Two prompts: the main scorer, then the RAD bucket. Feed steps one message at a time if Copilot stalls.

---

## PROMPT 1 — Main territory scorer

> **What this sheet is:** a sales enrollment contest scorer. It has one row per territory with quarterly enrollments, and I want to score each territory on growth over its own baseline, grouped into size tiers, plus a conversion side prize and a payout. There are other tabs in this workbook (ATC Enrollments, ATC TTPs, ATC Infusions) — you may **read** from them if a formula needs a number, but do **not** edit, rename, move, or reformat any tab other than this active one. Every change stays on this sheet, and add new columns to the right of what's already here so my current layout doesn't shift.
>
> Please do these in order, and show me each formula before applying it:
>
> **Step 1 — A small settings block.** In a few empty cells near the top, create these named inputs so every formula can reference them:
> - Total prize pot = 30000
> - Tier 1 cutoff = `=PERCENTILE(<the size column>,2/3)`
> - Tier 2 cutoff = `=PERCENTILE(<the size column>,1/3)`
> - Min enrollments for side prize = 5
> - 1st share = 0.1666, 2nd share = 0.10, side-prize share = 0.0666
> - Window scale = 0.6667  (a quarter is 3 months, the contest is 2)
>
> **Step 2 — Size and baseline.** Add a "Size" column = the average of each territory's quarterly enrollments. Then Baseline = `=ROUND(Size * WindowScale, 1)`. Baseline is each territory's 2-month target.
>
> **Step 3 — Tier.** `=IF(Size >= Tier1cutoff, "Tier 1", IF(Size >= Tier2cutoff, "Tier 2", "Tier 3"))`.
>
> **Step 4 — Growth.** Volume Growth = `Contest enrollments − Baseline`. % Growth = `(Contest − Baseline) / Baseline`.
>
> **Step 5 — The 50/50 rank (within each tier).**
> - Volume Rank = `=SUMPRODUCT((TierColumn=thisTier)*(VolGrowthColumn>thisVolGrowth))+1`
> - Growth Rank = `=SUMPRODUCT((TierColumn=thisTier)*(%GrowthColumn>this%Growth))+1`
> - Final Score = `=AVERAGE(VolumeRank, GrowthRank)`
> - Place = `=SUMPRODUCT((TierColumn=thisTier)*((ScoreColumn<thisScore)+(ScoreColumn=thisScore)*(%GrowthColumn>this%Growth)))+1`
> - Result = `=IF(Place<=2,"PAID","")`
>
> **Step 6 — Conversion side prize.** Read TTP counts from the ATC TTPs tab (read only). Pull-through % = `=IFERROR(TTP/Contest,0)`. Side Prize flag = `=IF(AND(Contest>=MinEnroll, PullThrough=MAXIFS(PullColumn, TierColumn, thisTier, ContestColumn, ">="&MinEnroll)),"SIDE","")`.
>
> **Step 7 — Payout.** `=IF(Place=1, 1stShare*Pot, IF(Place=2, 2ndShare*Pot, 0)) + IF(SidePrize="SIDE", SideShare*Pot, 0)`. Format as currency.
>
> Explain each formula in plain English as you go. **Reminder: only this active sheet gets changed — leave every other tab exactly as it is.**

---

## PROMPT 2 — RAD bucket (run after Prompt 1)

> On this **active sheet only**, add a small separate table below the territory table for the RAD bucket. Do not touch any other tab. The Regional Account Directors all compete as **one single group** — no tiers.
>
> Columns: RAD name, Baseline (2-mo), Contest Enroll, Volume Growth, % Growth, Vol Rank, Growth Rank, Final Score, Place, Result.
>
> - Volume Growth = `Contest − Baseline`; % Growth = `(Contest − Baseline)/Baseline`
> - Vol Rank = `=SUMPRODUCT((VolGrowthColumn>thisVolGrowth)*1)+1` (across all RADs, one group)
> - Growth Rank = `=SUMPRODUCT((%GrowthColumn>this%Growth)*1)+1`
> - Final Score = `=AVERAGE(VolRank, GrowthRank)`
> - Place = `=SUMPRODUCT((ScoreColumn<thisScore)+(ScoreColumn=thisScore)*(%GrowthColumn>this%Growth))+1`
> - Result = `=IF(Place<=2,"PAID","")`
>
> Show me each formula before applying. Keep everything on this active sheet.

---

## Notes
- Do Step 1 first, then feed steps 2–7 one at a time, each starting with "On this active sheet only," so the guardrail sticks.
- Swap the demo numbers for the real **ATC Enrollments** and **ATC TTPs**, and add the 4 missing territories to reach **28**.
- Change the **pot** cell and every payout re-flows — that's the "budget is a formula" point for Kolin.
- Reference build with all of this already wired up: `Contest Scoring - Reference Build.xlsx`.
# Prompt: update the Enrollment Contest Scorer

For the Claude add-in inside Excel. Open the workbook, make the **Enrollment
Contest Scorer** tab active, and paste everything below the line.

Save a backup copy of the workbook first.

---

You are updating the active sheet, the Enrollment Contest Scorer, in a live
Iovance workbook. Leadership has changed the contest rules and the scoring and
payout need to match.

**Ground rules.** Work on this active sheet only. There are other tabs in this
workbook. Read from them if a formula needs a value, but do not edit, rename,
move or delete any other tab. Do not insert or delete rows inside the territory
table, because that shifts every range and silently breaks the ranking
formulas. Add any new columns to the right of what is already there. Column C,
D and E hold the real quarterly enrollments and must not be altered.

## Before you change anything

Read the sheet and tell me what you find:

- Which row is the header row of the territory table, and which rows hold
  territory data.
- The column letter for each of: RAD, Territory, the three quarters, Size,
  Baseline (2-mo), Tier, Contest Enroll, Volume Growth, % Growth, Vol Rank,
  Growth Rank, Final Score, Place, Result, TTPs, Pull-through, Side Rank, Side
  Prize, Baseline flag, Payout.
- How many territories there are, and how many RADs are in the block below the
  territory table.
- Which cells hold the existing settings, and which cells nearby are free.

Everything below assumes the territory table runs rows 13 to 36 with columns A
through W in that order. If your sheet differs, use the real references and say
what you changed.

## The new rules

These are final. Apply them exactly. Do not add rules and do not leave any cell
reading "to confirm" or "pending".

- Each volume bucket pays three winners: 1st $7,000, 2nd $5,000, 3rd $3,000.
- Each volume bucket pays one $5,000 conversion kicker.
- One overall RAD bucket: 1st $10,000, 2nd $5,000, plus **one** $5,000
  conversion kicker across all RADs, not one per RAD.
- National bonus of $10,000 when total national contest enrollments **exceed**
  the sum of every territory baseline. Strictly greater than.
- Contest runs 15 August to 15 October 2026. For the conversion kicker the TTP
  must occur by 15 November 2026.
- Desert Plains moves to the medium bucket at leadership direction.
- A territory must finish **above** its baseline to take 1st, 2nd or 3rd. At or
  below the baseline is not a placement.

Superseded: the $30,000 pot, the 16.67 and 10.00 percent shares, the 6.67
percent side share, and paying only the top two.

## Step 1, settings

Put these in free cells near the existing settings block, each labelled, and
tell me where you put them:

Contest Start 2026-08-15, Contest End 2026-10-15, Conversion kicker TTP
deadline 2026-11-15, Territory 1st place 7000, Territory 2nd place 5000,
Territory 3rd place 3000, Territory conversion kicker 5000, RAD 1st place
10000, RAD 2nd place 5000, RAD conversion kicker 5000, National bonus 10000,
Must beat baseline to place TRUE, Desert Plains bucket "Tier 2".

The three dates must be real date cells with a date format, not text. Money
cells formatted as currency.

Update the existing Contest Start and Contest End to the new dates as well.

Rename the labels of the superseded pot and share cells to mark them
SUPERSEDED. Do not delete them until the end, when nothing errors.

Leave the tier cutoffs, the minimum enrollments for the kicker, and the
baseline logic note alone. Those were not changed.

## Step 2, Desert Plains

Force it rather than relying on the cutoff, so a data refresh cannot move it
back. Rewrite the Tier column, filled down:

```
=IF($B13="Desert Plains",<DesertPlainsCell>,IF($F13>=<Tier1Cutoff>,"Tier 1",IF($F13>=<Tier2Cutoff>,"Tier 2","Tier 3")))
```

Confirm Desert Plains now reads Tier 2.

## Step 3, three winners and the eligibility gate

Place, filled down. Column J is contest enrollments minus baseline, so
`$J13>0` is what makes the gate strictly greater than baseline:

```
=IF(NOT($J13>0),"",SUMPRODUCT(($H$13:$H$36=$H13)*($J$13:$J$36>0)*($N$13:$N$36<$N13))+SUMPRODUCT(($H$13:$H$36=$H13)*($J$13:$J$36>0)*($N$13:$N$36=$N13)*($K$13:$K$36>$K13))+SUMPRODUCT(($H$13:$H$36=$H13)*($J$13:$J$36>0)*($N$13:$N$36=$N13)*($K$13:$K$36=$K13)*(ROW($N$13:$N$36)<ROW()))+1)
```

Three parts: how many eligible territories in the same bucket scored better,
then ties broken on higher percent growth which is what the deck promises, then
sheet order so two identical rows cannot both claim a place.

Result:

```
=IF($O13="","Below baseline",IF($O13<=3,"Paid",""))
```

Payout:

```
=IF($O13="",0,IF($O13=1,<Terr1st>,IF($O13=2,<Terr2nd>,IF($O13=3,<Terr3rd>,0))))
```

## Step 4, conversion kicker tie-break

As written, two territories on an identical pull-through both rank 1 and both
get paid, paying the prize twice. Break on more TTPs, then sheet order.

Side Rank:

```
=IF($I13<<MinEnrol>,"",SUMPRODUCT(($H$13:$H$36=$H13)*($I$13:$I$36>=<MinEnrol>)*($R$13:$R$36>$R13))+SUMPRODUCT(($H$13:$H$36=$H13)*($I$13:$I$36>=<MinEnrol>)*($R$13:$R$36=$R13)*($Q$13:$Q$36>$Q13))+SUMPRODUCT(($H$13:$H$36=$H13)*($I$13:$I$36>=<MinEnrol>)*($R$13:$R$36=$R13)*($Q$13:$Q$36=$Q13)*(ROW($R$13:$R$36)<ROW()))+1)
```

Side Prize:

```
=IF($S13=1,<TerrKicker>,0)
```

Rename that header to "Conversion kicker" and the TTPs header to "Manual
entry: TTPs by 11/15/2026".

## Step 5, the TTP deadline

Check whether TTP dates exist per patient anywhere in the workbook, most likely
the ATC TTPs tab, and tell me what you find.

- If dated records exist, replace the manual TTP count with a COUNTIFS against
  that tab filtered to the territory and to a TTP date on or before the
  deadline cell. That makes the cut-off real.
- If they do not, leave it as manual entry and say so plainly. Do not make the
  sheet look like it enforces the deadline when it only holds a typed number.

## Step 6, RAD block

Add payout columns to the RAD table. The RADs are one group, no tiers.

- **Above baseline** = volume growth greater than zero.
- **Place** = blank if not above baseline, otherwise rank on final score across
  all eligible RADs, ties on higher percent growth, then sheet order. Same
  shape as the territory formula but with no bucket condition.
- **Place payout** = 1st gets the RAD 1st cell, 2nd the RAD 2nd cell, else 0.
- **TTPs** = sum of the TTPs of the territories rolling up to that RAD.
- **Pull-through** = TTPs over contest enrollments.
- **Kicker Rank** = rank pull-through across **all** RADs with enrollments above
  zero, ties on more TTPs then sheet order.
- **Conversion kicker** = the RAD kicker cell for rank 1 only.
- **Total** = place payout plus kicker.

## Step 7, national bonus

| Label | Formula |
|---|---|
| National baseline | `=SUMPRODUCT(ROUND($G$13:$G$36,0))` |
| Contest window, days | `=<ContestEnd>-<ContestStart>` |
| All contest enrollments | `=SUM($I$13:$I$36)` |
| Exceeds the national baseline | `=IF(<enrollments>><baseline>,"YES","NO")` |
| National bonus payable | `=IF(<exceeds>="YES",<NationalBonus>,0)` |

Strictly greater than. Equal does not pay. Rounding each baseline before
summing makes the sheet agree with the number printed on the deck.

## Step 8, payout summary

Territory places, territory conversion kickers, RAD places, RAD conversion
kicker, national bonus, and Total awarded as the sum of those five. Then:

```
Maximum possible payout = 3*(<Terr1st>+<Terr2nd>+<Terr3rd>)+3*<TerrKicker>+<RAD1st>+<RAD2nd>+<RADKicker>+<NationalBonus>
```

Tell me what it returns. It should be 90000. If not, a settings cell is wrong.

## Step 9, notes

Update the notes block to describe the current design: ranked within tier on
volume growth and percent growth, the two ranks averaged, top three paid, a
territory at or below its baseline cannot place, ties on higher percent growth.
Add notes for the RAD bucket and the national bonus.

## Now verify, and show me the result of each check

Do not tell me it is done until you have run these.

1. Desert Plains reads Tier 2.
2. Temporarily set every territory's Contest Enroll to reference its own
   Baseline cell exactly. Recalculate. Confirm zero placements and zero
   payouts, then undo. Use the baseline cell itself, not a rounded version, or
   a territory whose real baseline is 12.9 will look like a failure when you
   enter 13.
3. Enter a plausible set of contest enrollments and TTPs, then confirm: no tier
   pays more than three places; payouts are only 7000, 5000 or 3000; exactly
   one conversion kicker per tier; each kicker winner clears the minimum
   enrollments; no territory with volume growth at or below zero has a place or
   a payout; no duplicate place numbers within a tier.
4. The RAD block pays exactly two places, 10000 and 5000, and exactly one
   kicker of 5000 across the whole block.
5. Total awarded equals the sum of its five parts.
6. Maximum possible payout returns 90000.
7. No cell anywhere contains "TO CONFIRM", "top 10", "pending", "$30,000",
   "16.67" or "6.67".

Undo the test values before saving. Delete the superseded pot and share cells
once nothing errors.

## Flag these back to me, do not fix them

- The deck lists 28 territories. Count the rows here. If they differ, do not
  add or rename anything, just tell me the difference.
- Tell me how many RADs the sheet has and what they are called, and whether
  that matches the deck.

Do not touch the PowerPoint deck in this pass.

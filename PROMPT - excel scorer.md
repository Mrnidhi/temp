# Prompt: update the Enrollment Contest Scorer

Paste everything below to Claude on the machine that has the real workbook.

---

You are updating the `Enrollment Contest Scorer` tab of the live Iovance
enrollment contest workbook. Work on the real file. Save a backup copy first,
named with today's date, before changing anything.

Do not replace the real quarterly enrollment data. Columns C, D and E hold the
actual 4Q2025, 1Q2026 and 2Q2026 enrollments and they stay exactly as they are.
Everything below is about applying new rules to that data.

## Read the sheet first

Before writing a single formula, confirm the layout and tell me what you find:

- Which row is the header row of the territory table, and which rows hold
  territory data. Every formula below is written assuming the header is row 12
  and data runs 13 to 36. If your sheet differs, adjust every range
  consistently and say so.
- The column letter for each of: RAD, Territory, the three quarters, Size,
  Baseline (2-mo), Tier, Contest Enroll, Volume Growth, % Growth, Vol Rank,
  Growth Rank, Final Score, Place, Result, TTPs, Pull-through, Side Rank,
  Side Prize, Baseline flag, Payout. The instructions below assume A through W
  in that order.
- How many territories there are, and how many RADs are in the block below the
  territory table.

Do not insert or delete rows anywhere above the last territory row. Inserting a
row shifts every range and silently breaks the ranking formulas.

## What Kolin asked for

These came over Teams and are final. Apply them exactly. Do not add rules, do
not add "to confirm" or "pending" language, and do not leave any cell reading
TO CONFIRM when you are done.

- Each volume bucket pays three winners: 1st $7,000, 2nd $5,000, 3rd $3,000.
- Each volume bucket pays one $5,000 conversion kicker.
- One overall RAD bucket: 1st $10,000, 2nd $5,000, plus one $5,000 conversion
  kicker across all RADs, not one per RAD.
- National VP bonus of $10,000 when total national contest enrollments exceed
  the sum of every territory baseline. Strictly greater than, not greater than
  or equal to.
- Contest runs August 15 to October 15, 2026. For the conversion kicker the TTP
  must occur by November 15, 2026.
- Desert Plains moves to the medium bucket at leadership direction.
- A territory must finish above its baseline to take 1st, 2nd or 3rd. At or
  below the baseline is not a placement.

The old design is superseded: a $30,000 pot, 1st and 2nd share percentages of
16.67 and 10.00, a 6.67 side share, and paying only the top two.

## Step 1, parameters

The existing parameter block in rows 3 to 10 has no spare rows before the
header. Put the new payout parameters somewhere clearly outside the data, for
example in columns D and E alongside the existing block, or in an unused pair
of columns to the right of the last data column. Tell me where you put them.

Set up, as labelled cells:

| Parameter | Value |
|---|---|
| Contest Start | 2026-08-15 |
| Contest End | 2026-10-15 |
| Conversion kicker TTP deadline | 2026-11-15 |
| Territory 1st place | 7000 |
| Territory 2nd place | 5000 |
| Territory 3rd place | 3000 |
| Territory conversion kicker | 5000 |
| RAD 1st place | 10000 |
| RAD 2nd place | 5000 |
| RAD conversion kicker | 5000 |
| National bonus, VP option | 10000 |
| Must beat baseline to place | TRUE |
| Desert Plains bucket | Tier 2 |

The three dates must be real date cells with a date number format, not text, so
that date arithmetic works. Format the money cells as currency.

Update the existing Contest Start and Contest End cells to the new dates as
well, as real dates.

The old pot and share cells are superseded. Do not delete them yet or you may
break a formula still pointing at them. Rename their labels to mark them
superseded, finish every step below, confirm nothing errors, then remove them.

Leave the tier cutoffs, the minimum enrollments for the kicker, and the
baseline logic note alone. Those were not set by Kolin.

## Step 2, Desert Plains

Kolin moved it by hand, so force it rather than relying on the cutoff to put it
in the right place. Otherwise a data refresh can quietly move it back.

Rewrite the Tier column, filled down the whole territory range:

```
=IF($B13="Desert Plains",<DesertPlainsParam>,IF($F13>=<Tier1Cutoff>,"Tier 1",IF($F13>=<Tier2Cutoff>,"Tier 2","Tier 3")))
```

Then confirm Desert Plains reads Tier 2.

## Step 3, three winners and the eligibility gate

Two changes in one formula. Pay three instead of two, and blank the Place
entirely for any territory that did not finish above its baseline.

Place column, filled down. Replace 36 with your actual last data row:

```
=IF(NOT($J13>0),"",SUMPRODUCT(($H$13:$H$36=$H13)*($J$13:$J$36>0)*($N$13:$N$36<$N13))+SUMPRODUCT(($H$13:$H$36=$H13)*($J$13:$J$36>0)*($N$13:$N$36=$N13)*($K$13:$K$36>$K13))+SUMPRODUCT(($H$13:$H$36=$H13)*($J$13:$J$36>0)*($N$13:$N$36=$N13)*($K$13:$K$36=$K13)*(ROW($N$13:$N$36)<ROW()))+1)
```

Three parts. How many eligible territories in the same bucket scored better,
then ties broken on higher percent growth, which is the rule the deck states,
then sheet order so two identical rows can never both claim the same place.

Note that `$J13>0` is what makes the gate strictly greater than the baseline,
because column J is contest enrollments minus baseline. A territory landing
exactly on its baseline gets zero, which is not greater than zero, so it does
not place. That is the intended behaviour.

Result column:

```
=IF($O13="","Below baseline",IF($O13<=3,"Paid",""))
```

Payout column:

```
=IF($O13="",0,IF($O13=1,<Terr1st>,IF($O13=2,<Terr2nd>,IF($O13=3,<Terr3rd>,0))))
```

## Step 4, conversion kicker with a tie-break

The existing kicker mechanics stay: best enrollment-to-TTP pull-through in each
tier, among territories meeting the minimum enrollment. One change is needed.
As written, two territories on an identical pull-through would both be ranked 1
and both be paid, which would pay the prize twice. Break the tie on the higher
TTP count, then on sheet order.

Side Rank column, filled down:

```
=IF($I13<<MinEnrol>,"",SUMPRODUCT(($H$13:$H$36=$H13)*($I$13:$I$36>=<MinEnrol>)*($R$13:$R$36>$R13))+SUMPRODUCT(($H$13:$H$36=$H13)*($I$13:$I$36>=<MinEnrol>)*($R$13:$R$36=$R13)*($Q$13:$Q$36>$Q13))+SUMPRODUCT(($H$13:$H$36=$H13)*($I$13:$I$36>=<MinEnrol>)*($R$13:$R$36=$R13)*($Q$13:$Q$36=$Q13)*(ROW($R$13:$R$36)<ROW()))+1)
```

Side Prize column:

```
=IF($S13=1,<TerrKicker>,0)
```

Rename the Side Prize header to "Conversion kicker".

## Step 5, the TTP deadline

Rename the TTPs header to "Manual entry: TTPs by 11/15/2026".

Then check whether TTP dates exist per patient anywhere in the workbook, most
likely on the ATC TTPs tab. Tell me what you find.

- If dated records exist, replace the manual TTP count with a COUNTIFS against
  that tab, filtered to the territory and to a TTP date on or before the
  deadline parameter. That makes the November 15 cut-off real.
- If they do not exist, leave the column as a manual entry and say so plainly.
  Do not make the sheet look like it enforces the deadline when it only holds a
  number somebody typed.

## Step 6, the RAD block

The RAD block sits below the territory table. It currently ranks the RADs but
pays nothing. Add the payout columns.

- Keep the existing baseline, contest enrollments, volume growth, percent
  growth, and the two ranks. A RAD baseline is the sum of the baselines of the
  territories it covers, which is what the existing SUMIF does.
- Add an eligibility column using the same rule as the territories: volume
  growth greater than zero.
- Add a Place column that ranks on final score among eligible RADs, ties on
  higher percent growth, then sheet order. Same shape as the territory Place
  formula but over the RAD rows and with no bucket condition, because the RADs
  are one group.
- Add a Place payout column: 1st gets the RAD 1st parameter, 2nd gets the RAD
  2nd parameter, everything else zero.
- Add a TTPs column summing the territory TTPs for that RAD, and a pull-through
  column of TTPs over contest enrollments.
- Add a Kicker Rank column ranking pull-through across **all** RADs, not within
  any group, among RADs with contest enrollments above zero. Break ties on more
  TTPs then sheet order.
- Add a Conversion kicker column paying the RAD kicker parameter to rank 1 only,
  so exactly one kicker is paid across the whole block.
- Add a Total column of place payout plus kicker.

## Step 7, national bonus

Add a small block below the notes:

| Label | Formula |
|---|---|
| National baseline, all territories | `=SUMPRODUCT(ROUND($G$13:$G$36,0))` |
| Contest window, days | `=<ContestEnd>-<ContestStart>` |
| All contest enrollments | `=SUM($I$13:$I$36)` |
| Exceeds the national baseline | `=IF(<enrollments>><baseline>,"YES","NO")` |
| National bonus payable | `=IF(<exceeds>="YES",<NationalBonus>,0)` |

The comparison must be strictly greater than. Equal to the baseline does not
pay.

Rounding each baseline before summing gives the same total the deck prints, so
the sheet and the deck agree on the number leadership is being asked to beat.

## Step 8, payout summary

Add a block that shows what has actually been awarded:

- Territory places, summing the territory payout column
- Territory conversion kickers, summing the territory kicker column
- RAD places, summing the RAD place payout column
- RAD conversion kicker, summing the RAD kicker column
- National bonus
- Total awarded, summing those five

Then one more cell, Maximum possible payout:

```
=3*(<Terr1st>+<Terr2nd>+<Terr3rd>)+3*<TerrKicker>+<RAD1st>+<RAD2nd>+<RADKicker>+<NationalBonus>
```

That should return $90,000. If it does not, a parameter is wrong.

## Step 9, notes

Update the notes block so it describes the current design. It currently says
the top two are paid and describes a side prize. It should say that territories
are ranked within their tier on volume growth and percent growth, the two ranks
are averaged, the top three are paid, a territory finishing at or below its
baseline cannot place, and ties go to the higher percent growth. Add notes for
the RAD bucket and the national bonus.

## Verify, and show me the output of each check

1. Desert Plains reads Tier 2.
2. Set every territory's Contest Enroll temporarily to exactly its own baseline
   cell, recalculate, and confirm zero placements and zero payouts. This is the
   strictly-greater test. Do not use the rounded baseline for this, use the
   baseline cell itself, or a territory whose true baseline is 12.9 will look
   like a failure when enrolling 13 is genuinely above it. Undo afterwards.
3. Enter a plausible set of contest enrollments and TTPs, then confirm: no tier
   pays more than three places; payouts are only ever 7000, 5000 or 3000;
   exactly one conversion kicker per tier; every kicker winner has at least the
   minimum enrollments; no territory with volume growth at or below zero has a
   place or a payout; no duplicate place numbers inside a tier.
4. The RAD block pays exactly two places, 10000 and 5000, and exactly one
   kicker of 5000 across the whole block.
5. Total awarded equals the sum of its five parts.
6. Maximum possible payout returns 90000.
7. Search every cell for "TO CONFIRM", "to confirm", "top 10", "pending",
   "$30,000", "16.67" and "6.67". All must return nothing.
8. Confirm the workbook has no leftover demo, QA or superseded sheets visible.

Undo any temporary test values before saving.

## One thing to flag back to me, do not fix it yourself

The deck lists 28 territories. Check how many are in the sheet and whether the
names match the deck exactly. If they do not, stop and tell me the difference
rather than adding or renaming territories. The same applies to the RAD list:
tell me how many RADs the sheet has and what they are called.

Do not touch the PowerPoint deck in this pass.

# Prompt: rebuild the Enrollment Contest Scorer in Kolin's new workbook

For the Claude add-in inside Excel. Open Kolin's new workbook, make the
scorer tab the active sheet, and paste everything below the line.

Before you start, use File > Save As to keep a dated copy on disk. A hidden
backup tab is not a backup.

---

You are rebuilding the Enrollment Contest Scorer on the active sheet of a live
Iovance workbook. The headers, column layout and formatting were pasted in
from an older workbook, so the sheet looks right but the formulas did not
survive the paste. Your job is to make it compute.

**Do not assume any cell address in this prompt is correct.** Everything below
is written with placeholders in angle brackets. Read the sheet, work out the
real column letters and row numbers, substitute them, and tell me what you
substituted. The old workbook had a blank spacer column and an extra column
part way across, so guessing from the header order will be wrong.

**Ground rules.** Work on the active sheet only. Read other tabs if a formula
needs a value, but do not edit, rename, move or delete any other tab. Do not
insert or delete rows inside the territory table; that shifts every range and
breaks the ranking silently. Put any new column to the right of what exists.
The quarterly enrollment columns hold real data and must not be altered.

## Step 0, survey the sheet and stop

Do this first and report back before you change a single cell.

1. Which row is the header row of the territory table, and which rows hold
   territory data. Call these `<FIRST>` and `<LAST>`.
2. The column letter for each of: RAD, Territory, the three quarters, Size,
   Baseline, Tier, Contest Enroll, Volume Growth, Percent Growth, Volume Rank,
   Growth Rank, Final Score, Place, Result, TTPs, Pull-through, Side Rank,
   Conversion Kicker, Payout. Say which of these do not exist.
3. How many territories, and list their names.
4. Whether there is a RAD block below the table, how many rows, and the RAD
   names.
5. Which cells hold contest parameters (dates, tier cutoffs, minimum
   enrollments, payout amounts), and which cells near them are free.
6. Whether the workbook defines named ranges for per-patient TTP dates and
   order territory. In the old workbook these were `range_TTP_date` and
   `range_order_terr`. Say whether they exist here and what they point at.
7. Any cell in the computed columns currently showing `#REF!`, `#NAME?`,
   `#VALUE!` or a stale pasted constant.

Then clear the computed columns completely, values and broken formulas alike,
before rebuilding. Do not leave a pasted constant sitting where a formula
should be; it will look correct and never update.

### How to read the formulas below

Every formula is written for the **first** territory row and then filled down.
The dollar signs are load bearing:

- `$<Tier><FIRST>` is the current row. The row number is relative, so it moves
  as you fill down. This is the cell being scored.
- `$<Tier>$<FIRST>:$<Tier>$<LAST>` is the whole block, locked. It must not move
  when you fill down, or each row compares itself against a different set of
  rivals and the ranking quietly comes apart.

If you fill down and row two of the table references rows 4 to 15 instead of
3 to 14, the absolute markers were dropped. Check one filled row before you
carry on.

These formulas were tested end to end on a twelve territory sample with
deliberate ties, a territory sitting exactly on its baseline and a territory
under the enrollment floor, and they reproduced a hand-computed result exactly.
Type them as written and only change the column letters and row numbers.

## The rules to implement

These are final. Do not add rules, and do not leave any cell reading "to
confirm" or "pending".

- Territories are split into three volume buckets and ranked only inside their
  own bucket. Keep whatever column and cutoffs this sheet already uses to
  assign buckets. Do not change the basis or the thresholds.
- Rank on volume growth and on percent growth separately, average the two
  ranks, lowest score wins, ties go to the higher percent growth.
- A territory must finish **strictly above** its baseline to place. At or
  below the baseline is not a placement however it ranks.
- Each bucket pays 1st $7,000, 2nd $5,000, 3rd $3,000.
- Each bucket pays one $5,000 conversion kicker, to the best
  enrollment-to-TTP pull-through among territories meeting the minimum
  enrollment threshold. Ties go to the higher TTP count.
- RADs are one group with no bucket split: 1st $10,000, 2nd $5,000, plus
  **one** $5,000 conversion kicker across all RADs, not one per RAD. A RAD is
  measured against the combined baseline of the territories it covers.
- $10,000 national bonus when total national contest enrollments are
  **strictly greater** than the sum of every territory baseline.
- Contest runs 15 August to 15 October 2026. For the conversion kicker the TTP
  must occur by 15 November 2026.
- Desert Plains sits in the medium bucket at leadership direction.

Superseded, and must not appear anywhere: the $30,000 pot, the 16.67 and 10.00
percent shares, the 6.67 percent side share, and paying only the top two.

## Step 1, parameters

Put these in free cells near the existing parameter block, each labelled, and
tell me where you put them:

Contest Start 2026-08-15, Contest End 2026-10-15, Conversion kicker TTP
deadline 2026-11-15, Territory 1st place 7000, Territory 2nd place 5000,
Territory 3rd place 3000, Territory conversion kicker 5000, RAD 1st place
10000, RAD 2nd place 5000, RAD conversion kicker 5000, National bonus 10000,
Must beat baseline to place TRUE, Desert Plains bucket "Tier 2".

The three dates must be real date cells with a date number format, not text.
Money cells formatted as currency. If the sheet already has Contest Start and
Contest End, point them at the new date cells rather than leaving two copies.

If the tier cutoffs and the minimum enrollment threshold came across in the
paste, leave their values alone. If they did not, tell me and stop rather than
inventing numbers.

## Step 2, the bucket assignment

Force Desert Plains rather than relying on the cutoff, so a data refresh cannot
move it. Rewrite the Tier column and fill down:

```
=IF($<Terr><FIRST>="Desert Plains",<DesertPlainsCell>,IF($<Size><FIRST>>=<Tier1Cut>,"Tier 1",IF($<Size><FIRST>>=<Tier2Cut>,"Tier 2","Tier 3")))
```

Use whichever column the cutoffs are actually measured against on this sheet.
Confirm Desert Plains reads Tier 2 afterwards.

## Step 3, the growth measures

```
Volume growth   =<Enrol><FIRST>-<Base><FIRST>
Percent growth  =IF(<Base><FIRST>=0,"",<VolG><FIRST>/<Base><FIRST>)
```

Ranks are within the bucket, best first, real ties sharing a rank:

```
Volume rank =IF($<Enrol><FIRST>="","",SUMPRODUCT(($<Tier>$<FIRST>:$<Tier>$<LAST>=$<Tier><FIRST>)*($<VolG>$<FIRST>:$<VolG>$<LAST>>$<VolG><FIRST>))+1)
Growth rank =IF($<Enrol><FIRST>="","",SUMPRODUCT(($<Tier>$<FIRST>:$<Tier>$<LAST>=$<Tier><FIRST>)*($<PctG>$<FIRST>:$<PctG>$<LAST>>$<PctG><FIRST>))+1)
Final score =AVERAGE(<VRank><FIRST>,<GRank><FIRST>)
```

## Step 4, placement and the eligibility gate

Volume growth greater than zero is what makes the gate strictly above baseline.

```
=IF(NOT($<VolG><FIRST>>0),"",SUMPRODUCT(($<Tier>$<FIRST>:$<Tier>$<LAST>=$<Tier><FIRST>)*($<VolG>$<FIRST>:$<VolG>$<LAST>>0)*($<Score>$<FIRST>:$<Score>$<LAST><$<Score><FIRST>))+SUMPRODUCT(($<Tier>$<FIRST>:$<Tier>$<LAST>=$<Tier><FIRST>)*($<VolG>$<FIRST>:$<VolG>$<LAST>>0)*($<Score>$<FIRST>:$<Score>$<LAST>=$<Score><FIRST>)*($<PctG>$<FIRST>:$<PctG>$<LAST>>$<PctG><FIRST>))+SUMPRODUCT(($<Tier>$<FIRST>:$<Tier>$<LAST>=$<Tier><FIRST>)*($<VolG>$<FIRST>:$<VolG>$<LAST>>0)*($<Score>$<FIRST>:$<Score>$<LAST>=$<Score><FIRST>)*($<PctG>$<FIRST>:$<PctG>$<LAST>=$<PctG><FIRST>)*(ROW($<Score>$<FIRST>:$<Score>$<LAST>)<ROW()))+1)
```

Three parts: how many eligible territories in the same bucket scored better,
then ties broken on higher percent growth which is what the deck promises,
then sheet order so two identical rows cannot both claim the same place.

```
Result  =IF($<Place><FIRST>="","Below baseline",IF($<Place><FIRST><=3,"Paid",""))
Payout  =IF($<Place><FIRST>="",0,IF($<Place><FIRST>=1,<Terr1st>,IF($<Place><FIRST>=2,<Terr2nd>,IF($<Place><FIRST>=3,<Terr3rd>,0))))
```

## Step 5, TTPs and the conversion kicker

First establish where TTPs come from, and tell me which case applies.

- If the workbook has per-patient dated TTP records, count them with a COUNTIFS
  filtered to the territory and to a TTP date between the contest start and the
  kicker deadline. That makes the 15 November cut-off real.
- If it does not, leave TTPs as manual entry and say so plainly. Do not head
  the column as if a deadline is enforced when it only holds a typed number.

```
Pull-through =IF($<Enrol><FIRST>=0,"",$<TTPs><FIRST>/$<Enrol><FIRST>)
```

Do **not** cap this at 100 percent. If it comes out above 100 percent that is
a real signal, not a display problem, and I need to see it. Add a plain flag
column to the right that reads "over 100%" when pull-through exceeds 1, and
report how many rows trip it.

Rank the kicker within the bucket, ties on more TTPs, then sheet order:

```
=IF($<Enrol><FIRST><<MinEnrol>,"",SUMPRODUCT(($<Tier>$<FIRST>:$<Tier>$<LAST>=$<Tier><FIRST>)*($<Enrol>$<FIRST>:$<Enrol>$<LAST>>=<MinEnrol>)*($<Pull>$<FIRST>:$<Pull>$<LAST>>$<Pull><FIRST>))+SUMPRODUCT(($<Tier>$<FIRST>:$<Tier>$<LAST>=$<Tier><FIRST>)*($<Enrol>$<FIRST>:$<Enrol>$<LAST>>=<MinEnrol>)*($<Pull>$<FIRST>:$<Pull>$<LAST>=$<Pull><FIRST>)*($<TTPs>$<FIRST>:$<TTPs>$<LAST>>$<TTPs><FIRST>))+SUMPRODUCT(($<Tier>$<FIRST>:$<Tier>$<LAST>=$<Tier><FIRST>)*($<Enrol>$<FIRST>:$<Enrol>$<LAST>>=<MinEnrol>)*($<Pull>$<FIRST>:$<Pull>$<LAST>=$<Pull><FIRST>)*($<TTPs>$<FIRST>:$<TTPs>$<LAST>=$<TTPs><FIRST>)*(ROW($<Pull>$<FIRST>:$<Pull>$<LAST>)<ROW()))+1)
```

```
Conversion kicker =IF($<SideRank><FIRST>=1,<TerrKicker>,0)
```

Without the tie-break, two territories on an identical pull-through both rank
1 and the prize gets paid twice.

## Step 6, the RAD block

If the RAD block did not survive the paste, rebuild it below the territory
table with the same columns. RADs are one group with no bucket condition.

- **Baseline** = sum of the baselines of the territories rolling up to that RAD.
- **Contest enrollments, TTPs** = sums of the same territories.
- **Above baseline** = volume growth greater than zero.
- **Place** = blank if not above baseline, otherwise the same three-part rank
  as the territories but with the bucket condition removed.
- **Place payout** = 1st takes the RAD 1st cell, 2nd the RAD 2nd cell, else 0.
- **Pull-through** = TTPs over contest enrollments.
- **Kicker rank** = rank pull-through across all RADs with enrollments above
  zero, ties on more TTPs then sheet order.
- **Conversion kicker** = the RAD kicker cell for rank 1 only, so exactly one
  is paid across the whole block.
- **Total** = place payout plus kicker.

## Step 7, national bonus

| Label | Formula |
|---|---|
| National baseline | `=SUMPRODUCT(ROUND($<Base>$<FIRST>:$<Base>$<LAST>,0))` |
| Contest window, days | `=<ContestEnd>-<ContestStart>` |
| All contest enrollments | `=SUM($<Enrol>$<FIRST>:$<Enrol>$<LAST>)` |
| Exceeds the national baseline | `=IF(<enrollments>><baseline>,"YES","NO")` |
| National bonus payable | `=IF(<exceeds>="YES",<NationalBonus>,0)` |

Strictly greater than. Landing exactly on the baseline does not pay. Rounding
each baseline before summing is what makes the sheet agree with the number
printed on the deck.

## Step 8, payout summary

Territory places, territory conversion kickers, RAD places, RAD conversion
kicker, national bonus, and Total awarded as the sum of those five. Then:

```
Maximum possible payout = 3*(<Terr1st>+<Terr2nd>+<Terr3rd>)+3*<TerrKicker>+<RAD1st>+<RAD2nd>+<RADKicker>+<NationalBonus>
```

Tell me what it returns. It should be 90000. If it is not, a parameter cell is
wrong and I want to know which before you go any further.

## Step 9, notes

Write a notes block describing the design as built: ranked within bucket on
volume growth and percent growth, the two ranks averaged, top three paid, a
territory at or below its baseline cannot place, ties on higher percent growth.
Add notes for the conversion kicker, the RAD bucket and the national bonus.

## Now verify, and show me the result of every check

Do not tell me it is done until you have run all of these.

1. Desert Plains reads Tier 2.
2. Temporarily set every territory's Contest Enroll to reference its own
   Baseline cell exactly. Recalculate. Confirm zero placements and zero payouts,
   then undo. Reference the baseline cell itself, not a rounded version, or a
   territory whose true baseline is 12.9 will look like a failure when you type
   13.
3. Enter a plausible set of contest enrollments and TTPs, then confirm all of:
   no bucket pays more than three places; payouts are only 7000, 5000 or 3000;
   exactly one conversion kicker per bucket; each kicker winner clears the
   minimum enrollments; no territory with volume growth at or below zero holds
   a place or a payout; no duplicate place numbers inside a bucket.
4. The RAD block pays exactly two places, 10000 and 5000, and exactly one
   kicker of 5000 across the whole block.
5. Total awarded equals the sum of its five parts.
6. Maximum possible payout returns 90000.
7. No cell anywhere contains "TO CONFIRM", "top 10", "pending", "$30,000",
   "16.67" or "6.67".
8. No cell in the computed columns is a hardcoded number where a formula
   belongs. Say how you checked.
9. No formula points at a cell, range or defined name in the old workbook.
   Any external link is a paste artifact and has to go.

Undo the test values before saving, and confirm the enrollment and TTP columns
are back to whatever they were when you started.

## Flag these back to me, do not fix them

- Count the territories. The deck lists 28. If this sheet differs, do not add,
  remove or rename anything. Tell me the count and the names.
- Tell me how many RADs there are and what they are called.
- Tell me how many rows show pull-through above 100 percent, and the largest
  value. This happens when the TTP window reaches patients who enrolled before
  the contest opened, and it is an open question with leadership. Report it,
  do not correct it.
- If a whole bucket records zero TTPs, every pull-through ties at zero and the
  tie-break hands the kicker to the first row in sheet order. Tell me if that
  happens. Adding a minimum-TTP guard would be a new rule, so leave it.

Do not touch the PowerPoint deck in this pass.

# Enrollment Contest: Corrections to the Scoring Sheet

Apply these changes to the existing `Contest Scoring` sheet. Four problems need fixing. They are listed in the order they should be applied, because later steps depend on earlier ones.

---

## Problem 1: The baseline and the contest window are different lengths

The baseline is an average of a **3 month quarter**. The contest runs for **2 months**, August and September.

Right now the sheet subtracts a 3 month baseline from a 2 month result. Every territory will show negative growth even when they performed above their normal pace.

**Example.** A territory has a baseline of 12 per quarter, which is 4 per month. During the contest it enrolls 9 patients across 2 months, which is 4.5 per month, better than normal. The sheet calculates 9 minus 12 and reports -3, as though the territory declined.

**The fix.** Scale the baseline down to the length of the contest window before comparing.

Add a new column, `Adjusted Baseline`, immediately after `Baseline`. All growth calculations use the adjusted figure, never the raw quarterly one.

Do not round the adjusted baseline to a whole number. A territory with a baseline of 2 scales to 1.3, and rounding that to 1 would hand it an unfairly low bar. Keep one decimal place.

---

## Problem 2: Four territories are missing

The sheet contains 24 territories. There should be 28. The workbook's alignment data carries an older 24 territory mapping.

**The fix.** Reload the roll up using the current 28 territory alignment. Do not proceed past this step until the validation check for territory count passes. Every bucket boundary and every rank depends on the full set being present.

All cell ranges below assume 28 territories in rows 2 through 29. If only 24 are present, the ranges must read rows 2 through 25 instead, and the results should be treated as provisional.

---

## Problem 3: Territories of identical size are landing in different buckets

Buckets are currently assigned by forcing an equal count into each tier. The cutoff lands in the middle of a tie.

Two territories both have a baseline of 11. One sits in Tier 1, the other in Tier 2. The first now competes against a territory that does 18 a quarter, the second competes against much smaller ones. There is no defensible reason for the difference.

**The fix.** Stop assigning buckets by position in a sorted list. Assign them by baseline **value**, using two cutoff numbers. Any two territories with the same baseline then always land in the same bucket.

Accept that the groups will be uneven. Uneven groups are correct. Splitting a tie is not.

**Choosing the cutoffs.** Sort the baselines, look for the natural gaps in the numbers, and place the two cutoffs there. Never place a cutoff between two identical values. Aim for roughly a third of the territories in each tier, but let the ties win when the two goals conflict.

---

## Problem 4: Empty contest results are being scored

The `Contest Enrollments` column is empty because the contest has not run. The formulas are treating empty as zero, so every territory shows -100 percent growth, every growth rank shows 1, and the final scores and places are meaningless numbers that look real.

**The fix.** Every calculated column must return blank when `Contest Enrollments` is blank. Nothing downstream should display a value until real results exist.

---

## Parameters

Put these in cells `R1:S4` on the `Contest Scoring` sheet, so the settings are visible and changeable without editing formulas.

| Cell | Label | Value |
|---|---|---|
| R1 / S1 | Contest window, months | 2 |
| R2 / S2 | Baseline quarter, months | 3 |
| R3 / S3 | Tier 1 cutoff | set from the data |
| R4 / S4 | Tier 2 cutoff | set from the data |

A territory lands in Tier 1 if its baseline is greater than or equal to the Tier 1 cutoff. It lands in Tier 2 if its baseline is greater than or equal to the Tier 2 cutoff. Otherwise it lands in Tier 3.

---

## Corrected sheet layout

A new column is inserted at H. Everything from the old H onward shifts one to the right.

| Col | Field | Changed? |
|---|---|---|
| A | Territory | |
| B | Bucket | now formula driven |
| C | 3Q2025 enrollments | |
| D | 4Q2025 enrollments | |
| E | 1Q2026 enrollments | |
| F | 2Q2026 enrollments | |
| G | Baseline | |
| H | **Adjusted Baseline** | **new** |
| I | Contest Enrollments | |
| J | Volume Growth | now uses H |
| K | Percent Growth | now uses H |
| L | Volume Rank | now blank safe |
| M | Growth Rank | now blank safe |
| N | Final Score | now blank safe |
| O | Place | now blank safe |

---

## Corrected formulas

Enter in row 2, fill down to row 29.

**B2, Bucket, assigned by value so ties stay together**
```excel
=IF(G2>=$S$3,"Tier 1",IF(G2>=$S$4,"Tier 2","Tier 3"))
```

**G2, Baseline, unchanged**
```excel
=ROUNDUP(AVERAGE(C2:F2),0)
```

**H2, Adjusted Baseline, scaled to the contest window**
```excel
=ROUND(G2*$S$1/$S$2,1)
```

**J2, Volume Growth**
```excel
=IF(I2="","",I2-H2)
```

**K2, Percent Growth**
```excel
=IF(OR(I2="",H2=0),"",(I2-H2)/H2)
```

**L2, Volume Rank within bucket**
```excel
=IF(J2="","",SUMPRODUCT(($B$2:$B$29=B2)*($J$2:$J$29<>"")*($J$2:$J$29>J2))+1)
```

**M2, Growth Rank within bucket**
```excel
=IF(K2="","",SUMPRODUCT(($B$2:$B$29=B2)*($K$2:$K$29<>"")*($K$2:$K$29>K2))+1)
```

**N2, Final Score**
```excel
=IF(OR(L2="",M2=""),"",AVERAGE(L2,M2))
```

**O2, Place within bucket, with a three level tiebreaker**
```excel
=IF(N2="","",SUMPRODUCT(($B$2:$B$29=B2)*($N$2:$N$29<>"")*(($N$2:$N$29<N2)+($N$2:$N$29=N2)*($K$2:$K$29>K2)+($N$2:$N$29=N2)*($K$2:$K$29=K2)*($J$2:$J$29>J2)))+1)
```

The `<>""` term in each ranking formula excludes blank rows from the comparison. Without it, Excel treats an empty text value as larger than any number and the ranks come out wrong.

The place formula breaks ties in three stages. First on final score. If two territories are still level, the higher percent growth wins. If they are still level, the higher volume growth wins. If all three match, the two territories genuinely tie and share a place.

---

## Corrected validation checks

Replace the fixed expected values. Tier counts are no longer expected to be equal, because ties are no longer split.

| Check | Formula | Expected |
|---|---|---|
| Territories present | `=COUNTA(A2:A29)` | 28 |
| Blank buckets | `=COUNTBLANK(B2:B29)` | 0 |
| Baselines above zero | `=COUNTIF(G2:G29,">0")` | 28 |
| Adjusted baseline is smaller than baseline | `=SUMPRODUCT(--(H2:H29<G2:G29))` | 28 |
| Tier counts sum correctly | `=COUNTIF(B:B,"Tier 1")+COUNTIF(B:B,"Tier 2")+COUNTIF(B:B,"Tier 3")` | 28 |
| No baseline split across two tiers | `=SUMPRODUCT(--(COUNTIFS($G$2:$G$29,$G$2:$G$29,$B$2:$B$29,$B$2:$B$29)<>COUNTIF($G$2:$G$29,$G$2:$G$29)))` | 0 |

The last check is the important new one. It compares, for every territory, how many others share its baseline against how many share both its baseline and its bucket. If those two counts ever differ, a tie was split across a boundary and the bucket cutoffs need moving.

Tier counts should no longer be checked against 8. They will be uneven, and that is intended.

Once contest results are loaded, add back the two place checks: each bucket should contain exactly one Place 1 and one Place 2.

---

## One thing to verify in the source data

The roll up formula filters `Raw Data` on a flag column equal to 1. Confirm that this flag marks **one row per patient** and not one row per order.

A patient who enrolls, withdraws, then enrolls again produces two records. If the flag does not remove the duplicate, a territory can be credited twice for the same person. This is the single easiest way for the contest number to be inflated.

---

## Order of operations

1. Load the 28 territory alignment and confirm the territory count check passes
2. Rebuild the quarterly roll up so all 28 territories carry enrollment numbers
3. Set the two tier cutoffs from the new baselines, placing them at natural gaps rather than at fixed counts
4. Insert the Adjusted Baseline column and apply the scaling
5. Replace all formulas from column B and columns J through O
6. Rerun the validation table and confirm every check passes except the two place checks, which stay pending until the contest runs
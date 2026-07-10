# Building the Contest Sheet by Hand

You have the ten quarter columns and the Total. Everything from here is nine more columns.

Work through these in order. Each step has a check at the end. If the check fails, stop there rather than carrying on, because every column after it depends on the one before.

---

## Where things sit

| Col | What it holds |
|---|---|
| A | Territory |
| B | Bucket |
| C to L | 1Q2024 through 2Q2026, ten quarters |
| M | Total |
| N | Baseline |
| O | Adjusted Baseline |
| P | Contest Enrollments |
| Q | Volume Growth |
| R | Percent Growth |
| S | Volume Rank |
| T | Growth Rank |
| U | Final Score |
| V | Place |

Your data runs from row 2 to row 25. **Check that.** If your last territory is on a different row, replace every `25` below with your real last row.

**To fill a formula down:** click the cell, then double click the small square at the bottom right corner of the cell border. It fills to the bottom of the data.

---

## Step 0: Set up the parameters

These are four numbers the formulas will point at, so you can change them later without editing anything.

Type these into the cells shown.

| Cell | Type this |
|---|---|
| X1 | `Contest months` |
| Y1 | `2` |
| X2 | `Baseline months` |
| Y2 | `3` |
| X3 | `Tier 1 cutoff` |
| Y3 | `12` |
| X4 | `Tier 2 cutoff` |
| Y4 | `8` |

---

## Step 1: Baseline

This is what a normal quarter looks like for each territory right now.

In **N1**, type `Baseline`.

In **N2**, type:
```excel
=ROUNDUP(AVERAGE(I2:L2),0)
```

Fill down to N25.

**Look carefully at that formula.** It averages `I2:L2`, which is only the last four quarters. It does **not** average `C2:L2`. The six older quarters are on the sheet for the trend, and they stay out of the baseline. Four quarters is exactly one year, so every season is counted once. Stretch it wider and the average tilts toward whichever seasons got counted twice.

**Check:** your largest baseline should be 18 and your smallest should be 2. If the smallest is not 2, you have probably averaged too many columns.

---

## Step 2: Adjusted Baseline

The baseline is a three month quarter. The contest is only two months, August and September. Comparing them straight would make every territory look like it shrank.

In **O1**, type `Adjusted Baseline`.

In **O2**, type:
```excel
=ROUND(N2*$Y$1/$Y$2,1)
```

Fill down to O25.

The dollar signs matter. They stop the formula from sliding off the parameter cells as it fills down.

**Check:** a baseline of 18 should become 12.0. A baseline of 2 should become 1.3.

That 1.3 is why we keep a decimal. Rounding it to 1 would hand the smallest territory an unfairly low bar.

---

## Step 3: Buckets

Right now column B has the tiers typed in. Replace them with a formula, so two territories with the same baseline can never end up in different tiers.

In **B2**, type:
```excel
=IF(N2>=$Y$3,"Tier 1",IF(N2>=$Y$4,"Tier 2","Tier 3"))
```

Fill down to B25.

**Why 12 and 8.** Sort your baselines in your head from biggest down. Just above the first cutoff sits a 12, just below it sits an 11. Just above the second sits an 8, just below it a 7. Different numbers on each side, so no two territories with the same baseline get separated.

Never place a cutoff between two equal baselines. If you ever change these numbers, that is the one rule.

**Check:** count the tiers. You should get **7 in Tier 1, 8 in Tier 2, 9 in Tier 3.**

They are uneven, and that is correct. Forcing eight into each would split a tie.

---

## Step 4: Contest Enrollments

In **P1**, type `Contest Enrollments`.

**Leave P2 to P25 completely empty.** The contest has not happened. There is nothing to put there yet.

Every column you build after this will look blank. That is exactly what should happen, and Step 9 is where you prove it works.

---

## Step 5: The two growth numbers

Each territory gets both. Both compare against the **adjusted** baseline in column O, never the plain baseline in N.

In **Q1**, type `Volume Growth`. In **Q2**:
```excel
=IF(P2="","",P2-O2)
```

In **R1**, type `Percent Growth`. In **R2**:
```excel
=IF(OR(P2="",O2=0),"",(P2-O2)/O2)
```

Fill both down to row 25. Then select R2 to R25 and format it as a percentage.

**Why two numbers and not one.** A big territory going from 12 to 18 adds 6 real patients, which is 50 percent growth. A small one going from 1.3 to 3 adds under 2 patients, which is 131 percent growth. If you score on volume, the big one always wins. If you score on percent, the small one always wins for adding almost nothing. You need both.

**Check:** Q and R should both be completely blank, because P is empty.

---

## Step 6: Rank each territory twice

Each territory is only ever compared against others **in its own tier.** Never against all 24.

In **S1**, type `Volume Rank`. In **S2**:
```excel
=IF(Q2="","",SUMPRODUCT(($B$2:$B$25=B2)*($Q$2:$Q$25<>"")*($Q$2:$Q$25>Q2))+1)
```

In **T1**, type `Growth Rank`. In **T2**:
```excel
=IF(R2="","",SUMPRODUCT(($B$2:$B$25=B2)*($R$2:$R$25<>"")*($R$2:$R$25>R2))+1)
```

Fill both down.

Excel has no function that ranks within a group. This counts how many territories in the same tier beat you, then adds 1. So the best in each tier gets rank 1.

The `<>""` piece is not optional. Without it Excel treats an empty cell as bigger than any number, and every rank comes out wrong.

---

## Step 7: Blend the two ranks

In **U1**, type `Final Score`. In **U2**:
```excel
=IF(OR(S2="",T2=""),"",AVERAGE(S2,T2))
```

Fill down.

**Lowest score wins.** A territory that comes 1st on volume and 3rd on percent scores 2.0. A territory that comes 3rd on volume and 1st on percent also scores 2.0. They tie, and that is the entire point. Nobody wins on size alone.

---

## Step 8: Places

In **V1**, type `Place`. In **V2**:
```excel
=IF(U2="","",SUMPRODUCT(($B$2:$B$25=B2)*($U$2:$U$25<>"")*(($U$2:$U$25<U2)+($U$2:$U$25=U2)*($R$2:$R$25>R2)+($U$2:$U$25=U2)*($R$2:$R$25=R2)*($Q$2:$Q$25>Q2)))+1)
```

Fill down.

It is long because it breaks ties for you. First it compares final scores. If two territories are level, the one with higher percent growth places ahead. If they are still level, higher volume growth wins. You never have to make the call by hand.

Place 1 in each tier wins. Place 2 in each tier also gets paid. Six winners across three tiers.

---

## Step 9: Prove it works, then undo it

None of columns Q to V have ever actually run, because P is empty. Test them now, months before you need them.

1. Type made up numbers into **P2 down to P25.** Make some territories beat their adjusted baseline and some fall short. Anything plausible.

2. Now check all of this:

   * Every row shows a number in Q, R, S, T, U and V
   * No cell anywhere shows `#DIV/0!`
   * In each tier, exactly **one** territory has Place 1
   * In each tier, exactly **one** territory has Place 2
   * Somewhere in the sheet, a small territory that added **fewer** enrollments has placed **ahead** of a bigger one, because its percent growth was higher

3. That last one is the important one. If it never happens anywhere, the blend is not working and the contest is secretly just a volume contest.

4. **Now select P2 to P25 and delete it.** Leave the column empty.

Everything from Q to V goes blank again. That is correct, and it stays that way until the contest actually runs.

---

## Two things that are wrong with the data, and are not your fault

You will not fix either of these in Excel.

**Some enrollments have no territory.** In the raw data, some rows show `#N/A` where the territory should be. Those enrollments match no territory and are being left out of every baseline on this sheet. Worth finding out how many, and which centers they belong to.

**There is no patient identifier.** The raw data has an order id but nothing that identifies a person. A patient who enrolled, dropped out, and enrolled again is counted as two enrollments. So every number here counts orders, not patients. That needs a new field on the export.

---

## The one thing to never do

Do not use the Total column in M for anything.

It is there to show the trend. If you size or bucket territories by their ten quarter total, you rank people by what they did in 2024, back when there were fewer slots and a different roster. The baseline is what they do **now**, and that is what the buckets are built from.
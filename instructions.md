# Running the Contest on 2Q2026

Show what would have happened if the contest had run during 2Q2026. Real territories, real numbers, a real winner in each tier.

Once this works, moving to 3Q2026 is a two cell change.

---

## Fix two things first

The sheet as it stands has two problems. Both must be fixed before anything below will mean anything.

### Problem 1: the baseline is averaging all ten quarters

CT/NYC has a Total of 139 and a Baseline of 14. That is 139 divided by 10. Every row does the same thing.

The baseline is supposed to be a **normal quarter as things stand now**, not an average of the last two and a half years. Ten quarters reaches back to a smaller business with fewer slots and a different territory map.

### Problem 2: there is no Contest Enrollments column

Your columns run Adjusted Baseline, then straight into Volume Growth.

So Volume Growth is quietly calculating `Adjusted Baseline minus Baseline`. That is why CT/NYC reads -4.7, which is simply 9.3 minus 14.0. It is also why every Percent Growth on the sheet sits at about -33 percent. It is measuring the two thirds scaling against itself. It is not measuring performance at all.

You need a column holding **what each territory actually enrolled during the contest**, sitting between Adjusted Baseline and Volume Growth.

---

## What the demo is

* The contest period is **2Q2026**, which is column L
* The baseline is the **four quarters immediately before it**: `2Q2025`, `3Q2025`, `4Q2025`, `1Q2026`, which are columns **H through K**
* `2Q2026` must never appear in the baseline. It is the thing being measured

A full quarter is being compared against a quarterly baseline, so there is **no scaling**. Adjusted Baseline will equal Baseline.

That is correct, and it is worth pointing out when you present. The Adjusted Baseline column earns its keep later, when the real contest runs across two months instead of three.

---

## Step 1: Set the parameters

| Cell | Type this |
|---|---|
| X1 | `Contest months` |
| Y1 | `3` |
| X2 | `Baseline quarter months` |
| Y2 | `3` |
| X3 | `Tier 1 cutoff` |
| Y3 | leave empty for now |
| X4 | `Tier 2 cutoff` |
| Y4 | leave empty for now |

`Y1` is 3 because 2Q2026 is a three month quarter. When you move to the real contest in August and September, this becomes 2. Nothing else changes.

---

## Step 2: Fix the baseline

In **N2**:

```excel
=ROUNDUP(AVERAGE(H2:K2),0)
```

Fill down to N25.

`H` through `K` is `2Q2025`, `3Q2025`, `4Q2025`, `1Q2026`. Four quarters, one full year, ending right before the contest quarter.

**Do not include column L.** That is 2Q2026, the quarter you are measuring. If it goes into the baseline you are comparing 2Q2026 against a number that already contains 2Q2026, and every result becomes meaningless while still looking believable.

**Check:** CT/NYC should now show a baseline of **18**, not 14. San Diego/OC should show **3**, not 2.

---

## Step 3: Adjusted baseline

**O2** stays as it is:

```excel
=ROUND(N2*$Y$1/$Y$2,1)
```

**Check:** because `Y1` and `Y2` are both 3, column O should now be identical to column N. CT/NYC reads 18.0 in both.

That is the point. A full quarter needs no shrinking.

---

## Step 4: Insert the missing column

Right click on the **Volume Growth** column heading and choose **Insert**. A blank column appears between Adjusted Baseline and Volume Growth.

In the new **P1**, type `Contest Enrollments`.

In **P2**:

```excel
=L2
```

Fill down to P25.

That is it. Column L already holds each territory's 2Q2026 enrollments. You are simply pointing at it.

Your columns are now:

| Col | Field |
|---|---|
| N | Baseline |
| O | Adjusted Baseline |
| P | Contest Enrollments |
| Q | Volume Growth |
| R | Percent Growth |
| S | Volume Rank |
| T | Growth Rank |
| U | Final Score |
| V | Place |

Everything shifted one to the right. Excel updates the old formulas automatically, but check them anyway in the next step.

---

## Step 5: Rewrite the growth columns

These were pointing at the wrong cells. Retype both.

**Q2, Volume Growth.** How many extra enrollments, compared to a normal quarter.
```excel
=IF(P2="","",P2-O2)
```

**R2, Percent Growth.** How much better than normal, relative to their own size.
```excel
=IF(OR(P2="",O2=0),"",(P2-O2)/O2)
```

Fill both down. Format R as a percentage.

**Check:** the values should now be a mix of positive and negative. If everything is still around -33 percent, the formulas are still pointing at the old columns.

**Check:** CT/NYC enrolled 18 in 2Q2026 against a baseline of 18, so its volume growth is **0** and its percent growth is **0 percent**. Exactly average. San Diego/OC enrolled 0 against a baseline of 3, so **-3** and **-100 percent**.

---

## Step 6: Pick new cutoffs

Your baselines have all changed, so **12 and 8 no longer apply.** Those came from the old ten quarter average.

Copy column N into an empty area and sort it largest to smallest.

Look down the sorted list for two natural gaps, one roughly a third of the way down, one roughly two thirds. Put those two values in **Y3** and **Y4**.

**The one rule: never place a cutoff between two territories with the same baseline.** If the gap you want falls between two identical numbers, move the cutoff up or down until it sits between two different numbers.

Then in **B2**:
```excel
=IF(N2>=$Y$3,"Tier 1",IF(N2>=$Y$4,"Tier 2","Tier 3"))
```

Fill down. This replaces the typed in tiers.

**Check:** the three tiers will be uneven. That is correct.

---

## Step 7: The ranks and the winner

These columns already exist but now sit one letter further right. Retype them so the references are certain.

**S2, Volume Rank**
```excel
=IF(Q2="","",SUMPRODUCT(($B$2:$B$25=B2)*($Q$2:$Q$25<>"")*($Q$2:$Q$25>Q2))+1)
```

**T2, Growth Rank**
```excel
=IF(R2="","",SUMPRODUCT(($B$2:$B$25=B2)*($R$2:$R$25<>"")*($R$2:$R$25>R2))+1)
```

**U2, Final Score**
```excel
=IF(OR(S2="",T2=""),"",AVERAGE(S2,T2))
```

**V2, Place**
```excel
=IF(U2="","",SUMPRODUCT(($B$2:$B$25=B2)*($U$2:$U$25<>"")*(($U$2:$U$25<U2)+($U$2:$U$25=U2)*($R$2:$R$25>R2)+($U$2:$U$25=U2)*($R$2:$R$25=R2)*($Q$2:$Q$25>Q2)))+1)
```

Fill all four down.

Lowest Final Score wins. Place 1 in each tier is the winner. Place 2 also gets paid.

---

## Step 8: Check it before you show it

| Check | What you should see |
|---|---|
| Percent Growth is a spread of positive and negative | not all -33 percent |
| Column O equals column N | because Y1 and Y2 are both 3 |
| Each tier has exactly one Place 1 | three winners |
| Each tier has exactly one Place 2 | three runners up |
| No cell shows an error | no `#DIV/0!` |
| Somewhere, a smaller territory beat a bigger one on percent growth | this is the whole design working |

That last row is the one to hunt for. Find the example, write down both territory names and both sets of numbers. It is the most persuasive thing you can put in front of anyone, because it shows the fairness mechanism working on real data without you having to argue for it.

---

## Step 9: Moving to the real contest

Once this is signed off, the change to 3Q2026 is small.

1. Set **Y1** to `2`. The contest runs August and September, two months, so every adjusted baseline drops to two thirds of the baseline.
2. Change **N2** to `=ROUNDUP(AVERAGE(I2:L2),0)`, so the baseline becomes the four quarters ending 30 June 2026.
3. Change **P2** from `=L2` to a count of enrollments dated between 1 August and 30 September 2026:
```excel
=COUNTIFS('Raw Data'!$AO:$AO,$A2,'Raw Data'!$Y:$Y,">="&DATE(2026,8,1),'Raw Data'!$Y:$Y,"<="&DATE(2026,9,30),'Raw Data'!$AQ:$AQ,1)
```
4. Re-derive the cutoffs, because the baselines move again.

Nothing else changes. That is the point of building it this way.

---

## What to say when you present

**Lead with the mechanism.** Here is what each territory normally does in a quarter. Here is what they actually did in 2Q2026. Here is the growth, both in patients added and as a percentage. Here is how those two rank inside a size group, and here is the winner.

**Then show the example.** A small territory that added fewer patients than a large one, but placed ahead because it grew more against its own baseline. That is the fairness rule doing its job.

**Then say the caveats before he asks.**

1. This uses today's territory map applied to older enrollments. Territories have changed. So this proves the scoring, it is not a real leaderboard.
2. Every count is orders, not patients. There is no patient identifier in the data, so a patient who enrolled twice is counted twice.
3. Some enrollments have an unresolved territory and are excluded from every number here.
4. The workbook maps 24 territories. There should be 28.

The scoring engine is finished. What is left is two data fixes that belong to whoever owns the source file.
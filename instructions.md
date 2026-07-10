# Fixing the Sheet

Four changes. Do them in order. Expected results are at the bottom so you can check your work.

---

## Fix 1: The baseline

Right now the baseline averages all ten quarters. CT/NYC has a Total of 139 and a Baseline of 14, which is 139 divided by 10.

It should average the **four quarters before the contest quarter**: `2Q2025`, `3Q2025`, `4Q2025`, `1Q2026`. Those are columns **H, I, J, K**.

In **N2**:
```excel
=ROUNDUP(AVERAGE(H2:K2),0)
```
Fill down to N25.

Column L is `2Q2026`. That is the quarter you are measuring. It must never be in the baseline.

**Check:** CT/NYC changes from 14 to **18**. South FL changes from 12 to **13**.

---

## Fix 2: Turn off the scaling

The contest period is 2Q2026, a full three month quarter. There is nothing to shrink.

Change **Y1** from `2` to `3`.

**Check:** column O should now match column N exactly on every row. CT/NYC reads 18.0 in both.

Right now the bar is being lowered twice, once by averaging weak old quarters and again by taking two thirds of a full quarter. That is why nearly every territory is showing growth over 100 percent.

---

## Fix 3: The column heading

**P1** reads `3Q2026 - Contest`. The numbers in it are 2Q2026.

Rename it to `2Q2026 Contest`.

---

## Fix 4: New cutoffs

Every baseline just changed, so 12 and 8 are stale.

Set **Y3** to `11` and **Y4** to `8`.

Here is why. Sorted, the new baselines run:

```
18  13  12  12  11  11  11  10  10  9  8  8  8  8  6  6  6  6  5  4  3  3  2  2
```

A cutoff at 11 sits between 11 and 10. Two different numbers, so no tie is split.
A cutoff at 8 sits between 8 and 6. Two different numbers, so no tie is split.

That gives tiers of **7, 7 and 10**.

Tier 3 is large, and that is unavoidable. Four territories share a baseline of 6, so any attempt to cut through them would separate identical territories. Uneven tiers are the correct answer.

Then in **B2**:
```excel
=IF(N2>=$Y$3,"Tier 1",IF(N2>=$Y$4,"Tier 2","Tier 3"))
```
Fill down to B25.

---

## Fix 5: One validation row is now wrong

Row 36 reads `Adjusted baseline is smaller than baseline` and expects 24.

For this demo the adjusted baseline **equals** the baseline, because a full quarter needs no scaling. Change that row to:

`Adjusted baseline equals baseline`, expected **24**.

If it fails, `Y1` is still set to 2.

---

## What you should see when it is right

If your numbers do not match this table, something above is still wrong.

| Territory | Tier | Baseline | 2Q2026 | Volume Growth | Percent Growth |
|---|---|---|---|---|---|
| CT/NYC | 1 | 18 | 18 | 0 | 0.0% |
| South FL | 1 | 13 | 23 | +10 | 76.9% |
| Pittsburgh/Cleveland | 1 | 12 | 20 | +8 | 66.7% |
| Los Angeles | 1 | 12 | 17 | +5 | 41.7% |
| South TX/LA | 1 | 11 | 17 | +6 | 54.5% |
| Chicago/IN | 1 | 11 | 13 | +2 | 18.2% |
| Pacific Northwest | 1 | 11 | 9 | -2 | -18.2% |
| Mid-Atlantic | 2 | 10 | 18 | +8 | 80.0% |
| Rocky Mountains | 2 | 10 | 8 | -2 | -20.0% |
| New England | 2 | 9 | 9 | 0 | 0.0% |
| Philly | 2 | 8 | 13 | +5 | 62.5% |
| Great South | 2 | 8 | 15 | +7 | 87.5% |
| OH/MI | 2 | 8 | 13 | +5 | 62.5% |
| MN/WI | 2 | 8 | 12 | +4 | 50.0% |
| Desert Plains | 3 | 6 | 15 | +9 | 150.0% |
| Carolinas | 3 | 6 | 12 | +6 | 100.0% |
| IN/KY/Cincy | 3 | 6 | 7 | +1 | 16.7% |
| AR/MO/Tulsa | 3 | 6 | 3 | -3 | -50.0% |
| Northern Cal | 3 | 5 | 2 | -3 | -60.0% |
| Midwest | 3 | 4 | 2 | -2 | -50.0% |
| North FL/GA | 3 | 3 | 4 | +1 | 33.3% |
| San Diego/OC | 3 | 3 | 0 | -3 | -100.0% |
| North TX/OK | 3 | 2 | 5 | +3 | 150.0% |
| Northern NJ & NYC | 3 | 2 | 5 | +3 | 150.0% |

Notice CT/NYC lands on exactly zero. It enrolled 18 against a baseline of 18. That is a good sign, not a bug. It means the largest territory performed exactly at its own normal, which is what a baseline is supposed to detect.

---

## Your winners

| Tier | First | Second |
|---|---|---|
| Tier 1 | South FL | Pittsburgh/Cleveland |
| Tier 2 | **Great South** | Mid-Atlantic |
| Tier 3 | Desert Plains | North TX/OK and Northern NJ & NYC, tied |

---

## The example to show Kolin

**Tier 2 is the whole design working, on real data.**

Mid-Atlantic added **8** extra patients. Great South added **7**. Mid-Atlantic added more.

But Mid-Atlantic's normal quarter is 10, so 8 extra is 80 percent growth.
Great South's normal quarter is 8, so 7 extra is 87.5 percent growth.

Mid-Atlantic wins the volume rank. Great South wins the growth rank. Both score 1.5.

The tiebreaker goes to higher percent growth, so **Great South wins the tier despite adding fewer patients.**

That single comparison proves the contest does not simply reward whoever is bigger. Write down both names and all four numbers, and lead with it.

---

## A real problem the data just handed you

In Tier 3, **North TX/OK** and **Northern NJ & NYC** are identical.

Both have a baseline of 2. Both enrolled 5 in 2Q2026. Both grew by 3 patients and by 150 percent.

They tie on final score. They tie on percent growth. They tie on volume growth. Every tiebreaker in the sheet runs out, and they share second place.

This is not a bug. It is what happens with small territories and whole numbers, and it will happen again. Second place is a paid position, so somebody has to decide what happens when two territories are genuinely indistinguishable.

Take this to Kolin as a question. Split the prize, pay both, or add a further tiebreaker such as who reached TTP more often. It is his call, and finding it now rather than in October is exactly the kind of thing that makes the work look finished.

---

## Still outstanding, and not fixable here

* The workbook maps **24** territories. There should be 28.
* Some enrollment rows carry `#N/A` for territory and are excluded from every number above.
* There is no patient identifier, so all counts are orders, not patients.
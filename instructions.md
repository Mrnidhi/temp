# Testing the Contest on Last Year's Data

Run the contest as if it had happened in August and September 2025. Real numbers, real territories, real winners.

This proves the scoring works before anyone bets money on it.

---

## The idea

The real contest looks like this:

* Baseline built from the four quarters ending **30 June 2026**
* Contest runs **1 August to 30 September 2026**
* July sits in between, untouched

Shift the whole thing back exactly one year and you get:

* Baseline built from the four quarters ending **30 June 2025**
* Contest runs **1 August to 30 September 2025**
* July 2025 sits in between, untouched

Same shape, and the data already exists.

---

## The one rule that matters

**The baseline must not contain any part of the contest.**

`3Q2025` is July, August and September 2025. That quarter **contains the contest window.** If it goes into the baseline, you are measuring August and September against a number that already includes August and September. The result would be meaningless, and it would look plausible, which is worse.

So the backtest baseline uses `3Q2024`, `4Q2024`, `1Q2025` and `2Q2025`. Those are columns **E through H**. Nothing later.

---

## Step 1: Work on a copy

Right click the `Contest Scoring` tab, choose Move or Copy, tick Create a copy.

Rename the copy `Backtest 2025`.

Do everything below on the copy. Never touch the real sheet.

---

## Step 2: Change the baseline to the older four quarters

On the copy, in **N2**:

```excel
=ROUNDUP(AVERAGE(E2:H2),0)
```

Fill down.

That is `3Q2024`, `4Q2024`, `1Q2025`, `2Q2025`. Four quarters, one full year, ending before the contest starts.

**Check:** these baselines will be different from the ones on your live sheet. They should be. You are looking at an older, smaller version of the business.

---

## Step 3: Adjusted baseline stays the same

**O2** is unchanged:

```excel
=ROUND(N2*$Y$1/$Y$2,1)
```

Still two months over three, because the simulated contest is also two months.

---

## Step 4: Pick new cutoffs

**Do not reuse 12 and 8.** Those came from the 2026 baselines. Your 2025 baselines are different numbers, so the cutoffs move.

Copy column N somewhere empty and sort it largest to smallest. Look down the list for two natural gaps, roughly a third and two thirds of the way down.

The one rule: **never place a cutoff between two equal baselines.** If the gap you want falls between two territories with the same number, move the cutoff up or down until it lands between two different numbers.

Put the two values in **Y3** and **Y4**.

**Check:** count the tiers. They will be uneven. That is correct.

---

## Step 5: Fill in the contest column

This is the only place the year changes.

In **P2**:

```excel
=COUNTIFS('Raw Data'!$AO:$AO,$A2,'Raw Data'!$Y:$Y,">="&DATE(2025,8,1),'Raw Data'!$Y:$Y,"<="&DATE(2025,9,30),'Raw Data'!$AQ:$AQ,1)
```

Fill down.

Note the dates: **2025**, not 2026. Everything else is identical to the live sheet.

---

## Step 6: Everything else is already there

Columns Q through V need no changes. Volume growth, percent growth, both ranks, final score and place all work exactly as built.

The moment column P fills, the whole sheet comes alive.

---

## Step 7: Read the result

You now have, for the first time, real output.

Check these before you show anyone:

* Each tier has exactly one Place 1 and exactly one Place 2
* No cell shows an error
* **Somewhere, a smaller territory has beaten a bigger one because its percent growth was higher.** Find that example and write it down. It is the single most convincing thing you can show.
* Nobody with the biggest volume growth in a tier automatically took first place. If they always did, the blend is not working.

---

## Step 8: Test whether the answer is fragile

Change **Y1** from `2` to `3`, and change the end date in P2 from `DATE(2025,9,30)` to `DATE(2025,10,31)`. That simulates an August through October contest.

Do the winners change?

If they mostly stay the same, the design is robust and the two versus three month question does not matter much. If they change completely, that question matters a great deal and needs deciding before launch.

Either answer is useful. Change it back afterwards.

---

## What to say when you show it

Lead with what it proves, then get ahead of the caveats before they are asked.

**What it proves.** The mechanism works end to end on real data. It produces a clear, defensible winner in every tier. Small territories can and do beat large ones. There are no ties left unresolved and no errors.

**Say these out loud, unprompted.**

1. **These are not who would actually have won.** The 2025 enrollments are being sorted using **today's** territory map. Territories have changed since then, and the count went from 24 to 28. So a territory here is a set of centers as they are grouped now, not the patch any particular rep held in 2025. This shows the mechanism, not a real leaderboard.

2. **Every count is orders, not patients.** The data has an order id but no patient identifier, so a patient who enrolled twice is counted twice.

3. **Some enrollments are missing entirely.** Rows with an unresolved territory are excluded from every number here.

4. **Four territories are absent.** The workbook maps 24, not 28.

Saying these first is stronger than being asked. It is also the honest position: the scoring engine is finished and proven, and what remains is two data fixes that belong to whoever owns the source file.
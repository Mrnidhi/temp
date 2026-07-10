# Contest Scoring: Trend Adjusted Design

Two changes to how the bar is set. Both are supported by the ten quarters of data already in the workbook.

---

## Change 1: Stop rounding the baseline up

`ROUNDUP` raises the bar by 33.3 percent for San Diego/OC and North TX/OK, by 1.4 percent for CT/NYC, and by nothing at all for six territories that happen to land on whole numbers.

It taxes the smallest territories hardest, which is the opposite of what the tiers exist to do.

Removing it produces three benefits, all measured on your own data.

**Tiers become clean.** Unrounded baselines sorted:

```
17.75  12.5  12  11.5  11  11  10.5  10  9.75  8.75  8  7.5
7.25  7.25  6  6  5.75  5.5  4.25  3.5  3  2.25  1.75  1.5
```

Cutoffs at **10.0** and **6.0** give tiers of exactly **8, 8 and 8**, with **zero** baselines split across a boundary. Both territories on 7.25 sit together. Both on 6.0 sit together.

**The unresolvable tie disappears.** North TX/OK and Northern NJ & NYC both rounded to a baseline of 2 and tied on every tiebreaker. Unrounded they are 1.50 and 1.75, and the tie never occurs.

**Growth is measured precisely.** A territory averaging 12.5 is measured against 12.5.

---

## Change 2: Set the bar to what the territory would do anyway

The business is growing. Quarterly enrollments across all territories:

```
1Q2024   42   <- launch ramp, an outlier
2Q2024  144
3Q2024  159
4Q2024  137
1Q2025  177
2Q2025  161
3Q2025  175
4Q2025  180
1Q2026  221
2Q2026  260
```

From 2Q2024 to 1Q2026 that is **6.31 percent growth per quarter, compounding.**

A four quarter average sits about **2.5 quarters** behind the quarter it is meant to predict. At 6.31 percent compounding, that gap is worth **16.5 percent**.

So a plain four quarter average sets a bar that a territory clears by doing nothing at all. It rewards the tailwind, not the effort.

**Fix:** multiply the baseline by the growth the business is already producing.

```
Contest Target = Baseline  x  Trend Uplift  x  (Contest Months / 3)
```

The trend uplift is `(1 + quarterly growth) ^ 2.5`.

**This changes no winners.** Tested against 2Q2026, all six paid positions are identical with and without the adjustment. What it changes is the story: territories can no longer claim growth that the market handed them.

---

## Three rules this design depends on

**1. The target must be known before the contest opens.**

You cannot tell a rep in November what their August target was. The growth rate is therefore computed **only from quarters that finished before the contest starts**, then frozen. It is never recalculated using contest period data.

This also avoids a circularity. If the growth rate were computed from the contest quarter, a large territory's own performance would be inflating the bar it is being measured against.

**2. Tiers are locked before the contest and never recomputed.**

Slide the baseline window by a single quarter and 4 of 24 territories change tier. Tier assignment must be frozen at the same moment the targets are published.

**3. The launch quarter is excluded from the trend calculation.**

1Q2024 recorded 42 enrollments against 144 the following quarter. Including it would triple the apparent growth rate.

---

## Building it in Excel

### Step 1: Add a quarter totals row

In **C27**:
```excel
=SUM(C2:C25)
```
Fill across to **L27**.

Label **A27** as `Quarter total`.

### Step 2: Extend the parameter block

| Cell | Label | Value or formula |
|---|---|---|
| X1 | `Contest months` | `3` |
| X2 | `Baseline quarter months` | `3` |
| X3 | `Tier 1 cutoff` | `10` |
| X4 | `Tier 2 cutoff` | `6` |
| X5 | `Baseline lag, quarters` | `2.5` |
| X6 | `Quarterly growth` | `=(K27/D27)^(1/7)-1` |
| X7 | `Trend uplift` | `=(1+Y6)^Y5` |

Put each label in column X and each value in column Y.

`Y6` reads from **D27** (`2Q2024`) to **K27** (`1Q2026`). Seven steps. It deliberately skips **C27**, the launch quarter, and deliberately stops before **L27**, the contest quarter.

**Check:** `Y6` should read about **6.31%**. `Y7` should read about **1.1653**.

### Step 3: Baseline, unrounded

In **N2**:
```excel
=AVERAGE(H2:K2)
```
Fill down to N25.

No `ROUNDUP`. Format the column to two decimals.

**Check:** CT/NYC reads **17.75**. North TX/OK reads **1.50**.

### Step 4: Rename column O and rebuild it

Rename **O1** from `Adjusted Baseline` to `Contest Target`.

In **O2**:
```excel
=ROUND(N2*$Y$7*$Y$1/$Y$2,2)
```
Fill down to O25.

This applies both adjustments at once: the trend uplift, and the shortening of the window if the contest runs fewer than three months. For this demo `Y1` is 3, so the window factor is 1 and only the trend applies.

**Check:** CT/NYC reads **20.68**. South FL reads **14.57**.

### Step 5: New cutoffs

Set **Y3** to `10` and **Y4** to `6`.

In **B2**:
```excel
=IF(N2>=$Y$3,"Tier 1",IF(N2>=$Y$4,"Tier 2","Tier 3"))
```
Fill down.

**Check:** tiers come out **8, 8, 8**.

### Step 6: Everything downstream is unchanged

Volume Growth, Percent Growth, both ranks, Final Score and Place all point at column O, which still holds the bar. Nothing needs retyping.

---

## What you should see

| Tier | First | Second |
|---|---|---|
| Tier 1 | South FL | Mid-Atlantic |
| Tier 2 | Desert Plains | Great South |
| Tier 3 | North TX/OK | Carolinas |

Identical with or without the trend adjustment. That is the point.

**CT/NYC is the one to look at.** Against a plain baseline it grew 1.4 percent and looked fine. Against a target that expects the market's own growth, it is at **-13.0 percent**. It grew, but slower than the business around it. That is exactly the distinction the adjustment exists to draw.

---

## The example to show Kolin

**Tier 1. Pittsburgh/Cleveland added more patients and still lost.**

| | Target | Enrolled | Added | Growth |
|---|---|---|---|---|
| Pittsburgh/Cleveland | 13.40 | 20 | +6.60 | +49.2% |
| Mid-Atlantic | 11.65 | 18 | +6.35 | +54.5% |

Pittsburgh added more patients, so it wins the volume rank. Mid-Atlantic grew a larger share of its own target, so it wins the growth rank. Both score 2.5. The tiebreaker goes to percent growth, and **Mid-Atlantic takes second place with fewer patients added.**

Neither territory can win on size alone. That is the entire design, on real data, in four numbers.

---

## Validation

| Check | Formula | Expected |
|---|---|---|
| Baseline is unrounded | `=SUMPRODUCT(--(N2:N25<>ROUND(N2:N25,0)))` | above 0 |
| Baseline matches a fresh average | `=SUMPRODUCT(--(ROUND(N2:N25,4)<>ROUND((H2:H25+I2:I25+J2:J25+K2:K25)/4,4)))` | 0 |
| Target above baseline while uplift exceeds 1 | `=SUMPRODUCT(--(O2:O25>N2:N25))` | 24 |
| Growth rate excludes the launch quarter | inspect `Y6` | reads D27, not C27 |
| Growth rate excludes the contest quarter | inspect `Y6` | stops at K27, not L27 |
| Tier counts | `=COUNTIF(B:B,"Tier 1")` and so on | 8, 8, 8 |
| No baseline split across tiers | `=SUMPRODUCT(--(COUNTIFS($N$2:$N$25,$N$2:$N$25,$B$2:$B$25,$B$2:$B$25)<>COUNTIF($N$2:$N$25,$N$2:$N$25)))` | 0 |
| One first place per tier | `=COUNTIFS(B:B,"Tier 1",W:W,1)` and so on | 1 each |
| No formula errors | `=SUMPRODUCT(--ISERROR(N2:W25))` | 0 |

---

## Be honest about what this does not fix

**2Q2026 was an exceptional quarter, not just a trending one.** The plain baseline understates it by 41 percent. The trend adjusted target still understates it by 21 percent. The adjustment removes the predictable part of the growth, not a genuine surge. Sixteen of twenty four territories still beat the adjusted target.

**Tier 3 is still decided by very few patients.** North TX/OK wins on a target of 1.75 and five enrollments. One patient is worth 57 percent growth to that territory and 5 percent to CT/NYC. Volatility for territories below a baseline of 5 is three times that of territories above 8.

No arithmetic fixes this. It is a property of small numbers. Either merge Tier 2 and Tier 3, or give the smallest territories a fixed target instead of a rank. That is a decision for Kolin, and it is better raised with these numbers than discovered in October.

**Every count is orders, not patients.** There is still no patient identifier in the source data.

---

## When the real contest runs

Three changes and nothing else.

1. `Y1` becomes `2`, because August and September are two months. The window factor drops the target to two thirds.
2. `N2` becomes `=AVERAGE(I2:L2)`, the four quarters ending 30 June 2026.
3. `Y6` extends one quarter to `=(L27/D27)^(1/8)-1`, since 2Q2026 has now finished and is no longer the contest quarter.

Then recompute the cutoffs, publish the targets, and freeze everything before 1 August.
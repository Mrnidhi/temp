# Enrollment Contest: Complete Formula Guide

Every formula for the Contest Scoring sheet, in order, matching the final column layout. Contest quarter is **2Q2026**.

Assumptions: 24 territories in **rows 2 to 25**, Total in row 26, header in row 1.

---

## If you are seeing #NAME? errors

`#NAME?` in the Bucket column means Excel does not recognise `Tier1_Cutoff` or `Tier2_Cutoff`, because those named cells have not been created yet. The Rank, Score and Place columns then inherit the error because they read from Bucket.

Do **Step 1** below first. Creating the two names clears every `#NAME?` on the sheet at once.

---

## Final column layout

| Col | Header | Type |
|---|---|---|
| A | Territory | text |
| B | Bucket | formula |
| C–L | 1Q2024 … 2Q2026 | your quarterly data |
| M | Total | formula |
| N | Baseline | formula |
| O | Contest metric | formula (2Q2026 enrolled) |
| P | Volume Growth | formula |
| Q | Percent Growth | formula |
| R | Volume Rank | formula |
| S | Growth Rank | formula |
| T | Final Score | formula |
| U | Place | formula |
| V | Result | formula (optional) |

---

## Step 1: Parameters box (do this first)

Cutoff values do not belong inside formulas. Put them in labelled cells so there is one place to change them and the formula reads in plain words.

In an empty area, for example starting at **X1**:

| Cell | Content |
|---|---|
| X1 | `Parameter` |
| Y1 | `Value` |
| X2 | `Tier 1 cutoff (baseline >=)` |
| Y2 | `10` |
| X3 | `Tier 2 cutoff (baseline >=)` |
| Y3 | `6` |

Then name the two value cells:

1. Click **Y2**, click the Name Box (far left of the formula bar, next to the formula), type `Tier1_Cutoff`, press Enter.
2. Click **Y3**, click the Name Box, type `Tier2_Cutoff`, press Enter.

Names cannot contain spaces, hence the underscore. Once these exist, the Bucket column stops showing `#NAME?`.

---

## Step 2: The formulas

Type each into **row 2**, press Enter, then double-click the small square at the cell's bottom-right corner to fill down to row 25.

**B2 — Bucket.** Which size group the territory competes in.
```
=IF(N2>=Tier1_Cutoff,"Tier 1",IF(N2>=Tier2_Cutoff,"Tier 2","Tier 3"))
```

**M2 — Total.** All ten quarters, for reference only.
```
=SUM(C2:L2)
```

**N2 — Baseline.** A normal quarter, the average of the four quarters before the contest: 2Q2025, 3Q2025, 4Q2025, 1Q2026 (columns H to K).
```
=AVERAGE(H2:K2)
```

**O2 — Contest metric.** What the territory enrolled in the contest quarter, 2Q2026 (column L).
```
=L2
```

**P2 — Volume Growth.** Extra enrollments over a normal quarter.
```
=O2-N2
```

**Q2 — Percent Growth.** The same gain as a share of the territory's own size. Format this column as a percentage.
```
=(O2-N2)/N2
```

**R2 — Volume Rank.** Rank on patients added, within the group only. 1 is best.
```
=SUMPRODUCT(($B$2:$B$25=B2)*($P$2:$P$25>P2))+1
```

**S2 — Growth Rank.** Rank on percent growth, within the group only. 1 is best.
```
=SUMPRODUCT(($B$2:$B$25=B2)*($Q$2:$Q$25>Q2))+1
```

**T2 — Final Score.** The two ranks weighted equally.
```
=AVERAGE(R2,S2)
```

**U2 — Place.** Position within the group. Lowest final score wins; ties break on higher percent growth.
```
=SUMPRODUCT(($B$2:$B$25=B2)*(($T$2:$T$25<T2)+($T$2:$T$25=T2)*($Q$2:$Q$25>Q2)))+1
```

**V2 — Result (optional).** Flags the paid positions, top 2 per group.
```
=IF(U2<=2,"PAID","")
```

---

## Step 3: Formatting

- **Q2:Q25** → click the `%` button so growth shows as percentages.
- **N2:N25** → 2 decimals, so baselines read cleanly.
- Widen column **U** if Place shows `####`; that just means the column is too narrow, it is not an error.
- Winners: six rows will show 1 or 2 in Place. Fill Place-1 rows gold and Place-2 rows grey by hand. They are South FL, Mid-Atlantic, Desert Plains, Great South, North TX/OK, Carolinas.

---

## Why the cutoffs are 10 and 6

Not arbitrary, and worth being able to explain. Sort the 24 baselines largest to smallest:

```
17.75  12.5  12  11.5  11  11  10.5  10 | 9.75  8.75  8  7.5  7.25  7.25  6  6 | 5.75  5.5  4.25  3.5  3  2.25  1.75  1.5
```

Three groups of eight put the boundaries after the 8th and 16th values.

- 8th value is **10**, 9th is 9.75, so Tier 1 cutoff is **10**.
- 16th value is **6**, 17th is 5.75, so Tier 2 cutoff is **6**.

Both boundaries fall between two **different** numbers. That is the point: if a cutoff split two territories with the same baseline, two identical territories would land in different tiers, which cannot be defended to the rep who loses. Both 6.0 territories stay in Tier 2; the 5.75 sits just below in Tier 3.

Drop a note under the parameters box so the reasoning lives on the sheet:

> Cutoffs set at the natural gaps in the sorted baselines (10 / 6), giving 8 / 8 / 8 with no equal baselines split across a boundary.

---

## When the real contest runs

The baseline window moves, so the numbers shift but the method does not.

1. Change **N2** to `=AVERAGE(I2:L2)`, the four quarters ending 30 June 2026.
2. Change **O2** to a count of enrollments dated 1 Aug to 30 Sep 2026 from the raw data, not `=L2`.
3. Re-sort the new baselines, find the two natural gaps, and type the new cutoffs into **Y2** and **Y3**. Never place a cutoff between two equal baselines.

Only these three inputs change. Every formula stays exactly as written, because the cutoffs live in named cells and the ranks read from whatever the columns hold.

---

## Check it worked

- No `#NAME?` or `#REF!` anywhere
- Bucket reads Tier 1 / 2 / 3, roughly 8 each
- Percent Growth is a spread of positive and negative, not all the same value
- Each tier has exactly one `1` and one `2` in Place
- Exactly six rows show PAID
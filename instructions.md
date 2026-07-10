# Enrollment Contest: Complete Formula Guide

Every formula for the Contest Scoring sheet, in order. Contest quarter is **2Q2026**.

Assumptions: 24 territories in **rows 2 to 25**, Total in row 26, header in row 1. If your first territory is on a different row, shift the numbers to match.

---

## Column layout

| Col | Header | Type |
|---|---|---|
| A | Territory | text |
| B | Bucket | formula |
| C–L | 1Q2024 … 2Q2026 | your quarterly data |
| M | Total | formula |
| N | Baseline | formula |
| O | Adjusted Baseline | hide it, see note |
| P | 2Q2026 Enrolled | formula |
| Q | Volume Growth | formula |
| R | Percent Growth | formula |
| S | Volume Rank | formula |
| T | Growth Rank | formula |
| U | Final Score | formula |
| V | Place | formula |
| W | Result | formula |

**Column O:** for a full-quarter demo there is nothing to scale, so the adjusted baseline equals the baseline and adds nothing. Right-click the O header and choose Hide. Do not delete it, deleting shifts every column left and breaks references.

---

## Step 1: Parameters box (do this first)

Cutoff values do not belong inside formulas. Put them in labelled cells so there is one place to change them and the formula reads in plain words.

In an empty area, for example starting at **Y1**:

| Cell | Content |
|---|---|
| Y1 | `Parameter` |
| Z1 | `Value` |
| Y2 | `Tier 1 cutoff (baseline >=)` |
| Z2 | `10` |
| Y3 | `Tier 2 cutoff (baseline >=)` |
| Z3 | `6` |

Then name the two value cells:

1. Click **Z2**, click the Name Box (far left of the formula bar), type `Tier1_Cutoff`, press Enter.
2. Click **Z3**, click the Name Box, type `Tier2_Cutoff`, press Enter.

Names cannot contain spaces, hence the underscore.

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

**N2 — Baseline.** A normal quarter, taken as the average of the four quarters before the contest: 2Q2025, 3Q2025, 4Q2025, 1Q2026 (columns H to K).
```
=AVERAGE(H2:K2)
```

**P2 — 2Q2026 Enrolled.** What the territory actually enrolled in the contest quarter (column L). Rename the header to `2Q2026 Enrolled` first.
```
=L2
```

**Q2 — Volume Growth.** Extra enrollments over a normal quarter.
```
=P2-N2
```

**R2 — Percent Growth.** The same gain as a share of the territory's own size. Format this column as a percentage.
```
=(P2-N2)/N2
```

**S2 — Volume Rank.** Rank on patients added, within the group only. 1 is best.
```
=SUMPRODUCT(($B$2:$B$25=B2)*($Q$2:$Q$25>Q2))+1
```

**T2 — Growth Rank.** Rank on percent growth, within the group only. 1 is best.
```
=SUMPRODUCT(($B$2:$B$25=B2)*($R$2:$R$25>R2))+1
```

**U2 — Final Score.** The two ranks weighted equally.
```
=AVERAGE(S2,T2)
```

**V2 — Place.** Position within the group. Lowest final score wins; ties break on higher percent growth.
```
=SUMPRODUCT(($B$2:$B$25=B2)*(($U$2:$U$25<U2)+($U$2:$U$25=U2)*($R$2:$R$25>R2)))+1
```

**W2 — Result.** Flags the paid positions, top 2 per group.
```
=IF(V2<=2,"PAID","")
```

---

## Step 3: Formatting

- **R2:R25** → click the `%` button so growth shows as percentages.
- **N2:N25** → 2 decimals, so baselines read cleanly.
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
2. Change **P2** to a count of enrollments dated 1 Aug to 30 Sep 2026 from the raw data, not `=L2`.
3. Re-sort the new baselines, find the two natural gaps, and type the new cutoffs into **Z2** and **Z3**. Never place a cutoff between two equal baselines.

Only three inputs change. Every formula stays exactly as written, because the cutoffs live in named cells and the ranks read from whatever the columns hold.

---

## Check it worked

- No `#REF!` anywhere (hide column O if needed)
- Bucket reads Tier 1 / 2 / 3, roughly 8 each
- Percent Growth is a spread of positive and negative, not all the same value
- Each tier has exactly one `1` and one `2` in Place
- Exactly six rows show PAID
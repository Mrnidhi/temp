# Enrollment Contest: Self-Updating Formula Guide

A version that maintains itself. Each quarter you add one new column of enrollments, and the baseline, buckets and winners all recompute on their own. Built to run every quarter for years without editing a formula.

Assumptions: 24 territories in **rows 2 to 25**, header in row 1, quarter columns starting at **C** and free to grow rightward toward column Z.

---

## The three things that now calculate themselves

1. **Baseline window slides.** It always averages the four quarters immediately before the most recent one, so you never re-edit the range.
2. **Contest quarter is always the latest column.** Add a quarter, it becomes the one being scored.
3. **Cutoffs derive from the data** as the 33rd and 67th percentiles (terciles), so the three size groups stay balanced no matter how the numbers drift.

---

## Step 1: Helper block (all formulas, nothing typed by hand)

Put these below the table, starting at **A28**. They are calculations, not settings, so they update automatically.

| Cell | Label (col A) | Formula (col B) |
|---|---|---|
| B28 | Quarters filled | `=COUNTA(C1:Z1)` |
| B29 | Tier 1 cutoff | `=PERCENTILE($N$2:$N$25,2/3)` |
| B30 | Tier 2 cutoff | `=PERCENTILE($N$2:$N$25,1/3)` |

- **B28** counts how many quarter columns currently have a header. Everything else keys off this number.
- **B29 / B30** are the tercile cutoffs. On today's data they return 10 and 6, the same numbers you had, but now they move with the data instead of being fixed.

---

## Step 2: Column formulas

Type each into **row 2**, then fill down to row 25.

**M2 — Total.** All quarters, however many there are.
```
=SUM($C2:$Z2)
```

**N2 — Baseline.** Average of the four quarters before the latest one. `$B$28` is the quarter count, so this window slides forward on its own.
```
=AVERAGE(INDEX($C2:$Z2,1,$B$28-4):INDEX($C2:$Z2,1,$B$28-1))
```

**O2 — Contest metric.** The most recent quarter, whichever column that is.
```
=INDEX($C2:$Z2,1,$B$28)
```

**B2 — Bucket.** Reads the two cutoff cells from Step 1.
```
=IF(N2>=$B$29,"Tier 1",IF(N2>=$B$30,"Tier 2","Tier 3"))
```

**P2 — Volume Growth.**
```
=O2-N2
```

**Q2 — Percent Growth.** Format as a percentage.
```
=(O2-N2)/N2
```

**R2 — Volume Rank** (within group).
```
=SUMPRODUCT(($B$2:$B$25=B2)*($P$2:$P$25>P2))+1
```

**S2 — Growth Rank** (within group).
```
=SUMPRODUCT(($B$2:$B$25=B2)*($Q$2:$Q$25>Q2))+1
```

**T2 — Final Score.**
```
=AVERAGE(R2,S2)
```

**U2 — Place** (within group, ties break on higher percent growth).
```
=SUMPRODUCT(($B$2:$B$25=B2)*(($T$2:$T$25<T2)+($T$2:$T$25=T2)*($Q$2:$Q$25>Q2)))+1
```

**V2 — Result** (optional, flags top 2).
```
=IF(U2<=2,"PAID","")
```

---

## How you run it next quarter

1. Paste the new quarter's enrollments into the next empty column (the one just right of your latest quarter). Put the quarter label in row 1.
2. Done. `Quarters filled` ticks up by one, the baseline slides to the new four-quarter window, the latest quarter becomes the contest quarter, and the cutoffs and winners recalculate.

No formula changes, no re-typing cutoffs, ever.

---

## Two things to keep in mind

**Only add a quarter once it is complete.** A half-finished quarter would still become the contest quarter and would drag the baseline down. Add the column after the quarter closes.

**Check the tier split after each new quarter.** A percentile can occasionally land exactly on a repeated baseline value and split two identical territories across a boundary. Drop this check somewhere and confirm it reads **0**:
```
=SUMPRODUCT(--(COUNTIFS($N$2:$N$25,$N$2:$N$25,$B$2:$B$25,$B$2:$B$25)<>COUNTIF($N$2:$N$25,$N$2:$N$25)))
```
If it ever reads above 0, nudge one cutoff cell (B29 or B30) up or down by 0.5 to move the boundary onto a gap. That is the only manual touch the sheet ever needs, and only if that check fails.

---

## Sanity check on today's numbers

With 10 quarters filled, `Quarters filled` is 10, the baseline averages columns H to K (2Q2025 to 1Q2026), the contest metric reads column L (2Q2026), and the cutoffs come out at 10 and 6. Buckets land roughly 9 / 9 / 6, and the six paid positions are South FL, Mid-Atlantic, Desert Plains, Great South, North TX/OK, Carolinas.
# Enrollment Contest: Formula Guide

Corrected version. The cutoffs still calculate themselves from the data. The quarter formulas are bounded to the actual quarter columns so there is no circular reference.

Layout: 24 territories in **rows 2 to 25**, header in row 1. Quarter columns are **C to L** (1Q2024 to 2Q2026). Scoring columns start at M.

---

## Why you saw a circular reference

The earlier formulas used the range `C:Z`, which reaches past the quarters into the scoring columns. `Total = SUM($C2:$Z2)` was adding the Total cell to itself, and `COUNTA(C1:Z1)` counted the Baseline and Contest headers as if they were quarters, which is why "Quarters filled" read 19 instead of 10.

The fix: point the quarter formulas only at **C to L**, the real quarter columns.

---

## Delete this first

Remove the **Quarters filled** helper (the cell that reads 19). It is not needed and it was feeding the circular formulas. Keep the two cutoff cells below it.

---

## Cutoff cells (these calculate themselves)

In your helper block:

| Cell | Label | Formula |
|---|---|---|
| B35 | Tier 1 cutoff | `=PERCENTILE($N$2:$N$25,2/3)` |
| B36 | Tier 2 cutoff | `=PERCENTILE($N$2:$N$25,1/3)` |

These derive the two size boundaries as the 33rd and 67th percentiles of the baselines. On today's data they return 10 and 6, and they re-derive on their own whenever the baselines change. No typing.

---

## Column formulas

Type into **row 2**, fill down to row 25.

**M2 — Total.** Only the quarter columns C to L.
```
=SUM(C2:L2)
```

**N2 — Baseline.** Average of the four quarters before the contest quarter: 2Q2025, 3Q2025, 4Q2025, 1Q2026 (H to K).
```
=AVERAGE(H2:K2)
```

**O2 — Contest metric.** The contest quarter, 2Q2026 (column L).
```
=L2
```

**B2 — Bucket.** Reads the two cutoff cells.
```
=IF(N2>=$B$35,"Tier 1",IF(N2>=$B$36,"Tier 2","Tier 3"))
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

**U2 — Place** (within group, ties break on percent growth).
```
=SUMPRODUCT(($B$2:$B$25=B2)*(($T$2:$T$25<T2)+($T$2:$T$25=T2)*($Q$2:$Q$25>Q2)))+1
```

**V2 — Result** (optional).
```
=IF(U2<=2,"PAID","")
```

---

## What still updates on its own, and what does not

**Self-updating:** the cutoffs. Change any baseline and B35 and B36 re-derive. You never touch them.

**Manual each quarter:** the baseline window and the contest quarter. Because your quarter columns sit directly next to the scoring columns, there is no empty space for them to grow into, so a fully automatic sliding window is not possible in this layout without a circular reference. That is the trade-off, and it is a small one.

---

## Running it next quarter (3Q2026 and beyond)

When a quarter closes:

1. **Insert a column** just left of Total (between L and M). Put the new quarter's enrollments in it and the label in row 1.
2. Update **Total** to include the new column, for example `=SUM(C2:M2)`.
3. Update **Baseline** to the new last four quarters. When 3Q2026 lands in M, baseline becomes `=AVERAGE(I2:L2)` (3Q2025 to 2Q2026).
4. Update **Contest metric** to the new quarter, for example `=M2`.

That is three cell edits, filled down. The cutoffs, buckets, ranks and winners all recalculate on their own.

If you want it to be fully automatic for years with no edits at all, the quarter history has to move to the far right of the sheet so it can grow into empty columns. That is a one-time restructure. Say the word and I will write it up, otherwise the three-edit routine above is reliable and safe.

---

## Check after any change

- No circular reference warning
- Bucket reads Tier 1 / 2 / 3, roughly 9 / 9 / 6
- Percent Growth is a spread of positive and negative
- Each tier has exactly one 1 and one 2 in Place
- Tie-split check reads 0:
```
=SUMPRODUCT(--(COUNTIFS($N$2:$N$25,$N$2:$N$25,$B$2:$B$25,$B$2:$B$25)<>COUNTIF($N$2:$N$25,$N$2:$N$25)))
```
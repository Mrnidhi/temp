# Add More Quarter Columns

Add older quarters to the `Contest Scoring` sheet so more history is visible.

The baseline must keep using only the **last four completed quarters**. Adding history to the left does not change what the baseline measures.

---

## Step 1: Find the available quarters

Read the distinct values in `Raw Data` column `AA`. List them in chronological order and report the list.

Exclude any quarter that has not finished yet. The current quarter is still in progress and would pull every baseline down.

---

## Step 2: Insert the new columns

The sheet currently holds four quarters in columns C through F, running `3Q2025`, `4Q2025`, `1Q2026`, `2Q2026`.

Insert the older quarters **to the left of column C**, so all quarters stay in chronological order, oldest on the left.

For example, adding two quarters gives:

| Col | Quarter |
|---|---|
| C | 1Q2025 |
| D | 2Q2025 |
| E | 3Q2025 |
| F | 4Q2025 |
| G | 1Q2026 |
| H | 2Q2026 |

Everything to the right shifts across. Excel updates the existing formulas automatically.

Put the quarter label in row 1 of each new column. The label must match exactly what appears in `Raw Data` column `AA`.

---

## Step 3: Fill the new columns

Use the same roll up formula already used by the other quarter columns. The header drives the match.

```excel
=COUNTIFS('Raw Data'!$AO:$AO,$A2,'Raw Data'!$AA:$AA,C$1,'Raw Data'!$AQ:$AQ,1)
```

Fill down to the last data row.

---

## Step 4: Confirm the baseline still uses the last four quarters

After inserting, the baseline formula should read the **four rightmost** quarter columns, not all of them.

With six quarters in C through H, the baseline is:

```excel
=ROUNDUP(AVERAGE(E2:H2),0)
```

Check this. If the formula widened to cover all six quarters, correct it back to four.

---

## Step 5: Verify nothing moved

| Check | Expected |
|---|---|
| Quarters are in chronological order, oldest at C | yes |
| No in progress quarter was added | yes |
| Baseline covers exactly four columns | yes |
| Every baseline value is unchanged from before | yes |
| Every tier assignment is unchanged from before | yes |
| No formula errors anywhere | yes |

If any baseline or tier changed, the baseline formula picked up the new columns. Fix the formula rather than accepting the new values.

---

## Report back

1. The quarters found, in order
2. Any quarter excluded as incomplete
3. How many quarter columns now exist
4. Which four quarters the baseline used
5. Whether any baseline or tier changed
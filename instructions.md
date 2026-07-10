# Setting the Bucket Cutoffs Properly

## The problem with the current formula

```
=IF(N2>=10,"Tier 1",IF(N2>=6,"Tier 2","Tier 3"))
```

The numbers 10 and 6 are buried inside the formula, repeated across all 24 rows. Two things are wrong with that:

1. **To change a cutoff you would have to edit every cell.** Miss one and the sheet is silently inconsistent.
2. **Nobody reading the formula knows what 10 and 6 mean, where they came from, or that they are meant to be adjustable.** They look like magic numbers.

The fix is to hold each cutoff in one labelled cell, give that cell a name, and point the formula at the name. One place to change, and the formula reads like a sentence.

---

## Step 1: Build a small parameters box

Pick an empty area to the right of the table, for example starting at cell **Y1**. Enter:

| Cell | Content |
|---|---|
| Y1 | `Parameter` |
| Z1 | `Value` |
| Y2 | `Tier 1 cutoff (baseline >=)` |
| Z2 | `10` |
| Y3 | `Tier 2 cutoff (baseline >=)` |
| Z3 | `6` |

Put a border round it and bold the header so it reads as a settings block, not stray data.

---

## Step 2: Name the two value cells

Naming a cell lets you refer to it by a word instead of an address.

1. Click cell **Z2**.
2. Click the **Name Box** (the small box on the far left of the formula bar, where it currently says `Z2`).
3. Type `Tier1_Cutoff` and press Enter.
4. Click cell **Z3**, click the Name Box, type `Tier2_Cutoff`, press Enter.

Names cannot contain spaces, which is why they use an underscore.

---

## Step 3: Rewrite the bucket formula

In **B2**, enter:

```
=IF(N2>=Tier1_Cutoff,"Tier 1",IF(N2>=Tier2_Cutoff,"Tier 2","Tier 3"))
```

Fill down to B25.

Now the formula states its own logic: a territory is Tier 1 if its baseline is at or above the Tier 1 cutoff, Tier 2 if at or above the Tier 2 cutoff, otherwise Tier 3. To move a boundary you change one cell, Z2 or Z3, and all 24 rows update at once.

---

## Where the values 10 and 6 actually come from

They are not arbitrary, and this is worth being able to explain.

Sort the 24 baselines from largest to smallest:

```
17.75  12.5  12  11.5  11  11  10.5  10 | 9.75  8.75  8  7.5  7.25  7.25  6  6 | 5.75  5.5  4.25  3.5  3  2.25  1.75  1.5
```

To make three groups of eight, the boundaries fall after the 8th and 16th values.

- The 8th value is **10** and the 9th is 9.75, so the Tier 1 cutoff sits at **10**.
- The 16th value is **6** and the 17th is 5.75, so the Tier 2 cutoff sits at **6**.

Both boundaries land between two **different** numbers. That matters: if a cutoff fell between two territories with the same baseline, those two identical territories would end up in different tiers, which is impossible to defend to whichever rep loses. The chosen values avoid that. Both 6.0 territories stay together in Tier 2; the 5.75 sits just below in Tier 3.

Put a short note under the parameters box recording this, so the choice is documented on the sheet itself:

> Cutoffs set at the natural gaps in the sorted baselines (10 / 6), giving groups of 8 / 8 / 8 with no equal baselines split across a boundary.

---

## If the baselines change

When the real contest runs, the baseline window moves and these numbers will shift. The method does not:

1. Sort the new baselines.
2. Find the two gaps nearest the one-third and two-third marks.
3. Move each cutoff onto a gap between two different values, never between two equal ones.
4. Type the two results into Z2 and Z3.

The formula never changes. Only the two parameter cells do.
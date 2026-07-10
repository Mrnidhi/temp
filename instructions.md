# Enrollment Contest: Sheet Build Instructions

Build a scoring sheet that ranks 28 sales territories on enrollment growth, fairly, despite large differences in territory size.

---

## Key terms

**Enrollment.** A patient signed up for treatment at a center. This is the only thing the contest scores. It is not a referral.

**ATC.** An individual treatment center. There are roughly 96 of them.

**Territory.** A sales patch. There are 28. Each territory contains between 3 and 10 ATCs.

**Baseline.** What a normal quarter looks like for a given territory. Every score is measured against this.

The source data records enrollments at the ATC level. The contest is scored at the territory level. Rolling one up into the other is the first half of the job.

---

## Parameters

These are the settings the build assumes. If any of them change, the formulas still hold.

| Setting | Value |
|---|---|
| Baseline window | Last 4 completed quarters |
| Number of buckets | 3 |
| How buckets are split | By baseline size, using natural cutoffs |
| Bucket sizes | Roughly 9 / 10 / 9 (28 does not divide evenly into 3) |
| Paid places | Top 2 in each bucket, so 6 winners total |
| Tiebreaker | Higher percent growth wins |
| Contest window | August through September |

---

## Why the contest is scored this way

Territory sizes are very uneven. Over a six quarter stretch, some territories record around 100 enrollments while others record about 13. If every territory competed in one shared pool, the largest ones would win every time and the smallest would never be in contention.

Two design choices fix this:

1. **Buckets.** Territories only compete against others of a similar size.
2. **Two growth measures instead of one.** Volume growth rewards adding the most patients. Percent growth rewards improving the most relative to your own size. Scoring on both, equally weighted, means neither the big nor the small territories have a built in advantage.

---

## The build, end to end

1. Load the enrollment data
2. Roll ATC enrollments up into territories, by quarter
3. Calculate each territory's baseline
4. Sort territories into 3 buckets by baseline
5. Count enrollments during the contest window
6. Calculate volume growth and percent growth
7. Rank each territory twice, within its own bucket
8. Average the two ranks into a final score
9. Assign places and pick winners

Steps 1 through 4 use historical data and can be built immediately. Steps 5 through 9 are formulas that populate once contest results exist. Build them up front so the sheet scores itself automatically.

---

## Step 1: Load the data

Source is the enrollment tab of the ATC performance workbook.

Required fields:
* **Column D** contains the territory
* The ATC name
* The enrollment date, or a field identifying which quarter the enrollment occurred in
* A patient identifier

Copy this into a sheet named `Raw Data` without modification.

---

## Step 2: Roll ATCs up into territories

Create a pivot table from `Raw Data`:

* **Rows:** Territory
* **Columns:** Quarter
* **Values:** Count of enrollments

Pull the last five to six quarters so the trend is visible, even though only four are used for the baseline.

Paste the result into a new sheet named `Contest Scoring`.

**Validation check:** all 28 territories must appear. If fewer appear, some ATCs failed to map to a territory and dropped out of the roll up. Resolve this before continuing, because every downstream number depends on it.

---

## Step 3: Calculate the baseline

The baseline answers: what does a normal quarter look like for this territory?

Use the **last 4 completed quarters**, not all six. The most recent quarters ran unusually high, and including them would set a bar most territories cannot clear.

```
Baseline = ROUNDUP(AVERAGE(last 4 quarters), 0)
```

Round up, so the bar is never set below a whole enrollment.

---

## Step 4: Assign the 3 buckets

1. Sort all 28 territories by baseline, largest first
2. Split into three groups: **Tier 1** (largest), **Tier 2** (middle), **Tier 3** (smallest)
3. Because 28 does not divide evenly, let the natural break points in the data decide. Expect roughly 9 / 10 / 9.

Record the result in the `Bucket` column. Every territory must have a value. This column drives every ranking that follows.

---

## Step 5: Count contest enrollments

Once the contest window closes, rerun the Step 2 pivot filtered to the contest window only. Add the result as the `Contest Enrollments` column.

---

## Step 6: The two growth measures

Each territory gets both.

**Volume growth** is how many extra enrollments were added:
```
Contest Enrollments - Baseline
```

**Percent growth** is how much the territory improved relative to its own size:
```
(Contest Enrollments - Baseline) / Baseline
```

Format percent growth as a percentage.

**Worked example.** A large territory goes from a baseline of 90 to 97. That is +7 enrollments but only 8 percent growth. A small territory goes from 13 to 17. That is +4 enrollments but 31 percent growth. Volume alone crowns the first. Percent alone crowns the second. Using both is what makes the contest fair.

---

## Step 7: Rank twice, within bucket only

Two separate rankings. A territory is only ever compared against others in its own bucket, never against all 28.

**Volume Rank.** Most enrollments added, where 1 is best.
**Growth Rank.** Largest percent growth, where 1 is best.

Excel has no built in function to rank within a group. Use `SUMPRODUCT` to count how many territories in the same bucket outperformed this one, then add 1.

---

## Step 8: Blend the ranks

```
Final Score = AVERAGE(Volume Rank, Growth Rank)
```

**Lowest score wins.**

A territory ranked 1st on volume and 3rd on percent scores 2.0. A territory ranked 3rd on volume and 1st on percent also scores 2.0. They tie, which is the intended behaviour. Neither can win on size alone.

---

## Step 9: Assign places

Rank the final scores within each bucket, lowest first. The placement formula in the next section resolves ties automatically by awarding the better place to the territory with higher percent growth.

* 1st place in each bucket wins
* 2nd place in each bucket is also paid
* Six winners in total across the three buckets

---

## Sheet layout

Sheet name: `Contest Scoring`. Header in row 1. Data in rows 2 through 29 (28 territories).

| Col | Field |
|---|---|
| A | Territory |
| B | Bucket |
| C | Quarter 1 enrollments (oldest) |
| D | Quarter 2 enrollments |
| E | Quarter 3 enrollments |
| F | Quarter 4 enrollments (most recent completed) |
| G | Baseline |
| H | Contest Enrollments |
| I | Volume Growth |
| J | Percent Growth |
| K | Volume Rank |
| L | Growth Rank |
| M | Final Score |
| N | Place |

---

## Formulas

Enter these in row 2 and fill down to row 29.

**G2, Baseline**
```excel
=ROUNDUP(AVERAGE(C2:F2),0)
```

**I2, Volume Growth**
```excel
=H2-G2
```

**J2, Percent Growth**
```excel
=IF(G2=0,"",(H2-G2)/G2)
```

**K2, Volume Rank within bucket**
```excel
=SUMPRODUCT(($B$2:$B$29=B2)*($I$2:$I$29>I2))+1
```

**L2, Growth Rank within bucket**
```excel
=SUMPRODUCT(($B$2:$B$29=B2)*($J$2:$J$29>J2))+1
```

**M2, Final Score**
```excel
=AVERAGE(K2,L2)
```

**N2, Place within bucket, with tiebreaker built in**
```excel
=SUMPRODUCT(($B$2:$B$29=B2)*(($M$2:$M$29<M2)+($M$2:$M$29=M2)*($J$2:$J$29>J2)))+1
```

The placement formula counts two things: territories in the same bucket with a better final score, plus territories with an identical final score but higher percent growth. That applies the tiebreaker without any manual step.

---

## Example rows

Illustrative numbers only. The layout is what matters.

| Territory | Bucket | Q1 | Q2 | Q3 | Q4 | Baseline | Contest | Vol Growth | % Growth | Vol Rank | Growth Rank | Final Score | Place |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| South FL | Tier 1 | 24 | 28 | 22 | 26 | 25 | 30 | 5 | 20% | 2 | 3 | 2.5 | 2 |
| Rocky Mtn | Tier 3 | 3 | 4 | 2 | 3 | 3 | 5 | 2 | 67% | 1 | 1 | 1.0 | 1 |

---

## Data quality guards

**Count each patient once.** A patient who enrolls, drops out, then enrolls again appears as two records. Left uncorrected, 27 patients can read as 28 enrollments. Deduplicate on the patient identifier before counting, not on the order or record. Without this, a territory's number can be inflated by the same person twice.

**Only count enrollments that progress.** An enrollment that goes nowhere should not score. Restrict the count to enrollments that reach the next stage of the funnel. This prevents padding the number with patients who were never a real fit.

---

## Validation checklist

Before treating any result as final:

- [ ] All 28 territories appear in the roll up
- [ ] Every territory has a non blank bucket
- [ ] Every baseline is greater than zero, so no percent growth divides by zero
- [ ] Bucket counts total 28
- [ ] Each bucket has exactly one territory in place 1 and one in place 2
- [ ] Enrollments are deduplicated by patient
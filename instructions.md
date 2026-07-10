# Contest Scoring Sheet: Full Validation Pass

Run every check below against the `Contest Scoring` sheet in one pass. Do not fix anything. Do not modify any cell. Only report.

Output a single table with these columns: **Check**, **Result**, **Expected**, **Status**, **Notes**.

Status is `PASS`, `FAIL`, `PENDING`, or `BLOCKED`.

* `PENDING` means the check cannot run yet because the contest has not happened.
* `BLOCKED` means required data does not exist in the workbook.
* Never mark something `PASS` by changing a value. If a check fails, it fails.

Before starting, detect the last row containing a territory name in column A. Call it `LAST`. Report it. Every formula below uses row 29 as a placeholder. Replace 29 with `LAST`.

---

## Section 1: Structure

**1.1 Last data row detected**
Report `LAST`.

**1.2 Territories in the scoring sheet**
```excel
=COUNTA(A2:A29)
```
Expected: equals check 1.3.

**1.3 Distinct territories in the raw data**
```excel
=SUMPRODUCT(('Raw Data'!$AO$2:$AO$5000<>"")/COUNTIF('Raw Data'!$AO$2:$AO$5000,'Raw Data'!$AO$2:$AO$5000&""))
```
Expected: 28.

If 1.2 and 1.3 disagree, the roll up dropped territories. If 1.3 is below 28, the roster itself is incomplete. These are different problems. Say which one occurred.

**1.4 No blank territory names**
```excel
=COUNTBLANK(A2:A29)
```
Expected: 0.

**1.5 No blank buckets**
```excel
=COUNTBLANK(B2:B29)
```
Expected: 0.

---

## Section 2: Source data integrity

**2.1 Enrollment rows with no territory assigned**
```excel
=COUNTIFS('Raw Data'!$AQ:$AQ,1,'Raw Data'!$AO:$AO,"")
```
Expected: 0. Above zero means some centers are unmapped and silently dropping out of the roll up. List the affected centers.

**2.2 Repeated order identifiers**
Locate the column holding the order id, then:
```excel
=SUMPRODUCT(--(COUNTIF('Raw Data'!$AP$2:$AP$5000,'Raw Data'!$AP$2:$AP$5000)>1))
```
Expected: 0. Replace `AP` with the correct column and name it in your notes.

**2.3 Patient identifier exists**
Read the full header row of `Raw Data`. Report whether any column identifies a **person** rather than a transaction: a medical record number, patient key, subject id, or a name and date of birth pair.

Expected: yes. If only an order identifier exists, mark this `BLOCKED` and state plainly that every baseline in the sheet is a count of orders, not patients, and that a patient who enrolled twice is being counted twice.

**2.4 Quarter cells are all numeric**
```excel
=COUNT(C2:F29)
```
Expected: four times the territory count.

**2.5 No negative enrollment counts**
```excel
=SUMPRODUCT(--(C2:F29<0))
```
Expected: 0.

---

## Section 3: Baseline

**3.1 Stored baseline matches a fresh calculation**
```excel
=SUMPRODUCT(--(G2:G29<>ROUNDUP((C2:C29+D2:D29+E2:E29+F2:F29)/4,0)))
```
Expected: 0.

This is the important one. Any nonzero result means a baseline in column G does not match its own quarterly numbers, and was either hand entered or left stale. Name every territory where the two disagree, and give both the stored value and the correct value.

**3.2 Every baseline is above zero**
```excel
=COUNTIF(G2:G29,">0")
```
Expected: equals the territory count. A zero baseline would divide by zero in percent growth.

**3.3 Adjusted baseline matches the scaling formula**
```excel
=SUMPRODUCT(--(ROUND(H2:H29,1)<>ROUND(G2:G29*$S$1/$S$2,1)))
```
Expected: 0.

**3.4 Adjusted baseline is smaller than the baseline**
```excel
=SUMPRODUCT(--(H2:H29<G2:G29))
```
Expected: equals the territory count. The contest window is shorter than a quarter, so every adjusted baseline must be lower.

**3.5 Scaling factor is correct**
Confirm `S1` is 2 and `S2` is 3.

---

## Section 4: Buckets

**4.1 Bucket assignment matches the cutoffs**
```excel
=SUMPRODUCT(--(B2:B29<>IF(G2:G29>=$S$3,"Tier 1",IF(G2:G29>=$S$4,"Tier 2","Tier 3"))))
```
Expected: 0. Any nonzero result means a tier was typed in rather than derived.

**4.2 No baseline value split across two tiers**
```excel
=SUMPRODUCT(--(COUNTIFS($G$2:$G$29,$G$2:$G$29,$B$2:$B$29,$B$2:$B$29)<>COUNTIF($G$2:$G$29,$G$2:$G$29)))
```
Expected: 0. Above zero means two territories with identical baselines are competing in different tiers, which is indefensible. Name them.

**4.3 Tier counts sum to the territory count**
```excel
=COUNTIF(B:B,"Tier 1")+COUNTIF(B:B,"Tier 2")+COUNTIF(B:B,"Tier 3")
```
Expected: equals the territory count.

**4.4 No tier is empty**
Report the count in each tier. Each must be above zero. Do **not** expect the tiers to be equal in size. Uneven tiers are correct.

**4.5 Cutoff placement is reviewable**
Report the two cutoff values, and for each cutoff report the nearest baseline value above it and the nearest below it. If either pair is equal, check 4.2 should have failed.

---

## Section 5: Scoring columns

If column I is entirely blank, run 5.1 and mark 5.2 through 5.6 as `PENDING`.

**5.1 Blank contest results produce blank scores**
```excel
=SUMPRODUCT(--(($I$2:$I$29="")*($J$2:$J$29<>"")))
```
Expected: 0. Nothing downstream may display a value while contest results are empty.

**5.2 No formula errors anywhere**
```excel
=SUMPRODUCT(--ISERROR(J2:O29))
```
Expected: 0.

**5.3 Every territory has a full set of scores**
Confirm no territory has a Final Score without a Place, or a rank without a score.

**5.4 Each tier starts its ranks at 1**
For each tier, the minimum Volume Rank and the minimum Growth Rank must both be 1.

**5.5 Exactly one first place per tier**
```excel
=COUNTIFS(B:B,"Tier 1",O:O,1)
```
Repeat for Tier 2 and Tier 3. Expected: 1 each.

**5.6 Exactly one second place per tier**
```excel
=COUNTIFS(B:B,"Tier 1",O:O,2)
```
Repeat for Tier 2 and Tier 3. Expected: 1 each. The top two in each tier are paid, so a missing second place means a payout cannot be assigned.

---

## Section 6: Does the fairness logic actually work

Only meaningful once contest results exist. Mark `PENDING` otherwise.

**6.1 A small territory can beat a large one**
Find any tier containing a territory that added fewer enrollments than another but placed ahead of it on the strength of percent growth. Report one example, with both territories named and both growth figures shown.

If no such case exists anywhere in the sheet, the equal weighting of volume and percent growth is not doing its job, and the contest is behaving like a raw volume contest. Say so explicitly.

**6.2 Rank blending is symmetric**
Confirm that a territory ranked 1st on volume and 3rd on percent receives the same final score as one ranked 3rd on volume and 1st on percent. Both should be 2.0.

---

## Final report

After the table, write a short summary answering these questions directly:

1. Is the sheet safe to score a real contest with, yes or no?
2. Which checks failed, and what is the single underlying cause of each?
3. Which checks are blocked by missing data, and exactly what data is needed to unblock them?
4. Did any baseline in column G disagree with its own quarterly numbers?
5. Are any two territories with the same baseline sitting in different tiers?

Do not soften a failure. Do not resolve a blocked item by altering data. Report it.
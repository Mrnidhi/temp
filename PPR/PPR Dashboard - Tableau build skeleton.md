# PPR Dashboard - Tableau build skeleton

Goal: pick a center, the P&PR scorecard auto-fills from Infinity and refreshes on a
schedule. Replaces the manual "(Proposed) P&PR Metrics.xlsx".

The scorecard has 14 metrics in 4 groups, shown across time columns (Launch to date,
2024, 2025, 2026 YTD), ATC-tier benchmark columns (Top 10 / Top 40 / New), and
quarters (Q4'25 to Q3'26 QTD).

---

## 1. Data model (bring these files in as one source)
Relate every file on **Patient ID** and **ATC / Center name**. One patient-grain
source is easiest; if a file is one-row-per-order, keep it and de-dupe in the calcs.

| Role | Likely file | Gives us |
|---|---|---|
| Orders / enrollment | BAI - List of Orders | TIL Order Name, Order Request Date, Patient ID, Center |
| Patient detail | file_Patient_Characteristics | Patient ID, ATC Name, referral, health status |
| Tumor tissue | file_Tumor_Procurements | Tumor Tissue Pickup Date, resection info |
| Infusions | file_Infusions | Infusion Date, Final Product Delivery Date |
| Slots / mfg | file_Manufacturing_Slots, file_Pre_Reserved_Slots | Slot Reservation Date, Mfg Start Date, OOS flag |
| Center list / tier | file_Veeva_Komodo_ATC_Mapping | Center name, region, onboarding year |

## 2. Field mapping - FILL THIS FIRST
Replace the right column with your actual header, then the calcs below just work.

| Placeholder used below | Your real column |
|---|---|
| [Patient ID] | ? |
| [Center] (ATC name) | ? |
| [Order Request Date] (enrollment) | ? |
| [TIL Order Name] | ? |
| [Tumor Pickup Date] | ? |
| [Infusion Date] | ? |
| [Final Delivery Date] | ? |
| [Mfg Start Date] | ? |
| [Slot Reservation Date] | ? |
| [TTP Change Date] (cancel/reschedule) | ? |
| [Dropout Reason] | ? |
| [OOS Flag] | ? |
| [Onboarding Year] | ? |

## 3. Parameters & filters
- Parameter **pCenter** (string, populate from [Center]). Center Scorecard sheet filters `[Center] = [pCenter]`.
- Date pills: put `YEAR([Order Request Date])` and `QUARTER` on Columns for the time cuts.
- **ATC Tier** calc (for the benchmark columns):
```
// rank centers by enrollments in the window
IF [New ATC] THEN "New"
ELSEIF RANK(COUNTD([Patient ID]),'desc') <= 10 THEN "Top 10"
ELSEIF RANK(COUNTD([Patient ID]),'desc') <= 40 THEN "Top 40"
ELSE "Other" END
```
- **New ATC**: `[Onboarding Year] = 2025`

## 4. Calc fields (the 14 metrics)

Patient Identification & Enrollment
```
Patients Enrolled   = COUNTD([Patient ID])
Enrollments         = COUNTD([TIL Order Name])          // orders, not patients
TTP Cancel <=7d     = COUNTD(IF DATEDIFF('day',[TTP Change Date],[Slot Reservation Date]) BETWEEN 0 AND 7
                             THEN [TIL Order Name] END)
```
Tumor Tissue Procurement
```
Completed TTPs = COUNTD(IF [Tumor Pickup Date] <= TODAY() THEN [Patient ID] END)
Scheduled TTPs = COUNTD(IF [Tumor Pickup Date] >  TODAY() THEN [Patient ID] END)
2nd Resections = COUNTD(IF {FIXED [Patient ID],[Center]: COUNTD([Tumor Pickup Date])} >= 2
                        THEN [Patient ID] END)
```
AMTAGVI Regimen
```
Dropouts post-TTP (health) = COUNTD(IF [Dropout Reason] = "Patient Health" THEN [Patient ID] END)
OOS Products               = COUNTD(IF [OOS Flag] THEN [Patient ID] END)
AMTAGVI Infusions          = COUNTD(IF NOT ISNULL([Infusion Date]) THEN [Patient ID] END)
Patient Progression Rate   = SUM([Dropouts post-TTP (health)]) / SUM([Mfg Starts])
Mfg Starts                 = COUNTD(IF NOT ISNULL([Mfg Start Date]) THEN [Patient ID] END)
```
AMTAGVI Treatment Timelines (days)
```
Avg Enroll to TTP   = AVG(DATEDIFF('day',[Order Request Date],[Tumor Pickup Date]))
Avg TTP to Infusion = AVG(DATEDIFF('day',[Tumor Pickup Date],[Infusion Date]))
Avg Delivery to Inf = AVG(DATEDIFF('day',[Final Delivery Date],[Infusion Date]))
```

## 5. Sheet layout
- Sheet **Center Scorecard**: Rows = Metric Name (or a group + metric); Columns = the year/quarter pills; filter to pCenter. Format as a text table to mirror the Excel.
- Sheet **National Benchmarks**: same rows, Columns = [ATC Tier], no center filter.
- Dashboard: benchmarks to the right of the center table, pCenter selector on top, a "Source data as of" text = `MAX([Order Request Date])`.

## 6. Build order for TODAY (minimum showable)
1. Connect the files, set the mapping (section 2).
2. pCenter parameter + one center filter.
3. Build just the first group (Patients Enrolled, Enrollments, TTP Cancel) in the matrix, 2025 / 2026 YTD columns only.
4. That is enough to show: pick a center, numbers fill, one refresh works. Add the rest of the metrics after.

## 7. Publish + refresh
Publish to Tableau Server, connect the same Infinity source there, set a scheduled
refresh. After that: pick a center, screenshot or drop the view into PowerPoint.

## 8. To finalize I need
The actual file names and column headers (section 2). Send those and I convert every
placeholder to your real fields, and confirm the two ambiguous ones: whether
"Enrollments" counts orders vs patients, and which date defines an enrollment.

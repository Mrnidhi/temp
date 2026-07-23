# P&PR Scorecard - Tableau build spec

Build the P&PR scorecard natively in Tableau Desktop from the `.hyper` extracts in this
folder. Definitions follow `../` memory spec (Kolin's Meet 6 walkthrough + template footnotes).

Two sources, two jobs:
- **`ppr_scorecard.hyper`** (table `Scorecard`) - the pre-shaped tidy matrix. **Use this for
  the mandated scorecard.** Tableau just pivots it, so the multi-window template (Launch-to-date
  + years + tier benchmarks + quarters, all at once) drops in cleanly with almost no calcs.
- **`ppr_analysis.hyper`** (table `Orders`) - order-grain rows with the derived flags and dates.
  Use this if you want Tableau to compute the metrics itself (single-window scorecards, trends,
  funnels, or to not depend on the Python pre-aggregation). Formulas in the appendix.

Why the split: the template's columns overlap (Launch-to-date is the total of the year columns),
which is painful to reproduce from row-level data but trivial from the tidy long table. Building
the exact template off `Scorecard` is the reliable path; `Orders` is for native/custom work.

Real-data refresh (both): on the office laptop rerun the pipeline on the real Infinity files,
rerun `pipeline/build_hyper.py`, then in Tableau **Data > [source] > Extract > Refresh** (or
replace the `.hyper`). The view is unchanged; only the data updates.

---

## A. Mandated scorecard, off `ppr_scorecard.hyper` (recommended)

### 1. Connect
Tableau Desktop > Connect > To a File > **More** > select `ppr_scorecard.hyper`. Drag the
**`Scorecard`** table onto the canvas. It is a native extract; no join or prep needed.

### 2. Parameter (the center selector)
Create parameter **`pCenter`**:
- Data type: String
- Allowable values: List > **Add values from field** > `center`
- Current value: any center (e.g. the busiest)

### 3. One calc field
Create **`Keep Row`** (Boolean):
```
([scope] = "Center" AND [center] = [pCenter]) OR [scope] = "National"
```
This keeps the selected center's year/quarter cells and always keeps the national benchmark
cells, so the benchmark block stays constant whichever center is chosen.

### 4. Worksheet "P&PR Scorecard" (text table)
- **Filter:** drag `Keep Row` to Filters, keep **True**.
- **Columns shelf:** `col_group` then `col_label` (both discrete/blue).
  - Sort `col_label`: Field > `col_order`, Aggregation Minimum, Ascending.
  - Sort `col_group`: Field > `col_order`, Aggregation Minimum, Ascending.
  - This yields the template order: Launch to Date, 2024, 2025, 2026 YTD, Top 10, Top 40, New,
    Q3'26 QTD, Q2'26, Q1'26, Q4'25 - grouped under Time / Benchmark / Quarter headers.
- **Rows shelf:** `metric_group` then `metric` (both discrete).
  - Sort `metric`: Field > `metric_order`, Minimum, Ascending.
- **Marks (Text):** drag **`value_display`** to Text. It becomes `ATTR([value_display])`.
  Each cell is a single row, so ATTR returns the pre-formatted string (counts as integers,
  timelines to 1 decimal, Patient Progression Rate as a percent). No number formatting needed.
- **Fit:** Analysis > Table Layout, or set Fit = Entire View.

### 5. Cosmetics (Iovance house style)
- Rename `col_group` members (right-click a header > Edit Alias): "Benchmark" -> "YTD National
  Metrics", "Quarter" -> "Quarterly ATC Metrics", "Time" -> "This Center". (Tableau cannot put
  the live center name in a column header; keep "This Center" or add the center name via a title.)
- Format > Borders: row and column dividers on (thin). Shading: header row olive `#567A2E` with
  white bold-italic text; benchmark columns light steel `#EEF3F9`.
- Rename the sheet tab "P&PR Scorecard".

### 6. Dashboard "P&PR Scorecard"
- New dashboard, size Automatic or 1200 x 800.
- Drag the worksheet in.
- Add the **`pCenter`** parameter control (dropdown) to the top (Analysis > Parameters, or the
  sheet's parameter card > Show).
- Add a title: "P&PR Scorecard" and a floating text "Source Data As of: <date>".
- Optional: add the `metric_group` or `col_group` as a filter card if you want show/hide toggles.

Result: pick a center in the dropdown, every metric fills, the three national columns stay put.

---

## B. Native metric build, off `ppr_analysis.hyper` (advanced / custom)

Connect the `Orders` table. Create `pCenter` as above from field `atc`. The 13 metrics as
Tableau calc fields (the flags are pre-computed per order, so the calcs stay clean):

```
// 1  Enrollments in IovanceCares
COUNTD([order_request__til_order_name])

// 2  Patients Enrolled in IovanceCares
COUNTD([iovance_patient_id])

// 3  TTPs Cancelled or Rescheduled within 7 Days   (proxy flag; see note)
SUM(IF [ttp_cancel_le7] THEN 1 ELSE 0 END)

// 4  Completed TTPs
SUM(IF [completed_ttp] THEN 1 ELSE 0 END)

// 5  Scheduled TTPs
SUM(IF [scheduled_ttp] THEN 1 ELSE 0 END)

// 6  2nd Resections (patients with 2+ real TTP dates)
COUNTD(
  IF {FIXED [iovance_patient_id] :
        COUNTD(IF NOT ISNULL([tumor_pickup_date]) THEN [tumor_pickup_date] END)} >= 2
  THEN [iovance_patient_id] END)

// 7  Patient Related Drop-outs following TTP due to patient health
SUM(IF [dropout_post_ttp_health] THEN 1 ELSE 0 END)

// 8  OOS Products
SUM(IF [oos_product] THEN 1 ELSE 0 END)

// 9a Mfg Starts   (denominator)
SUM(IF [mfg_started] THEN 1 ELSE 0 END)
// 9b Drop-offs after Mfg Start   (numerator)
SUM(IF [drop_after_mfg] THEN 1 ELSE 0 END)
// 9  Patient Progression Rate
[Drop-offs after Mfg Start] / [Mfg Starts]          // format as percentage

// 10 AMTAGVI Infusions Performed
SUM(IF [amtagvi_infused] THEN 1 ELSE 0 END)

// 11 Average Time From Enrollment Date to TTP (Days)
AVG([days_enroll_to_ttp])

// 12 Average Time From TTP to AMTAGVI Infusion (Days)
AVG([days_ttp_to_infusion])

// 13 Average Time From Final Product Delivery Date to AMTAGVI Infusion (Days)
AVG([days_delivery_to_infusion])
```

Supporting dimensions already in the extract: `atc_tier` (Top 10 / Top 40 / New / Other),
`enroll_year` (2024/2025/2026), `enroll_q` (e.g. 2026Q2), `region`, `territory`.

**Single-window scorecard:** filter `atc` = `pCenter`, put Measure Names on Rows and the 13
measures on Measure Values, put `enroll_year` on Columns for a year view.

**Benchmark columns are the hard part here.** To show the selected center beside its tier
average in one view you need the tier aggregate to ignore the center filter - use a separate
"National" worksheet (filter `atc_tier`, no center filter) placed next to the center sheet on
the dashboard, exactly as the tidy build does it in one table. For the exact template matrix,
prefer source A.

---

## B2. Current Template (to retire), off `ppr_scorecard.hyper` (optional second sheet)

The tidy table also carries the workbook's second sheet: rows with `scope = "CurrentTemplate"`
hold the all-ATC launch-to-date quartiles (`25th Percentile`, `Median`, `75th Percentile`) and
`National Average` per metric. To build it: keep `([scope]="Center" AND [center]=[pCenter] AND
[col_label]="Launch to Date") OR [scope]="CurrentTemplate"`, same Rows shelf, `col_label` on
Columns. The `Keep Row` calc in section A excludes these rows automatically, so the mandated
scorecard is unaffected.

## C. Notes / honest caveats (carry into any build)
- **TTPs Cancelled within 7 Days** and the **'New' tier** are proxies in this preview. The 7-day
  metric needs Infinity's snapshot history (Jonathan's feed) to measure days-to-cancellation; the
  'New' tier needs each center's onboarding year (not in the current mapping export). Both resolve
  once the real fields are connected - no workbook change, just better inputs.
- **Top 10 / Top 40** = highest-enrolling centers in the timeframe (the set shifts); pre-computed
  in `atc_tier`.
- A starter workbook `../PPR Scorecard.twbx` exists (connected to the tidy CSV). It is a
  convenience only and unverified in Desktop; this spec is the source of truth.

## D. QA checklist (in Desktop)
- [ ] Pick 3 centers in `pCenter`; the year/quarter columns change, the Top 10/40/New columns stay fixed.
- [ ] Counts are whole numbers; Patient Progression Rate shows a percent; timelines show 1 decimal.
- [ ] "Launch to Date" equals the sum of 2024 + 2025 + 2026 for the count metrics.
- [ ] Column order matches the template (Launch, years, Top 10/40/New, Q3'26 QTD .. Q4'25).
- [ ] Refresh the extract and confirm the "Source Data As of" date and values update.

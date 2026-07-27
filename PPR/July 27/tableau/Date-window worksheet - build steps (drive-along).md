# Date-window verification worksheet - build steps

Goal: one worksheet where you set a start and end date and every metric recounts for that
window, each on its own event date (enrollment, TTP pickup, delivery, or infusion), the way
Kolin's Year-over-Year slides work. Build it once here to prove the mechanic, then repeat on
the office laptop with real data to verify against his slides.

Data source: the **Orders** table (order-grain), from `ppr_analysis.hyper`. This is NOT the
pre-aggregated Scorecard source; the date filter needs one row per order with the raw dates.

---

## Step 1. Add the Orders data source
Web edit: Data menu (left) -> New Data Source -> upload `ppr_analysis.hyper`
(`PPR Automation/tableau/ppr_analysis.hyper`). Drag the **Orders** table onto the canvas.
If web edit will not upload a local file, this step is a Desktop-only move; tell me and we
adjust. (On the office laptop it is Connect > To a File > the .hyper.)

## Step 2. Two parameters (the date filter)
Create parameter **pStart**: data type Date, current value 2025-01-01.
Create parameter **pEnd**:   data type Date, current value 2025-09-30.
(These are the two ends of one window. Window-A-vs-Window-B and the Difference column come
after the single window works.)

## Step 3. A center parameter (or filter)
Create **pCenter**: String, list, Add values from field -> `atc`. Pick any center.
Then a calc **Keep Center** = `[atc] = [pCenter]`, drag to Filters, keep True.
(Or just drag `atc` to Filters and pick one center for the test.)

## Step 4. The 13 metric calcs (paste each as a Calculated Field)
Each one filters on ITS OWN event date between pStart and pEnd. Names in quotes are the
field names to give them.

"01 Enrollments"
COUNTD(IF [enrollment_date] >= [pStart] AND [enrollment_date] <= [pEnd]
       THEN [order_request__til_order_name] END)

"02 Patients Enrolled"
COUNTD(IF [enrollment_date] >= [pStart] AND [enrollment_date] <= [pEnd]
       THEN [iovance_patient_id] END)

"03 TTPs Cancelled <=7d"
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [ttp_cancel_le7]
    THEN 1 ELSE 0 END)

"04 Completed TTPs"
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [completed_ttp]
    THEN 1 ELSE 0 END)

"05 Scheduled TTPs"
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [scheduled_ttp]
    THEN 1 ELSE 0 END)

"06 2nd Resections"
COUNTD(
  IF {FIXED [iovance_patient_id] :
        COUNTD(IF NOT ISNULL([tumor_pickup_date])
                  AND [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd]
               THEN [tumor_pickup_date] END)} >= 2
  THEN [iovance_patient_id] END)

"07 Dropouts (health) after TTP"
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [dropout_post_ttp_health]
    THEN 1 ELSE 0 END)

"08 OOS Products"
SUM(IF [fp_delivery_date] >= [pStart] AND [fp_delivery_date] <= [pEnd] AND [oos_product]
    THEN 1 ELSE 0 END)

"09a Drops after mfg"
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [drop_after_mfg]
    THEN 1 ELSE 0 END)
"09b Mfg starts"
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [mfg_started]
    THEN 1 ELSE 0 END)
"09 Patient Progression Rate"   (format as percentage)
[09a Drops after mfg] / [09b Mfg starts]

"10 AMTAGVI Infusions"
SUM(IF [infusion_date] >= [pStart] AND [infusion_date] <= [pEnd] AND [amtagvi_infused]
    THEN 1 ELSE 0 END)

"11 Days Enrollment -> TTP"     (event date = TTP pickup)
AVG(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd]
    THEN [days_enroll_to_ttp] END)

"12 Days TTP -> Infusion"       (event date = infusion)
AVG(IF [infusion_date] >= [pStart] AND [infusion_date] <= [pEnd]
    THEN [days_ttp_to_infusion] END)

"13 Days Delivery -> Infusion"  (event date = infusion)
AVG(IF [infusion_date] >= [pStart] AND [infusion_date] <= [pEnd]
    THEN [days_delivery_to_infusion] END)

## Step 5. Lay out the worksheet
- Rows shelf: Measure Names (you will place the 13 calcs), or build it as a simple text
  table: drag each calc to the Text mark and use Measure Names/Values.
  Simplest: put **Measure Values** on Text, **Measure Names** on Rows, then drag the 13
  calcs into the Measure Values card and remove anything else.
- Show parameter controls: right-click pStart, pEnd, pCenter -> Show Parameter.
- Format counts as whole numbers, "09" as a percentage, "11/12/13" to 1 decimal.

## Step 6. Test it
- With pStart 2025-01-01 and pEnd 2025-09-30 on the busiest center, you should get non-zero
  counts. Change pEnd to 2026-05-05 and the counts should grow.
- Cross-check: on the HTML dashboard (quick-check only), the same center and window give the
  same numbers. The Python and the browser engine already match exactly, so Tableau should too.

## After this works (office laptop, real data)
- Duplicate the 13 calcs as a "Window B" set using pStartB / pEndB, add Difference = B - A.
- Set the two windows to a Kolin slide's ranges (e.g. UK: Jan-Sep 2025 vs Oct 2025-May 5 2026)
  and confirm the numbers land close to the slide. Exact match only if the extract is from the
  same as-of date as the slide.

# MAIN DASHBOARD build - Tableau Desktop (office laptop)

The main dashboard is the **date-window scorecard**: pick a center, pick a date range, and the
13 metrics recompute for that window, each on its own event date. Easy controls so a non-Tableau
user (Kolin, anyone at Iovance) just uses a dropdown and two calendars. Publish to Tableau Cloud
and every viewer gets those controls automatically.

Styling follows the Goal template (`../Goal/`): category grouping down the left, navy header row,
olive category cells. The fixed-column Proposed/Current template tabs are built off
`ppr_scorecard.hyper` per `Tableau build spec.md` - add them as extra tabs after this.

Data source for THIS dashboard: **`ppr_analysis.hyper`** (table `Orders`, order-grain, has the
raw dates). Connect: Tableau Desktop > Connect > To a File > `ppr_analysis.hyper` > drag `Orders`.

---

## 1. Parameters (these become the easy on-screen controls)
- **pStart** - Date, current value 2025-01-01.
- **pEnd** - Date, current value 2026-05-05.
  (Right-click each > Show Parameter. Tableau renders a Date parameter as a calendar picker, so
  the viewer just clicks a From date and a To date. That is the "easy" filter.)

## 2. Center control (the "Select ATC" dropdown, like the Excel)
- Drag **atc** to Filters > keep All for now > OK.
- Right-click the `atc` filter pill > **Show Filter**.
- On the filter card (top-right) click the little dropdown arrow > **Single Value (dropdown)**.
  Now it is a one-center dropdown, exactly like Kolin's "Select ATC".

## 3. The 13 metric calcs (Analysis > Create Calculated Field, paste each)
Every metric filters on ITS OWN event date between pStart and pEnd. `>=`/`<=` are typed normally
in the Tableau editor.

01 Enrollments
COUNTD(IF [enrollment_date] >= [pStart] AND [enrollment_date] <= [pEnd] THEN [order_request__til_order_name] END)

02 Patients Enrolled
COUNTD(IF [enrollment_date] >= [pStart] AND [enrollment_date] <= [pEnd] THEN [iovance_patient_id] END)

03 TTPs Cancelled <=7d
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [ttp_cancel_le7] THEN 1 ELSE 0 END)

04 Completed TTPs
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [completed_ttp] THEN 1 ELSE 0 END)

05 Scheduled TTPs
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [scheduled_ttp] THEN 1 ELSE 0 END)

06 2nd Resections
COUNTD(IF {FIXED [iovance_patient_id] : COUNTD(IF NOT ISNULL([tumor_pickup_date]) AND [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] THEN [tumor_pickup_date] END)} >= 2 THEN [iovance_patient_id] END)

07 Dropouts (health) after TTP
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [dropout_post_ttp_health] THEN 1 ELSE 0 END)

08 OOS Products
SUM(IF [fp_delivery_date] >= [pStart] AND [fp_delivery_date] <= [pEnd] AND [oos_product] THEN 1 ELSE 0 END)

09a Drops after mfg
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [drop_after_mfg] THEN 1 ELSE 0 END)
09b Mfg starts
SUM(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] AND [mfg_started] THEN 1 ELSE 0 END)
09 Patient Progression Rate   (Default Properties > Number Format > Percentage)
[09a Drops after mfg] / [09b Mfg starts]

10 AMTAGVI Infusions Performed
SUM(IF [infusion_date] >= [pStart] AND [infusion_date] <= [pEnd] AND [amtagvi_infused] THEN 1 ELSE 0 END)

11 Days Enrollment -> TTP        (event = TTP pickup)
AVG(IF [tumor_pickup_date] >= [pStart] AND [tumor_pickup_date] <= [pEnd] THEN [days_enroll_to_ttp] END)

12 Days TTP -> Infusion          (event = infusion)
AVG(IF [infusion_date] >= [pStart] AND [infusion_date] <= [pEnd] THEN [days_ttp_to_infusion] END)

13 Days Delivery -> Infusion     (event = infusion)
AVG(IF [infusion_date] >= [pStart] AND [infusion_date] <= [pEnd] THEN [days_delivery_to_infusion] END)

## 4. The worksheet "Scorecard (window)"
- Double-click each of the 13 calcs so they land on Rows via **Measure Values** / **Measure Names**
  (or: drag Measure Names to Rows, Measure Values to Text, then drag the 13 calcs into the Measure
  Values card and remove any extras). Order them 01..13.
- Mark type Text. Each calc keeps its own number format (counts integer, 09 percent, 11/12/13 one
  decimal), so the table reads right with no extra work.
- To match the template's category column, also create a string calc **Metric Group** using a CASE
  over the 13 metric names (Patient Identification & Enrollment / Tumor Tissue Procurement /
  AMTAGVI Regimen / AMTAGVI Treatment Timelines) and put it on Rows to the left of Measure Names.

## 5. Style to the Goal template
- Header row: fill navy `#17344F`, white bold-italic text.
- Category cells: fill olive band `#EAF0E4`, text olive `#4A6B2E`, bold.
- Thin row/column borders. Fit = Entire View.
- Rename the sheet "Scorecard (window)".

## 6. Dashboard "PPR Scorecard" (this is the main one)
- New Dashboard, size 1200 x 850.
- Title text: "P&PR Scorecard".
- Drag in the worksheet.
- Drag the **atc** filter card, the **pStart** control, and the **pEnd** control to a strip across
  the top. Label the strip "Pick a center and a date range".
- Optional Iovance frame: a lime footer band `#9DC13C` with "ADVANCING IMMUNO-ONCOLOGY".

## 7. Two-window compare (optional, reproduces Kolin's YoY slide)
Duplicate the 13 calcs as a "Window B" set that reads **pStartB / pEndB**, add **Difference = B - A**
per metric, and lay the three columns side by side. Set A and B to a slide's two ranges to check
the numbers land close.

## 8. Publish so everyone gets the easy controls
- Server > Sign In (your Tableau Cloud) > Publish Workbook.
- Keep the parameter and filter controls visible. Anyone you grant access to now sees the center
  dropdown and the two date calendars and can drive them with zero Tableau knowledge.

## QA
- [ ] Change the center dropdown - the 13 numbers change.
- [ ] Move pStart / pEnd - the numbers recompute for that window; a window before the data starts
      shows blanks (correct).
- [ ] Counts are whole numbers, Progression Rate is a percent, the three timelines show 1 decimal.
- [ ] Set pStart/pEnd to a Kolin slide's range for that center; numbers land close (exact only if
      the extract is from the same as-of date as the slide).

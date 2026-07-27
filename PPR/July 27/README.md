# P&PR Dashboard - complete build (July 27)

One pipeline, one command. RUN_ALL.py turns the seven Infinity exports into three
native Tableau extracts: the mandated 13-metric P&PR scorecard, the order-grain table,
and an event-level table that powers a draggable date filter. The workbook itself is
built once in Tableau Desktop from these extracts (section 4, ~10 minutes, one time);
afterwards every data refresh is just rerun + Extract > Refresh.

---

## 1. What is in this folder

```
July 27/
  RUN_ALL.py                  run this; executes the whole pipeline in order
  README.md                   this file
  pipeline/
    build_analysis_table.py   joins the 7 Infinity .xlsx into one order-grain table
    build_scorecard.py        computes the 13 metrics for every center and benchmark
    build_datewindow.py       one row per metric event with its own event date
    build_hyper.py            writes the three native Tableau .hyper extracts
    build_center_decks.py     one P&PR PowerPoint per center (Launch-to-Date + YoY)
  analysis/                   pipeline outputs (CSV) - regenerated on every run
  tableau/                    ppr_scorecard.hyper (Scorecard), ppr_analysis.hyper
                              (Orders), ppr_datewindow.hyper (Events)
  decks/                      one .pptx per center, ready to present
```

## 2. One-time setup (office laptop)

1. Install Python 3.9+ (check: `python --version`).
2. `pip install pandas numpy openpyxl pantab`
3. Have Tableau Desktop installed and licensed.
4. Create a `data/` folder next to `RUN_ALL.py` and drop the seven Infinity
   exports in it, filenames containing: `bai_list_of_orders`, `bai_infusion`,
   `bai_slot_data`, `bai_ttp_data`, `bai_tumor_documentation`,
   `veeva_call_activity`, `veeva_komodo_atc_mapping` (all `.xlsx`).
   Real data stays on the office laptop; only code travels through git.

## 3. Run the pipeline

```
python RUN_ALL.py
```
Input is found automatically, first match wins: the `PPR_INPUT_DIR` env var if
set, then the `data/` folder next to `RUN_ALL.py`, then the synthetic sample
(dev only). The first line of output says which input it picked - check it.

The run prints each stage and ends with the three extracts written. Rerunning is
always safe; every output is rebuilt from scratch. Close Tableau Desktop first, it
locks the .hyper files.

## 4. Build the workbook in Tableau Desktop (one time, about 15 minutes)

You will do two things: refresh the old scorecard numbers, then add one new sheet
with the date slider. Follow in order. Each step says what you should see, so you
know it worked before moving on.

### Part A. Refresh the scorecard numbers (2 minutes)

1. Open Tableau Desktop.
2. File > Open > your existing workbook (the one with the P&PR Scorecard sheet,
   e.g. `up.twb` in the tableau folder).
3. Click the Data menu at the top. You will see your data source name in the list,
   something like "ppr_scorecard Extract".
4. Hover over that name. In the submenu, click Refresh. If Refresh is greyed out,
   in the same submenu go to Extract > Refresh instead.
5. If a file picker opens asking where the file is, browse to the `tableau` folder
   and pick `ppr_scorecard.hyper`.
6. Check it worked: open the P&PR Scorecard sheet, look at "AMTAGVI Infusions
   Performed". The 2024/2025 numbers should have changed from before. That is the
   corrected event dating coming through.

### Part B. Connect the new date-window data (2 minutes)

7. Data menu > New Data Source.
8. Under "To a File", click More..., then browse to the `tableau` folder and pick
   `ppr_datewindow.hyper`.
9. A canvas opens showing one table named Events. If it is not already on the
   canvas, drag Events onto it.
10. Check it worked: at the bottom left you should see columns named center,
    metric_group, metric, metric_order, agg, event_date, value.

### Part C. Build the Custom Date Window sheet (7 minutes)

11. Click the new-worksheet icon at the bottom (next to the sheet tabs). Rename the
    new sheet: right-click its tab > Rename > type `Custom Date Window`.
12. Make sure the left Data pane shows the NEW source (ppr_datewindow / Events).
    If not, click its name at the top of the Data pane.
13. Drag `metric_group` from the left pane onto the Rows shelf.
14. Drag `metric_order` onto the Rows shelf, to the RIGHT of metric_group.
    It will land as a green pill. Right-click that green pill and click Discrete.
    It turns blue. Then right-click the same pill again and untick Show Header.
    (It exists only to keep the metrics in template order. Hiding the header just
    hides the number column; the sorting still works.)
15. Drag `metric` onto the Rows shelf, to the RIGHT of metric_order.
16. Analysis menu > Create Calculated Field. In the name box type exactly:
        Keep Center
    In the formula box type exactly:
        [center] = [pCenter]
    Click OK. (pCenter is the same dropdown parameter your scorecard already uses,
    so one dropdown will drive both sheets.)
17. Drag `Keep Center` from the left pane onto the Filters shelf. A small dialog
    opens with True and False. Tick True. Click OK.
18. Analysis menu > Create Calculated Field. Name it exactly:
        Result
    Formula, copy it exactly as written:
        IF ATTR([agg]) = "rate" THEN STR(ROUND(AVG([value]) * 100, 1)) + "%"
        ELSEIF ATTR([agg]) = "avg" THEN STR(ROUND(MEDIAN([value]), 1))
        ELSE STR(INT(SUM([value]))) END
    Click OK. No red error text should appear under the formula box.
19. Drag `Result` onto the Text box in the Marks card (middle-left of the screen).
    Numbers appear in the table. Counts show as whole numbers, the progression
    rate as a percent, the three timing rows with one decimal.
20. Drag `event_date` onto the Filters shelf. In the dialog pick Range of Dates,
    click Next if shown, then OK.
21. Right-click the event_date pill on the Filters shelf > Show Filter. A slider
    card with two handles appears on the right side of the sheet.
22. Test it now, before the dashboard: drag the left handle right and the right
    handle left. Every number in the table should change as you drag. Drag both
    handles back to the ends when done.
23. Optional look: Format menu > Shading > under Header pick the dark navy
    (#17344F). White bold header font via Format > Font > Header.

### Part D. Put it on the dashboard (3 minutes)

24. Open your existing dashboard tab (or Dashboard menu > New Dashboard,
    size 1400 x 850).
25. Drag `Custom Date Window` from the Sheets list on the left onto the dashboard,
    next to the scorecard.
26. If the date slider card did not come along: click the Custom Date Window sheet
    on the dashboard, click the small dropdown arrow at its top-right corner, then
    Filters > event_date. The slider card appears on the right rail.
27. Same check for the center dropdown: if it is not visible, click either sheet,
    dropdown arrow > Parameters > pCenter.
28. Title bands if you want the house look: two Text objects, top one reads
    IOVANCE | P&PR Scorecard (white text, navy #17344F background), bottom one
    reads ADVANCING IMMUNO-ONCOLOGY (navy text, lime #9DC13C background).
29. File > Save. Done. You never rebuild any of this again; from now on it is
    only data refreshes (section 8).

### If something does not match

Stop at the step where your screen differs and check: are you on the right data
source (step 12)? Is the pill blue where it should be discrete (step 14)? Is the
formula copied exactly, straight quotes not curly (steps 16 and 18)? If it still
does not match, take a photo of the screen and send it.

## 4b. The per-center decks (generated automatically)

Every run also writes one PowerPoint per center to `decks/`, named
`<Center Name> - P&PR Review.pptx`. Two slides, Iovance styled:

- Slide 1 "Launch-to-Date Metrics": the center's 13 metrics next to the Top 10,
  Top 40 and 'New' tier medians.
- Slide 2 "Year over Year Metrics at ATC": 2025 vs 2026 YTD with a Difference
  column, green when the change is an improvement, red when it is not
  (the direction is flipped for metrics where lower is better).

To regenerate only the centers you need for a meeting:

```
python pipeline/build_center_decks.py "Moffitt" "Yale"
```

Names are matched loosely, so part of the name is enough. Open the file, adjust
the talk track if you want, present. No manual number entry anywhere.

## 5. How to use it (what Kolin does)

- Pick a center in the dropdown: both tables switch to that center. Benchmarks stay fixed.
- Drag the two ends of the Event Date slider: every metric in the Custom Date Window
  recomputes for exactly that range. Set Jan 1 2025 - Sep 30 2025 vs Oct 1 2025 - May 5
  2026 to reproduce a Year-over-Year deck for any center.
- No Tableau knowledge needed beyond the dropdown and the slider.

## 6. Publish for the team (optional)

Server menu > Publish Workbook (needs a Tableau Cloud/Server site login). Keep only the
dashboard visible. Everyone with access gets the same dropdown and slider in the
browser; nothing else to configure.

## 7. Metric definitions (fixed, do not drift)

The 13 metrics follow the (Proposed) P&PR Metrics template plus Kolin's Meet 6
definitions. Every metric is counted on its own event date, matching the real
per-center decks ("timing metrics based upon the TTP or Infusion Date"):

| # | Metric | Event date | Aggregation |
|---|--------|-----------|-------------|
| 1 | Enrollments in IovanceCares | enrollment | count |
| 2 | Patients Enrolled in IovanceCares | first enrollment per patient | count |
| 3 | TTPs Cancelled or Rescheduled within 7 Days | TTP pickup | count |
| 4 | Completed TTPs | TTP pickup | count |
| 5 | Scheduled TTPs | TTP pickup | count |
| 6 | 2nd Resections | 2nd TTP pickup per patient | count |
| 7 | Patient Related Drop-outs (health, post-TTP) | TTP pickup | count |
| 8 | OOS Products | final product delivery | count |
| 9 | Patient Progression Rate | TTP pickup | drop-offs after mfg start / mfg starts |
| 10 | AMTAGVI Infusions Performed | infusion | count |
| 11 | Avg Time Enrollment to TTP (days) | TTP pickup | median, 1 dp |
| 12 | Avg Time TTP to Infusion (days) | infusion | median, 1 dp |
| 13 | Avg Time Final Product Delivery to Infusion (days) | infusion | median, 1 dp |

Timing rows are medians, not averages. Kolin, Meet 6, on the existing Infinity
scorecard: "what it shows you is essentially, like, the median for all these
values." Medians also resist the big-center skew he flagged in Meet 4.5. The
column headers still read "Average Time ..." because that is the wording in the
mandated template; the number underneath is a median.

Because of event dating, Launch-to-Date does NOT have to equal 2024+2025+2026 for a
metric (events missing a date sit in Launch-to-Date only). That is correct behavior.

Known proxies until better feeds land: metric 3 needs Infinity snapshot history to be
exact; the "New" benchmark tier needs each center's onboarding year. Both are flagged
in `build_analysis_table.py`.

## 8. Refresh cadence

New Infinity export -> drop the 7 files in `data/` -> close Tableau ->
`python RUN_ALL.py` -> open the workbook > Data > each source > Extract > Refresh.
Numbers update; the workbook never changes.

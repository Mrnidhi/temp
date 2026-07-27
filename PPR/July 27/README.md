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
  analysis/                   pipeline outputs (CSV) - regenerated on every run
  tableau/                    ppr_scorecard.hyper (Scorecard), ppr_analysis.hyper
                              (Orders), ppr_datewindow.hyper (Events)
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

## 4. Build the workbook in Tableau Desktop (one time, ~10 minutes)

Start from the existing workbook that already has the P&PR Scorecard sheet and the
pCenter parameter (the one built from ppr_scorecard Extract). Two moves: refresh the
old data, add the date-window sheet.

A. Refresh the scorecard numbers
1. Open the workbook. Data > ppr_scorecard Extract > Extract > Refresh
   (point it at `tableau/ppr_scorecard.hyper` if it asks). Numbers update to the
   corrected event-dated values. Done with this part.

B. Add the Custom Date Window sheet
2. Data > New Data Source > More... > `tableau/ppr_datewindow.hyper` > table `Events`.
3. New worksheet, name it `Custom Date Window`.
4. Drag `metric_group`, then `metric_order`, then `metric` to Rows (that order).
   Right-click the metric_order pill > uncheck Show Header.
5. Analysis > Create Calculated Field, name `Keep Center`:
       [center] = [pCenter]
   Drag it to Filters, tick True.
6. Analysis > Create Calculated Field, name `Result`:
       IF ATTR([agg]) = "rate" THEN STR(ROUND(AVG([value]) * 100, 1)) + "%"
       ELSEIF ATTR([agg]) = "avg" THEN STR(ROUND(AVG([value]), 1))
       ELSE STR(INT(SUM([value]))) END
   Drag `Result` onto the Text mark.
7. Drag `event_date` to Filters > Range of Dates > OK. Right-click the filter pill >
   Show Filter. The slider card appears - that is the date window control.
8. Format > Shading > Header: navy #17344F, white bold font (matches house style).

C. Dashboard
9. Open the existing dashboard (or new one, 1400 x 850). Drag `Custom Date Window`
   next to the scorecard sheet.
10. The pCenter dropdown already controls both sheets (same parameter). Keep the
    Event Date slider card on the right rail.
11. Add a top Text object: IOVANCE | P&PR Scorecard, white text on navy #17344F fill;
    bottom Text object: ADVANCING IMMUNO-ONCOLOGY on lime #9DC13C fill.
12. Save. This workbook is the deliverable; you never rebuild it again.

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
| 11 | Avg Time Enrollment to TTP (days) | TTP pickup | mean, 1 dp |
| 12 | Avg Time TTP to Infusion (days) | infusion | mean, 1 dp |
| 13 | Avg Time Final Product Delivery to Infusion (days) | infusion | mean, 1 dp |

Because of event dating, Launch-to-Date does NOT have to equal 2024+2025+2026 for a
metric (events missing a date sit in Launch-to-Date only). That is correct behavior.

Known proxies until better feeds land: metric 3 needs Infinity snapshot history to be
exact; the "New" benchmark tier needs each center's onboarding year. Both are flagged
in `build_analysis_table.py`.

## 8. Refresh cadence

New Infinity export -> drop the 7 files in `data/` -> close Tableau ->
`python RUN_ALL.py` -> open the workbook > Data > each source > Extract > Refresh.
Numbers update; the workbook never changes.

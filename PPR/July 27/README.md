# P&PR Dashboard - complete build (July 27)

One pipeline, one command, one finished Tableau workbook. Run RUN_ALL.py against the
seven Infinity exports and it produces `PPR Dashboard.twbx`: the mandated 13-metric
P&PR scorecard plus a custom date-window view, with a center dropdown and a draggable
date slider on a single Iovance-styled dashboard.

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
    build_hyper.py            native Tableau .hyper extracts (for repointing/refresh)
    gen_workbook.py           authors the finished PPR Dashboard.twbx
  analysis/                   pipeline outputs (CSV) - regenerated on every run
  tableau/                    .hyper extracts - regenerated on every run
  PPR Dashboard.twbx          the deliverable (appears here after a run)
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

The run prints each stage. It ends with `wrote PPR Dashboard.twbx (... centers)`.
Rerunning is always safe; every output is rebuilt from scratch.

## 4. Open and finish in Tableau Desktop (5 minutes)

1. Double-click `PPR Dashboard.twbx`. The "P&PR Dashboard" tab opens with:
   - left: the P&PR Scorecard matrix (Launch to Date, 2024, 2025, 2026 YTD,
     Top 10 / Top 40 / New benchmarks, quarterly columns)
   - middle: the Custom Date Window table
   - right: the center dropdown (pCenter) and the Event Date range slider
2. If a sheet opens blank, click its tab, then Data menu > each source >
   Extract > Refresh once. Save.
3. Cosmetic pass (Tableau strips some hand-authored formatting on first open):
   - On each sheet: Format > Shading > Header = navy `#17344F`, header font white bold.
   - Dashboard title band should read navy with white text; bottom band lime `#9DC13C`
     with navy text. Fix via the two Text objects if needed.
   - On the Custom Date Window sheet, right-click the `metric_order` row header >
     uncheck Show Header (it exists only to keep metrics in template order).
4. Save. This file is the deliverable.

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

New Infinity export -> drop the 7 files in the input folder -> `python RUN_ALL.py` ->
reopen the .twbx (or Extract > Refresh if you built extracts on the .hyper files).
Numbers update; nothing else changes.

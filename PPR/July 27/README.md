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
  SETUP - do this.md   start here; setup and every run step, in order
  README.md                    this file
  RUN_ALL.py                   run this; executes the whole pipeline in order
  requirements.txt             pip install -r this first
  metric3_cancellations.py     standalone metric-3 sanity check on the snapshot history
  ONE DASHBOARD - Tableau build.md   the Tableau build recipe (one time)
  data/                        drop the 7 Infinity exports (+ hist) here; gitignored, see data/README.md
  pipeline/
    metrics.py                 the 13 metric names, groups and event dates - one definition
    cancellations.py           the 7-day cancellation rule - one definition, shared
    build_analysis_table.py    step 1: joins the 7 Infinity .xlsx into one order-grain table
    build_cancellations.py     step 2: counts metric 3 from the snapshot history
    build_scorecard.py         step 3: computes the 13 metrics for every center + benchmark
    build_datewindow.py        step 4: one row per metric event with its own event date
    build_hyper.py             step 5: writes the three native Tableau .hyper extracts
    build_dashboard_html.py    step 6: renders the standalone browser scorecard
    baseline.py                freeze / diff, to prove a change moved only what it should
  tableau/                     README + the 3 .hyper extracts (regenerated each run)
  analysis/ dashboard/ baseline/   pipeline outputs, regenerated every run
```

The `data/`, `analysis/`, `dashboard/`, `baseline/` folders and the `.hyper` extracts are
gitignored: all regenerable in one command, and all holding real patient rows once the
pipeline runs on real data. Only source (code + docs) is committed.

## 2. One-time setup

1. Install Python 3.9+ (check: `python --version`).
2. `pip install -r requirements.txt`
3. Have Tableau Desktop installed and licensed.
4. Create a `data/` folder next to `RUN_ALL.py` and drop the seven Infinity
   exports in it, filenames containing: `bai_list_of_orders`, `bai_infusion`,
   `bai_slot_data`, `bai_ttp_data`, `bai_tumor_documentation`,
   `veeva_call_activity`, `veeva_komodo_atc_mapping` (all `.xlsx`).
   Real data never goes into git; only code is committed.

## 3. Run the pipeline

```
python RUN_ALL.py
```
Input is found automatically, first match wins: the `PPR_INPUT_DIR` env var if
set, then the `data/` folder next to `RUN_ALL.py`, then the test sample
(dev only). The first line of output says which input it picked - check it.

The run prints each stage and ends with the three extracts written. Rerunning is
always safe; every output is rebuilt from scratch. Close Tableau Desktop first, it
locks the .hyper files.

## 4. Build the workbook in Tableau Desktop (one time, about 10 minutes)

One data source, one worksheet, one dashboard. Full click-by-click steps are in
**`ONE DASHBOARD - Tableau build.md`**, next to this file. Follow that, not this
section.

In short: connect `tableau/ppr_datewindow.hyper` (table `Events`), make three
parameters (pCenter, pStart, pEnd) and three calculated fields (Keep Center,
Keep Row, Result), put `col_label` on Columns and `metric` on Rows.

That single sheet renders the whole scorecard **and** answers a custom date range,
so there is no second sheet and no second data source to keep in step.

`tableau/ppr_scorecard.hyper` is still written on every run, but it is not what the
dashboard reads. It is the reference the event table gets checked against.

A per-center PowerPoint stage (build_center_decks.py) used to run here. Removed
2026-07-28: the dashboard already shows any center for any window, so the reviewer filters
and screenshots what he needs directly. Recoverable from this repo's history.

## 5. How to use it

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

The 13 metrics follow the (Proposed) P&PR Metrics template plus the manager walkthrough
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

Timing rows are medians, not averages. Confirmed verbally against the existing Infinity
scorecard: "what it shows you is essentially, like, the median for all these
values." Medians also resist the big-center skew the manager flagged earlier. The
column headers still read "Average Time ..." because that is the wording in the
mandated template; the number underneath is a median.

Because of event dating, Launch-to-Date does NOT have to equal 2024+2025+2026 for a
metric (events missing a date sit in Launch-to-Date only). That is correct behavior.

Metric 3 now counts real cancellations from the Infinity snapshot history when the
`bai_list_of_orders_hist` export is in `data/` (step 2, `build_cancellations.py`); without
that file it falls back to a proxy and the run still completes. The "New" benchmark tier
still needs each center's onboarding year (flagged in `build_analysis_table.py`).

## 8. Refresh cadence

New Infinity export -> drop the 7 files in `data/` -> close Tableau ->
`python RUN_ALL.py` -> open the workbook > Data > each source > Extract > Refresh.
Numbers update; the workbook never changes.

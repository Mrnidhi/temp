# P&PR pipeline - data lineage

What this builds, in the order it runs. Written so the code can be ported with minimum change.

Six Python stages. Only `pandas` and `numpy`, plus `pantab` for the final Tableau extract.
One command runs all six: `python RUN_ALL.py`.

## Sources

Six tables out of Infinity. Four build the order table, two carry the cancellation metric.

| Table | Role |
|---|---|
| `bai_list_of_orders` | the hub, one row per TIL order |
| `bai_infusion` | infusion date and the infused flag |
| `bai_tumor_documentation` | tumour procurement rows per order |
| `veeva_komodo_atc_mapping` | region, territory, segment per centre |
| `LTD_Reschedules` | one row per change to a booked TTP date |
| `LTD_Cancellations` | one row per cancelled TTP |

`bai_slot_data` is optional and drives no metric.

## The six stages

**1. `build_analysis_table.py`**
Joins the four order tables into one order-grain table. Derives every flag the metrics need,
assigns the ATC tier by ranking centres on enrolment count, and sets the as-of date.
Out: `analysis/ppr_analysis.csv`, one row per order.

**2. `build_cancellations.py`**
Reads the two LTD tables and applies the 7 day rule: when a booked pickup date moves or is
cleared with 0 to 7 days notice, the slot is counted as lost. Each event is dated on the slot
that was lost, not on the day the change was entered. Neither LTD table carries a centre, so
the order id joins back to stage 1.
Out: `analysis/ppr_cancellations.csv`, one row per lost slot.

**3. `build_scorecard.py`**
Computes the 13 metrics for every centre across every time column, plus the tier medians that
form the benchmark columns.
Out: `analysis/ppr_scorecard_tidy.csv`.

**4. `build_datewindow.py`**
Emits one row per event, tagged with every column that event belongs to, so a date filter
recomputes any window without a pipeline rerun. Adds the benchmark rows and the cell shading.
Out: `analysis/ppr_datewindow_long.csv`. **This is the table that matters.**

**5. `build_hyper.py`**
Writes the Tableau extracts. `ppr_datewindow.hyper` is the one the dashboard reads.

**6. `build_dashboard_html.py`**
A standalone browser view of the same numbers. Useful for checking, not part of the served
path. Safe to drop when porting.

## Shared modules

`metrics.py` holds the 13 metric definitions in one place, imported by every stage, so a name
or a rule cannot drift between them. `cancellations.py` holds the 7 day rule, imported by
stage 2 and by the standalone audit script.

## Things worth keeping when this is ported

**The as-of date comes from the data, never the clock.** It is the newest order creation date
in the extract. The same inputs give the same outputs on any day, and the date is recorded in
every output file.

**Assertions gate the build.** They are not tests run separately; they stop the run:

- period columns plus Undated plus After as-of must equal Launch to Date, per centre per metric
- the event table reconciles against the precomputed scorecard cell by cell
- every cancellation reason maps to a known category, or the run names it
- every completed TTP is also counted as scheduled
- the lost-slot funnel adds back to rows in

Losing these would mean a wrong number could ship silently, which is the failure mode this was
built to avoid.

**Each metric is counted on its own event date.** Enrolments on the enrolment date, TTP metrics
on the pickup date, out-of-spec products on the delivery date, infusions and timings on the
infusion date. Not a single cohort date across the board.

## If it becomes SQL

Most of the 13 metrics are counts and medians with a date filter, so they translate directly.
The two that look procedural are not: the 7 day rule is a `LAG` over the snapshot history, and
the Top 10 and Top 40 tiers are a `RANK` over enrolment counts.

The cell-by-cell reconciliation in stage 4 is the natural migration test. Move one metric at a
time and check it against the Python output before moving the next.

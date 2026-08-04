# P&PR - transformation logic and sample output

    pipeline/       the transformation
    sample/         the file it produces
    source files/   the two source files that are not in Redshift

## What it produces

One file. `ppr_events.csv`, rebuilt in full on every run. Tableau reads that and
nothing else.

Everything the pipeline writes into `work/` along the way is intermediate and
can be deleted.

## Sources

Four come from the BI tables already in Redshift:

    bai_list_of_orders          the base, one row per order
    bai_tumor_documentation     one row per tissue procurement
    bai_infusion                one row per infused order
    veeva_komodo_atc_mapping    one row per treatment centre

Two do not. They are uploaded files, and they are in `source files/`:

    LTD_Reschedules             one row per change to a booked slot
    LTD_Cancellations           one row per cancelled slot

Those two carry one metric on their own, the count of procurement slots given up
with seven days notice or less. Without them the pipeline falls back to a weaker
proxy and records that it did so, rather than failing quietly.

## Running it

    pip install -r requirements.txt
    # put the six source files in pipeline/data/
    python RUN_ALL.py

The output lands next to `RUN_ALL.py` as `ppr_events.csv`.

`pipeline/data/` ships empty on purpose. It is where the source files go, and
nothing in it is part of the handover.

## The five stages

    build_analysis_table.py   reads the sources, builds one row per order,
                              derives the flags the metrics need
    build_cancellations.py    the seven day lost slot rule
    build_scorecard.py        the 13 metrics per centre per column
    build_datewindow.py       reshapes into the event-level table
    build_final_table.py      writes ppr_events.csv

    metrics.py                the 13 metric names, groups and event dates
    cancellations.py          the lost slot rule, shared by two stages
    baseline.py               freeze and diff, to confirm a change moved nothing

The run stops at the first stage that fails.

## Two checks run inside the pipeline

Stage 3 requires the period columns to add back to the launch-to-date column for
every centre and every additive metric.

Stage 4 re-aggregates the event table it just built and compares every cell
against the scorecard computed separately in stage 3.

Either failing stops the run before the output is written.

## Two things about the output

It has no unique key and should not have one. Each event is written once per
scorecard column it belongs to, so identical looking rows are real. Do not
deduplicate it.

Rows with a blank `event_date` are real events that have no date. They belong in
the table; dropping them makes every period column look better than it was.

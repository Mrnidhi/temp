# Reference pipeline, as it runs today

These are the exact python files behind the current dashboard numbers, included
so the data engineering team can read the working transformation next to the
handoff documents. The Glue job in ../glue/ must reproduce what these produce;
the reconciliation and additivity gates inside them define what counts as equal.

## Where this runs today

Office laptop, in PowerShell:

    cd "C:\Users\SGowda\OneDrive - Iovance Biotherapeutics\Desktop\PPR Automation\VS Code"
    python RUN_ALL.py

The Infinity exports sit in data\ next to RUN_ALL.py. If the default python is
3.13 or newer and pip cannot build pandas or pantab, use py -3.12.

## What is what

- RUN_ALL.py runs the six stages in order and stops at the first failure
- pipeline\build_analysis_table.py builds the order master (one row per order)
- pipeline\build_cancellations.py counts the metric 3 lost slot events
- pipeline\cancellations.py holds the single 7 day rule both sources share
- pipeline\build_scorecard.py computes the 13 metrics and the benchmarks
- pipeline\build_datewindow.py builds the Events table Tableau reads
- pipeline\build_hyper.py writes the Tableau extracts (not needed once Tableau
  reads ppr_events from Redshift)
- pipeline\build_dashboard_html.py renders the standalone preview (same story)
- pipeline\metrics.py holds the metric names, groups and event date mapping
- pipeline\baseline.py freezes a reference run and diffs any later run against it

In the target architecture the same transformation runs inside the Glue job
from the raw Redshift tables; these files stay as the reference and as the
office fallback until cutover.

# PPR handoff

The full pipeline is included. Point it at the same source-export folder used by the approved
LTD-only run, then run:

```bash
PPR_INPUT_DIR=/path/to/source_exports python "PPR/July 27/RUN_ALL.py"
```

It produces `PPR/July 27/ppr_events.csv`, the analysis-ready output. The runner needs the four
order-level exports plus `LTD_Reschedules` and `LTD_Cancellations`. It stops when a required
file is missing or invalid.

`build_ltd_metric3_csv.py` is also included when a standalone Metric 3 event CSV is needed. It is
not required for the full `RUN_ALL.py` execution.

For validation, use the same input exports and as-of date as the approved LTD-only run. Compare
the resulting analysis-ready table with the approved output. The column order, row count, and
row-level values must all match. History is not an input or fallback.

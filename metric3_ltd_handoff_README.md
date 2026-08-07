# Metric 3 LTD handoff

Run the two SQL files separately in the source that contains the corresponding LTD table. Export
each result as a CSV, then run:

```bash
python build_ltd_metric3_csv.py \
  --reschedules LTD_Reschedules.csv \
  --cancellations LTD_Cancellations.csv \
  --as-of-date YYYY-MM-DD \
  --output ltd_metric3_events.csv
```

Use the generated CSV as the Metric 3 input to the existing pipeline.

For validation, use the same two LTD extracts and as-of date as the approved LTD-only run. Compare
the resulting analysis-ready table with the approved output. The column order, row count, and
row-level values must all match. Do not use history as an input or fallback.

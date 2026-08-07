# Message for Vinay

Hi Vinay — I checked both cancellation sources. The 65 days is a data-coverage gap, not two
different logics. LTD has records starting 3-Aug-2024, but the history table starts only on
7-Oct-2024. In between, LTD has 32 cancellation rows for 31 orders and history has no rows.

So I’m keeping this simple: Metric 3 will come only from the LTD cancellation and reschedule
tables. They will create one CSV with the actual lost-slot events. We will keep the history table
only for old-data checks; it will not be used as a fallback or added to LTD, so we do not create
duplicates or infer events from snapshots.

For the full Metric 3 file, both LTD exports are needed. If one is missing, the process stops
instead of quietly giving us a partial number.

## Endpoint command

```bash
python build_ltd_metric3_csv.py \
  --reschedules /path/LTD_Reschedules.csv \
  --cancellations /path/LTD_Cancellations.csv \
  --as-of-date 2026-08-07 \
  --output /path/ltd_metric3_events.csv
```

The script gives one clean CSV, keeps the input file and as-of date on each row, and stops when
something important is missing or invalid.

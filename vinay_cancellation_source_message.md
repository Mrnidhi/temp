# Message for Vinay

Hi Vinay — I put together a small package with two separate LTD extraction queries and the
Metric 3 CSV endpoint.

Could you test it with the same LTD exports and as-of date used by the current approved
LTD-only process? Run each extraction query separately, export both results, and run the command
below. Then send the generated CSV through the existing flow and compare the final
analysis-ready table with the current LTD-only output.

If the column order, row count, and row-level values all match, we can use this optimised flow.
The history table is intentionally not part of this test or a fallback source.

Both LTD exports are required. The endpoint stops if either export is missing or invalid, rather
than producing a partial Metric 3 file.

## Run command

```bash
python build_ltd_metric3_csv.py \
  --reschedules /path/LTD_Reschedules.csv \
  --cancellations /path/LTD_Cancellations.csv \
  --as-of-date 2026-08-07 \
  --output /path/ltd_metric3_events.csv
```

The generated CSV is the Metric 3 input; the existing pipeline still produces the final
analysis-ready table.

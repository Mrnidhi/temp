# Message for Vinay

Hi Vinay — I investigated the apparent 65-day cancellation gap and put together a complete
runnable PPR package, including the full transformation logic and `RUN_ALL.py`.

What I found:

- Measured: LTD starts recording on 3-Aug-2024, while `bai_list_of_orders_hist` starts on
  7-Oct-2024. This is a 65-day coverage gap, not two competing cancellation logics.
- Measured: in that 3-Aug-to-6-Oct window, LTD has 32 cancellation rows across 31 orders; the
  history query returns zero rows.
- Measured: LTD has 575 cancellation rows across 528 orders overall, and 245 rows meet the
  existing short-notice condition.
- Measured: history contains 12,361 snapshots across 1,295 orders and begins only after the
  gap. It is snapshot history, so using it to fill the gap would infer events and could duplicate
  the direct LTD events.

The decision in the package is therefore simple: Metric 3 uses only `LTD_Reschedules` and
`LTD_Cancellations`. History is retained only for archive/reconciliation checks; it is not used as
an analytics input or a fallback.

Could you test the package with the same source exports and as-of date used by the current
approved LTD-only process? Run the full flow below and compare the resulting analysis-ready table
with the current LTD-only output. If the column order, row count, and row-level values all match,
we can use this optimised flow.

The four order-level exports plus both LTD exports are required. The pipeline stops if any
required input is missing or invalid, rather than producing a partial result.

## Run command

```bash
PPR_INPUT_DIR=/path/to/source_exports python "PPR/July 27/RUN_ALL.py"
```

The final output is `PPR/July 27/ppr_events.csv`. The standalone Metric 3 CSV endpoint is also
included if it is useful separately, but it is not needed to run the full flow.

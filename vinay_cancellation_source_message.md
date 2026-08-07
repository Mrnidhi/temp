# Message for Vinay

Hi Vinay — I have shared the new PPR flow. It includes the full code, `RUN_ALL.py`, and a README
file for reference.

Measured: LTD starts on 3-Aug-2024, while the history table starts on 7-Oct-2024 and has no rows
in between. So this is a missing-history period, not different cancellation logic.

Measured: Metric 3 uses only `LTD_Reschedules` and `LTD_Cancellations`. History is not used as
an input or fallback.

Could you run it with the same source exports used for the current LTD-only process and compare
the final `ppr_events.csv` with the current output? If the columns, row count, and values are the
same, we can use this version. The process stops if a required input is missing.

## Run command

```bash
PPR_INPUT_DIR=/path/to/source_exports python "PPR/July 27/RUN_ALL.py"
```

The final output is `PPR/July 27/ppr_events.csv`.

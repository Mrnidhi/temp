# data/ - input folder (never committed)

Put the Infinity exports here as `.xlsx` or `.csv`. Everything in this folder except this
README is gitignored, so real patient data cannot be committed by accident.

The filename only has to *contain* the text in backticks, so `BAI - List of Orders 07.28.xlsx`
matches `bai_list_of_orders`.

## Required

| filename contains          | Infinity source              | what needs it |
|----------------------------|------------------------------|---------------|
| `bai_list_of_orders`       | BAI List of Orders           | the hub; 9 of 13 metrics |
| `bai_tumor_documentation`  | BAI Tumor Documentation      | second resections, `has_tumor` |
| `bai_infusion`             | BAI Infusion                 | metrics 10, 12, 13 |
| `veeva_komodo_atc_mapping` | Veeva / Komodo ATC mapping   | region, territory, segment |

## Required for metric 3

Both, from the uploaded-files layer in the query explorer. Together they are the complete
population of short-notice lost slots, current to the present.

| filename contains   | Infinity source     | grain |
|---------------------|---------------------|-------|
| `ltd_reschedules`   | `LTD_Reschedules`   | one row per change to a booked TTP date |
| `ltd_cancellations` | `LTD_Cancellations` | one row per cancelled TTP |

Neither carries a centre, so stage 2 joins them to the order table on the order id.

Without them, stage 2 falls back to walking `bai_list_of_orders_hist` if that file is present,
and to the `resection_rescheduled_` proxy if it is not. Either fallback still completes the
run, and the source used is printed and recorded in `analysis/run_meta.json`.

## Optional

| filename contains | why it is optional |
|-------------------|--------------------|
| `bai_slot_data`   | produces `has_slot`, which reaches the Tableau extract but drives no metric. Diagnostic only |

## No longer needed

| filename contains         | why |
|---------------------------|-----|
| `bai_list_of_orders_hist` | superseded by the two LTD exports, which start two months earlier and run to the present |
| `bai_ttp_data`            | no stage reads it |
| `veeva_call_activity`     | no stage reads it |

Then, from the `July 27` folder:

```
python RUN_ALL.py
```

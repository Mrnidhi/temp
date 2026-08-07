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

Both, from the uploaded-files layer in the query explorer. Together they are the only
per-event inputs for metric 3.

| filename contains   | Infinity source     | grain |
|---------------------|---------------------|-------|
| `ltd_reschedules`   | `LTD_Reschedules`   | one row per change to a booked TTP date |
| `ltd_cancellations` | `LTD_Cancellations` | one row per cancelled TTP |

Neither carries a centre, so stage 2 joins them to the order table on the order id.

Stage 2 stops if either export is missing. `bai_list_of_orders_hist` is archive-only snapshot
evidence: it must not be used as a fallback or unioned with LTD events. The
`resection_rescheduled_` order-level flag is also not a substitute for metric 3.

## Optional

| filename contains | why it is optional |
|-------------------|--------------------|
| `bai_slot_data`   | produces `has_slot`, which reaches the Tableau extract but drives no metric. Diagnostic only |

## Archive-only / no pipeline use

| filename contains         | why |
|---------------------------|-----|
| `bai_list_of_orders_hist` | retained only for one-time history/reconciliation checks; no analytics stage reads it |
| `bai_ttp_data`            | no stage reads it |
| `veeva_call_activity`     | no stage reads it |

Then, from the `July 27` folder:

```
python RUN_ALL.py
```

# data/ - input folder (never committed)

Put the Infinity exports here as `.xlsx`. Everything in this folder except this README is
gitignored, so real patient data cannot be committed by accident.

**Required** (the 7 exports; the filename only has to *contain* the text in backticks,
so `BAI - List of Orders 07.28.xlsx` matches `bai_list_of_orders`):

| filename contains          | Infinity report              |
|----------------------------|------------------------------|
| `bai_list_of_orders`       | BAI List of Orders           |
| `bai_infusion`             | BAI Infusion                 |
| `bai_slot_data`            | BAI Slot Data                |
| `bai_ttp_data`             | BAI TTP Data                 |
| `bai_tumor_documentation`  | BAI Tumor Documentation      |
| `veeva_call_activity`      | Veeva Call Activity          |
| `veeva_komodo_atc_mapping` | Veeva / Komodo ATC mapping   |

**Optional**, for the real metric 3 (TTPs cancelled or rescheduled within 7 days). Without
it, metric 3 falls back to a proxy and the run still completes:

| filename contains          | Infinity report              |
|----------------------------|------------------------------|
| `bai_list_of_orders_hist`  | BAI List of Orders (history) |

Stage 2 (`build_cancellations.py`) picks up the `hist` file automatically. Then, from the
`July 27` folder:

```
python RUN_ALL.py
```

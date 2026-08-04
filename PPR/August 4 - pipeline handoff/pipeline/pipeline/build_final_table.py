"""
PPR pipeline - Stage 5: write the final table.

The one output of this pipeline. Tableau reads this file and nothing else. Written in the
exact column order of the reporting table, so it also loads straight into Redshift.

Everything in work/ is intermediate and can be deleted after a run.

In:  work/ppr_datewindow_long.csv
Out: ppr_events.csv
"""
import os

import pandas as pd

HERE = os.path.dirname(__file__)
WORK = os.path.join(HERE, "..", "work")
OUT = os.path.join(HERE, "..", "ppr_events.csv")

# The column contract, verbatim and in order. A rename or a reorder here silently loads
# the wrong values into the reporting table, so it is asserted below.
EVENTS_COLUMNS = ["center", "metric_group", "metric", "metric_order", "agg", "event_date",
                  "value", "unit", "col_label", "col_order", "cell_color", "col_group",
                  "col_group_order"]

ev = pd.read_csv(os.path.join(WORK, "ppr_datewindow_long.csv"), low_memory=False)

missing = [c for c in EVENTS_COLUMNS if c not in ev.columns]
extra = [c for c in ev.columns if c not in EVENTS_COLUMNS]
assert not missing, f"the event table is missing {missing}; the load would fail"
assert not extra, f"the event table has unexpected column(s) {extra}; update EVENTS_COLUMNS " \
                  "and the reporting table definition together or the load goes into the " \
                  "wrong columns"

# Dates as plain YYYY-MM-DD. Blank means the event genuinely has no date, which is a real
# state here (see the Undated column), so it must stay blank rather than become a zero date.
ev["event_date"] = pd.to_datetime(ev["event_date"], errors="coerce").dt.strftime("%Y-%m-%d")

for col in ["metric_order", "col_order", "col_group_order"]:
    assert ev[col].notna().all(), f"{col} has blanks; it is an int column in the target table"
    ev[col] = ev[col].astype(int)

# Every row must carry a centre or it vanishes from the dashboard's centre filter.
blank_center = int(ev["center"].isna().sum())
assert blank_center == 0, f"{blank_center} rows have no centre"

ev = ev[EVENTS_COLUMNS]
ev.to_csv(OUT, index=False)
print(f"ppr_events.csv: {len(ev):,} rows x {ev.shape[1]} cols")
print("final table ->", os.path.abspath(OUT))

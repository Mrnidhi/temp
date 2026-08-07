"""
PPR pipeline - Stage 2: count metric 3 (TTPs Cancelled/Rescheduled within 7 Days).

Metric 3 cannot be a per-order flag: one order can lose more than one slot, and each loss
belongs to the slot's own date rather than the order's current pickup date. So it carries its
own event table.

Applies the 7-day rule from cancellations.py and maps each LTD event to the centre name stage
1 used. Neither LTD export carries a centre, so the order id is the join key. Both LTD event
exports are required; the pipeline stops if either is missing rather than substituting snapshot
history or an order-level proxy.

In:  the input folder (LTD_Reschedules and LTD_Cancellations), work/ppr_analysis.csv
Out: work/ppr_cancellations.csv, run_meta.json m3_source
"""
import json
import os

import pandas as pd

from cancellations import (COUNT_DIRECTIONS, COUNT_GRAIN, THRESHOLD_DAYS,
                           cancellation_events)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "work")

# Same input resolution as stage 1; RUN_ALL passes the resolved folder in PPR_INPUT_DIR.
_CANDIDATES = [os.environ.get("PPR_INPUT_DIR"),
               os.path.join(HERE, "..", "data"),
               os.path.join(HERE, "..", "synthetic_data", "out")]
INPUT_DIR = next((p for p in _CANDIDATES
                  if p and os.path.isdir(p)
                  and any(f.endswith((".xlsx", ".csv")) for f in os.listdir(p))), None)
if INPUT_DIR is None:
    raise SystemExit("build_cancellations: no input folder found (set PPR_INPUT_DIR).")

META_PATH = os.path.join(OUT_DIR, "run_meta.json")
if not os.path.exists(META_PATH):
    raise SystemExit("run_meta.json missing. Run build_analysis_table.py (stage 1) first.")
meta = json.load(open(META_PATH))

COLS = ["center", "order", "event_date", "recorded_on", "days_notice", "kind",
        "direction", "reason", "center_key", "center_disp"]
OUT = os.path.join(OUT_DIR, "ppr_cancellations.csv")

ev, source, files = cancellation_events(INPUT_DIR, THRESHOLD_DAYS, COUNT_DIRECTIONS)

if ev is not None:
    drops = ev.attrs.get("drops", {})
    print(f"metric 3 funnel ({source}):")
    for reason, n in drops.items():
        print(f"  {n:>6,}  {reason}")
    accounted = sum(v for k, v in drops.items() if k != "rows in")
    assert accounted == drops["rows in"], (
        f"funnel does not reconcile: {accounted} accounted for against "
        f"{drops['rows in']} rows in")

if ev is None:
    raise SystemExit("Metric 3 requires LTD event rows. bai_list_of_orders_hist is archive-only "
                     "and resection_rescheduled_ is not an acceptable substitute.")

ana = pd.read_csv(os.path.join(OUT_DIR, "ppr_analysis.csv"), low_memory=False,
                  usecols=["order_request__til_order_name", "center_key", "atc"])

# The LTD exports carry no centre, so the order id is the only way to place an event.
by_order = (ana.drop_duplicates("order_request__til_order_name")
               .set_index("order_request__til_order_name"))
ev["center_key"] = ev["order"].map(by_order["center_key"])
ev["center_disp"] = ev["order"].map(by_order["atc"])

lost = ev[ev["center_disp"].isna()]
if len(lost):
    print(f"  WARNING: {len(lost)} event(s) at order(s) not in the order table, EXCLUDED "
          f"from metric 3: {sorted(lost['order'].astype(str).unique())[:5]}")
before_mapping = len(ev)
ev = ev.dropna(subset=["center_disp"])
assert len(ev) + len(lost) == before_mapping, "Metric 3 centre-mapping funnel did not reconcile."

ev.reindex(columns=COLS).to_csv(OUT, index=False)
meta["m3_source"] = "ltd"
meta["m3_files"] = files
meta["m3_directions"] = sorted(COUNT_DIRECTIONS)
meta["m3_grain"] = COUNT_GRAIN

counted = len(ev) if COUNT_GRAIN == "events" else ev["order"].nunique()
print(f"metric 3: {counted} short-notice lost slot(s) counted as {COUNT_GRAIN} "
      f"({len(ev)} events across {ev['order'].nunique()} orders) "
      f"from {', '.join(files)} -> work/ppr_cancellations.csv")
print(f"  kind: {ev['kind'].value_counts().to_dict()}   "
      f"directions counted: {sorted(COUNT_DIRECTIONS)}")
if ev["direction"].notna().any():
    print(f"  direction: {ev['direction'].value_counts().to_dict()}")
if ev["reason"].notna().any():
    print(f"  reasons: {ev['reason'].value_counts().to_dict()}")
if len(ev):
    span = pd.to_datetime(ev["recorded_on"])
    print(f"  covers {span.min():%Y-%m-%d} to {span.max():%Y-%m-%d}")

with open(META_PATH, "w") as f:
    json.dump(meta, f, indent=1)

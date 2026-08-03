"""
PPR pipeline - Stage 2: count metric 3 (TTPs Cancelled/Rescheduled within 7 Days).

Metric 3 cannot be a per-order flag: one order can lose more than one slot, and each loss
belongs to the slot's own date rather than the order's current pickup date. So it carries its
own event table.

Applies the 7-day rule from cancellations.py and maps each event to the centre name stage 1
used. Neither LTD export carries a centre, so there the order id is the join key. Records
m3_source in run_meta.json so later stages know which source produced the figure. With no
source at all it writes an empty table and records the proxy, so the run still completes.

In:  the input folder (LTD exports, or a *hist* export), analysis/ppr_analysis.csv
Out: analysis/ppr_cancellations.csv, run_meta.json m3_source
"""
import json
import os

import pandas as pd

from cancellations import (COUNT_DIRECTIONS, COUNT_GRAIN, THRESHOLD_DAYS,
                           cancellation_events, norm_center)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "analysis")

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

if ev is None:
    pd.DataFrame(columns=COLS).to_csv(OUT, index=False)
    meta["m3_source"] = "proxy"
    print("metric 3: no LTD export and no snapshot history in the input folder; "
          "using the resection_rescheduled_ proxy from stage 1")
else:
    ana = pd.read_csv(os.path.join(OUT_DIR, "ppr_analysis.csv"), low_memory=False,
                      usecols=["order_request__til_order_name", "center_key", "atc"])

    if source == "ltd":
        # The LTD exports carry no centre, so the order id is the only way to place an event.
        by_order = (ana.drop_duplicates("order_request__til_order_name")
                       .set_index("order_request__til_order_name"))
        ev["center_key"] = ev["order"].map(by_order["center_key"])
        ev["center_disp"] = ev["order"].map(by_order["atc"])
        lost_label = "order(s) not in the order table"
        lost_col = "order"
    else:
        # The history export names the centre itself; match on the normalized key so every
        # stage agrees on the label.
        key_to_disp = ana.drop_duplicates("center_key").set_index("center_key")["atc"]
        ev["center_key"] = ev["center"].map(norm_center)
        ev["center_disp"] = ev["center_key"].map(key_to_disp)
        lost_label = "centre(s) not in the order table"
        lost_col = "center"

    lost = ev[ev["center_disp"].isna()]
    if len(lost):
        print(f"  WARNING: {len(lost)} event(s) at {lost_label}, EXCLUDED from metric 3: "
              f"{sorted(lost[lost_col].astype(str).unique())[:5]}")
    ev = ev.dropna(subset=["center_disp"])

    ev.reindex(columns=COLS).to_csv(OUT, index=False)
    meta["m3_source"] = source
    meta["m3_files"] = files
    meta["m3_directions"] = sorted(COUNT_DIRECTIONS)
    meta["m3_grain"] = COUNT_GRAIN

    counted = len(ev) if COUNT_GRAIN == "events" else ev["order"].nunique()
    print(f"metric 3: {counted} short-notice lost slot(s) counted as {COUNT_GRAIN} "
          f"({len(ev)} events across {ev['order'].nunique()} orders) "
          f"from {', '.join(files)} -> analysis/ppr_cancellations.csv")
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

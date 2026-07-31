"""
PPR pipeline - Stage 2: count metric 3 (TTPs Cancelled/Rescheduled within 7 Days).

Metric 3 cannot be a per-order flag: one order can lose more than one slot, and each loss
belongs to the slot's own date rather than the order's current pickup date. So it carries its
own event table.

Applies the 7-day rule from cancellations.py to the snapshot history and maps each event to
the centre name stage 1 used. Records m3_source in run_meta.json so the later stages know
which source produced the figure. With no history file it writes an empty table and records
the proxy, so the run still completes.

In:  the input folder (optionally a *hist* export), analysis/ppr_analysis.csv
Out: analysis/ppr_cancellations.csv, run_meta.json m3_source
"""
import json
import os

import pandas as pd

from cancellations import cancellation_events, load_history, norm_center

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "analysis")

# Same input resolution as stage 1; RUN_ALL passes the resolved folder in PPR_INPUT_DIR.
_CANDIDATES = [os.environ.get("PPR_INPUT_DIR"),
               os.path.join(HERE, "..", "data"),
               os.path.join(HERE, "..", "synthetic_data", "out")]
INPUT_DIR = next((p for p in _CANDIDATES
                  if p and os.path.isdir(p)
                  and any(f.endswith(".xlsx") for f in os.listdir(p))), None)
if INPUT_DIR is None:
    raise SystemExit("build_cancellations: no input folder found (set PPR_INPUT_DIR).")

META_PATH = os.path.join(OUT_DIR, "run_meta.json")
if not os.path.exists(META_PATH):
    raise SystemExit("run_meta.json missing. Run build_analysis_table.py (stage 1) first.")
meta = json.load(open(META_PATH))

COLS = ["center", "order", "event_date", "recorded_on", "days_notice", "kind",
        "center_key", "center_disp"]
OUT = os.path.join(OUT_DIR, "ppr_cancellations.csv")

hist_df, hist_path = load_history(INPUT_DIR)
if hist_df is None:
    pd.DataFrame(columns=COLS).to_csv(OUT, index=False)
    meta["m3_source"] = "proxy"
    print("metric 3: no snapshot history in the input folder; "
          "using the resection_rescheduled_ proxy from stage 1")
else:
    ev = cancellation_events(hist_df)
    # Match on the normalized key so every stage agrees on the centre label.
    ana = pd.read_csv(os.path.join(OUT_DIR, "ppr_analysis.csv"),
                      low_memory=False, usecols=["center_key", "atc"])
    key_to_disp = ana.drop_duplicates("center_key").set_index("center_key")["atc"]
    ev["center_key"] = ev["center"].map(norm_center)
    ev["center_disp"] = ev["center_key"].map(key_to_disp)
    lost = ev[ev["center_disp"].isna()]
    if len(lost):
        print(f"  WARNING: {len(lost)} cancellation event(s) at centre(s) not in the order "
              f"table, EXCLUDED from metric 3: {sorted(lost['center'].unique())[:5]}")
    ev = ev.dropna(subset=["center_disp"])
    ev.to_csv(OUT, index=False)
    meta["m3_source"] = "hist"
    meta["m3_hist_file"] = os.path.basename(hist_path)
    print(f"metric 3: {len(ev)} short-notice cancellation events "
          f"({ev['order'].nunique()} distinct orders) from {os.path.basename(hist_path)} "
          f"-> analysis/ppr_cancellations.csv   [compare to metric3_cancellations.py]")

with open(META_PATH, "w") as f:
    json.dump(meta, f, indent=1)

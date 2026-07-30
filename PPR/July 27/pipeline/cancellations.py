"""
Metric 3, the real rule: TTPs Cancelled or Rescheduled within 7 Days.

ONE definition of the 7-day rule. Imported by the pipeline (build_analysis_table,
stage 1) and by the standalone metric3_cancellations.py diagnostic, so the dashboard
number and the audit script can never drift.

THE RULE (Kolin, Meet 6)
    "They had a TTP date of August 14th 2024, and they cancelled it on August 9th. So
     it's checking the days between the snapshot, August 9th, and when it was cancelled,
     August 14th, and it's 5. This would flag as a last-minute cancellation."
    "I think it might use 3 today, but I think we want to use 7 moving forward."

Walk each order's snapshots in record_number order. Whenever the planned pickup date
moves or is cleared, measure from that snapshot's load date back to the date that HAD
been booked. A gap of 0-7 days means the slot could not realistically be refilled, so
it counts.

GRAIN AND DATE (two choices, flagged to Kolin, both one-line to change here)
  * grain: one row per CHANGE (an order rescheduled twice at short notice = 2 events).
           To count distinct orders instead, dedupe on `order` downstream.
  * event_date: the LOST SLOT date (the pickup date that had been booked and was then
           cancelled), because metrics.EVENT_DATE[M3] counts M3 on the TTP date. The
           alternative is `recorded_on` (the day the change was entered); it is carried
           in the output so switching is a column swap, not a recompute.
"""
import glob
import os
import re

import numpy as np
import pandas as pd

THRESHOLD_DAYS = 7          # Kolin: "we want to use 7 moving forward"


def norm_center(s):
    """Normalize free-text centre names so the same centre matches across files (the order
    table, the veeva mapping, the snapshot history). One definition, imported by the stages
    that need it."""
    if pd.isna(s):
        return s
    s = str(s).strip().lower()
    s = re.sub(r",?\s*(llc|inc|pllc|pc|pa|ltd)\.?$", "", s)
    s = re.sub(r"[^a-z0-9 ]", "", s)
    return re.sub(r"\s+", " ", s).strip()

# Column aliases: the Infinity export, the xlsx and the analysis table name these
# differently, so accept any spelling rather than break on a rename.
ALIASES = {
    "order":  ["order_request__til_order_name", "til_order_name", "til_order_number"],
    "record": ["record_number"],
    "load":   ["load_datetime"],
    "ttp":    ["tumor_tissue_pick_up_date", "tumor_pickup_date"],
    "atc":    ["atc"],
}


def find_hist_file(input_dir):
    """The snapshot-history export: any file whose name contains 'hist'. Returns None
    when absent (synthetic dev has no history table, so M3 falls back to the proxy)."""
    pats = ["*hist*.csv", "*hist*.xlsx", "*orders_hist*.csv", "*orders_hist*.xlsx"]
    hits = [f for p in pats for f in glob.glob(os.path.join(input_dir, p))
            if not os.path.basename(f).startswith("~$")]
    return sorted(set(hits), key=os.path.getmtime)[-1] if hits else None


def _col(df, key):
    cols = {str(c).lower().strip(): c for c in df.columns}
    for a in ALIASES[key]:
        if a in cols:
            return cols[a]
    raise KeyError(f"history file has no column for '{key}'; looked for {ALIASES[key]}, "
                   f"columns present: {list(df.columns)}")


def load_history(input_dir):
    """Find and read the history file in input_dir. Returns (df, path) or (None, None).
    The real xlsx exports carry a two-row title banner, so the true header is row index 2."""
    path = find_hist_file(input_dir)
    if path is None:
        return None, None
    if path.lower().endswith(".csv"):
        return pd.read_csv(path, low_memory=False), path
    for header in (0, 2):                      # try flat, then the banner layout
        df = pd.read_excel(path, header=header)
        if any(str(c).lower().strip() in ALIASES["record"] for c in df.columns):
            return df, path
    return pd.read_excel(path, header=2), path


def _parse_load(s):
    """load_datetime is a string like 20241007T024217; take the date part."""
    t = s.astype(str).str.strip().str.replace("-", "", regex=False)
    return pd.to_datetime(t.str[:8], format="%Y%m%d", errors="coerce")


def cancellation_events(hist_df, threshold_days=THRESHOLD_DAYS):
    """One row per short-notice change to a booked pickup date.

    Returns columns:
        center       the ATC as written in the history file
        order        til order name
        event_date   the lost slot date (the pickup date that had been booked) - M3's date
        recorded_on  the snapshot load date the change was seen on
        days_notice  event_date - recorded_on, in days (0..threshold)
        kind         'cancelled' (pickup cleared) or 'rescheduled' (pickup moved)
    """
    d = pd.DataFrame({
        "order":  hist_df[_col(hist_df, "order")].astype(str).str.strip(),
        "rec":    pd.to_numeric(hist_df[_col(hist_df, "record")], errors="coerce"),
        "snap":   _parse_load(hist_df[_col(hist_df, "load")]),
        "ttp":    pd.to_datetime(hist_df[_col(hist_df, "ttp")], errors="coerce"),
        "center": hist_df[_col(hist_df, "atc")].astype(str).str.strip(),
    })
    if d["snap"].isna().mean() > 0.5:
        raise ValueError("load_datetime did not parse in the history file; print a few raw "
                         "values and adjust cancellations._parse_load().")

    d = d.sort_values(["order", "rec"])
    d["prev_ttp"] = d.groupby("order")["ttp"].shift(1)
    moved = d[d.prev_ttp.notna() & (d.ttp.isna() | (d.ttp != d.prev_ttp))].copy()
    moved["days_notice"] = (moved.prev_ttp - moved.snap).dt.days
    moved["kind"] = np.where(moved.ttp.isna(), "cancelled", "rescheduled")

    # Only changes made BEFORE the booked date count. A change recorded after the date
    # had already passed is administrative cleanup, not a lost slot.
    late = moved[(moved.days_notice >= 0) & (moved.days_notice <= threshold_days)]

    return pd.DataFrame({
        "center":      late.center.values,
        "order":       late.order.values,
        "event_date":  late.prev_ttp.values,     # the lost slot date
        "recorded_on": late.snap.values,
        "days_notice": late.days_notice.values,
        "kind":        late.kind.values,
    })

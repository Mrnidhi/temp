"""
Metric 3: TTPs Cancelled or Rescheduled within 7 Days.

ONE definition of the 7-day rule. Imported by the pipeline and by the standalone
metric3_cancellations.py diagnostic, so the dashboard number and the audit script can never
drift.

THE RULE
    A slot was booked. Before it arrived, the date moved or was cleared. Measure from the day
    the change was recorded back to the date that had been booked. A gap of 0 to 7 days means
    the slot could not realistically be refilled, so it counts. The event belongs to the LOST
    slot date, not to the day the change was entered.

TWO SOURCES, ONE RULE
    Preferred: the LTD_Reschedules and LTD_Cancellations exports. Maintained upstream, current
    to the present, and they already carry a direction flag and a cancellation reason.
    Fallback: walking the order snapshot history. Kept because that export is what the
    synthetic set has, and because it covers the period before the LTD tables were available.
    Both feed apply_rule() below, so there is still one definition of the threshold.

GRAIN AND DIRECTION
    Both are open business questions, so both are named constants here rather than decisions
    buried in the code.
"""
import glob
import os
import re

import numpy as np
import pandas as pd

THRESHOLD_DAYS = 7

# A reschedule pushes the TTP later (Postponed) or pulls it earlier (Moved Up). Either way the
# originally booked slot is freed and cannot realistically be refilled, so both count. Narrow
# to {"Postponed"} to count only delays.
COUNT_DIRECTIONS = {"Postponed", "Moved Up"}

# "events" counts every lost slot, so an order rescheduled twice at short notice counts twice.
# "orders" counts each affected order once.
COUNT_GRAIN = "events"


def norm_center(s):
    """Normalize free-text centre names so the same centre matches across files. One
    definition, imported by the stages that need it."""
    if pd.isna(s):
        return s
    s = str(s).strip().lower()
    s = re.sub(r",?\s*(llc|inc|pllc|pc|pa|ltd)\.?$", "", s)
    s = re.sub(r"[^a-z0-9 ]", "", s)
    return re.sub(r"\s+", " ", s).strip()


# ---------------------------------------------------------------------------- file loading
def _norm(s):
    return re.sub(r"[^a-z0-9]", "", str(s).lower())


def _find(input_dir, *stems):
    """First file whose normalized name contains any of these stems. None if absent."""
    files = [f for f in os.listdir(input_dir)
             if f.lower().endswith((".xlsx", ".xls", ".csv")) and not f.startswith("~$")]
    for stem in stems:
        key = _norm(stem)
        hits = [f for f in files if key in _norm(f)]
        if hits:
            return os.path.join(input_dir, sorted(hits, key=len)[0])
    return None


def _read_any(path, must_have):
    """Read a csv or xlsx without knowing whether it carries a banner. The Infinity report
    exports put the true header on row index 2; the query-explorer downloads do not. Try both
    and keep whichever produced an expected column."""
    want = {_norm(c) for c in must_have}
    if path.lower().endswith(".csv"):
        df = pd.read_csv(path, low_memory=False)
        if want & {_norm(c) for c in df.columns}:
            return df
        raise ValueError(f"{os.path.basename(path)} has none of {must_have}; "
                         f"columns present: {list(df.columns)[:12]}")
    for header in (0, 2):
        df = pd.read_excel(path, header=header)
        if want & {_norm(c) for c in df.columns}:
            return df
    raise ValueError(f"{os.path.basename(path)} has none of {must_have} at header row 0 or 2; "
                     f"columns present: {list(pd.read_excel(path, nrows=0).columns)[:12]}")


def _col(df, *names):
    """Fetch a column by any of several spellings, ignoring case and separators."""
    lookup = {_norm(c): c for c in df.columns}
    for n in names:
        if _norm(n) in lookup:
            return df[lookup[_norm(n)]]
    raise KeyError(f"none of {names} found; columns present: {list(df.columns)}")


def _has(df, *names):
    present = {_norm(c) for c in df.columns}
    return any(_norm(n) in present for n in names)


def _dates(s, label):
    """Parse a date column and stop if it mostly failed. A silently unparsed date column would
    zero the metric instead of raising."""
    # format="mixed" because the exports carry a date column and a timestamp column side by
    # side, in whatever display format the download produced.
    out = pd.to_datetime(s, errors="coerce", format="mixed")
    if len(out) and out.isna().mean() > 0.5:
        raise ValueError(f"{label} did not parse; sample values: "
                         f"{s.dropna().astype(str).head(3).tolist()}")
    return out.dt.normalize()


# -------------------------------------------------------------------------------- the rule
def apply_rule(df, threshold_days=THRESHOLD_DAYS, directions=None):
    """The 7-day rule. Input needs order, lost_slot, recorded_on, kind, and optionally center,
    direction and reason. Returns one row per counted event.

    Only changes made BEFORE the booked date count. A change recorded after the date had
    already passed is administrative cleanup, not a lost slot.
    """
    d = df.copy()
    d["days_notice"] = (d["lost_slot"] - d["recorded_on"]).dt.days
    keep = d["days_notice"].between(0, threshold_days)
    if directions is not None and "direction" in d.columns:
        # A blank direction is a cancellation, which has no direction and always counts.
        keep &= d["direction"].isna() | d["direction"].isin(directions)
    d = d[keep]

    blank = pd.Series(np.nan, index=d.index, dtype=object)
    return pd.DataFrame({
        "center":      (d["center"] if "center" in d.columns else blank).values,
        "order":       d["order"].values,
        "event_date":  d["lost_slot"].values,
        "recorded_on": d["recorded_on"].values,
        "days_notice": d["days_notice"].values,
        "kind":        d["kind"].values,
        "direction":   (d["direction"] if "direction" in d.columns else blank).values,
        "reason":      (d["reason"] if "reason" in d.columns else blank).values,
    })


# ------------------------------------------------------- source 1: LTD exports (preferred)
def find_ltd(input_dir):
    """(reschedules path, cancellations path). Either may be None."""
    return (_find(input_dir, "ltd_reschedules", "reschedules"),
            _find(input_dir, "ltd_cancellations", "cancellations"))


def ltd_events(input_dir):
    """Normalize both LTD exports into the rule's input shape. Returns (frame, filenames)."""
    resch_path, canc_path = find_ltd(input_dir)
    parts, files = [], []

    if resch_path:
        r = _read_any(resch_path, ["ORDER_ID", "TTP_DATE_PREV"])
        parts.append(pd.DataFrame({
            "order":       _col(r, "ORDER_ID").astype(str).str.strip(),
            "lost_slot":   _dates(_col(r, "TTP_DATE_PREV"), "TTP_DATE_PREV"),
            "recorded_on": _dates(_col(r, "SNAPSHOT_DATE_TIME_CURR"),
                                  "SNAPSHOT_DATE_TIME_CURR"),
            "kind":        "rescheduled",
            "direction":   (_col(r, "RESCHEDULED_CATEGORY").astype(str).str.strip()
                            if _has(r, "RESCHEDULED_CATEGORY") else np.nan),
            "reason":      np.nan,
        }))
        files.append(os.path.basename(resch_path))

    if canc_path:
        c = _read_any(canc_path, ["ORDER_ID", "TTP_DATE"])
        parts.append(pd.DataFrame({
            "order":       _col(c, "ORDER_ID").astype(str).str.strip(),
            # A cancellation clears the date, so its single TTP_DATE is the lost slot.
            "lost_slot":   _dates(_col(c, "TTP_DATE"), "TTP_DATE"),
            "recorded_on": _dates(_col(c, "SNAPSHOT_DATE_TIME_CURR"),
                                  "SNAPSHOT_DATE_TIME_CURR"),
            "kind":        "cancelled",
            "direction":   np.nan,
            "reason":      (_col(c, "CANCELLATION_REASON").astype(str).str.strip()
                            if _has(c, "CANCELLATION_REASON") else np.nan),
        }))
        files.append(os.path.basename(canc_path))

    if not parts:
        return None, []
    return pd.concat(parts, ignore_index=True), files


# ------------------------------------------- source 2: walking the snapshot history (fallback)
def find_hist_file(input_dir):
    """The order snapshot history export: any file whose name contains 'hist'."""
    pats = ["*hist*.csv", "*hist*.xlsx", "*orders_hist*.csv", "*orders_hist*.xlsx"]
    hits = [f for p in pats for f in glob.glob(os.path.join(input_dir, p))
            if not os.path.basename(f).startswith("~$")]
    return sorted(set(hits), key=os.path.getmtime)[-1] if hits else None


def _parse_load(s):
    """load_datetime is a string like 20241007T024217; take the date part."""
    t = s.astype(str).str.strip().str.replace("-", "", regex=False)
    return pd.to_datetime(t.str[:8], format="%Y%m%d", errors="coerce")


def hist_events(input_dir):
    """Walk each order's snapshots and normalize the changes into the rule's input shape."""
    path = find_hist_file(input_dir)
    if path is None:
        return None, []
    h = _read_any(path, ["record_number"])

    d = pd.DataFrame({
        "order":  _col(h, "order_request__til_order_name", "til_order_name",
                       "til_order_number").astype(str).str.strip(),
        "rec":    pd.to_numeric(_col(h, "record_number"), errors="coerce"),
        "snap":   _parse_load(_col(h, "load_datetime")),
        "ttp":    pd.to_datetime(_col(h, "tumor_tissue_pick_up_date", "tumor_pickup_date"),
                                 errors="coerce"),
        "center": _col(h, "atc").astype(str).str.strip(),
    })
    if d["snap"].isna().mean() > 0.5:
        raise ValueError("load_datetime did not parse in the history file; print a few raw "
                         "values and adjust cancellations._parse_load().")

    d = d.sort_values(["order", "rec"])
    d["prev_ttp"] = d.groupby("order")["ttp"].shift(1)
    moved = d[d.prev_ttp.notna() & (d.ttp.isna() | (d.ttp != d.prev_ttp))].copy()

    return pd.DataFrame({
        "center":      moved["center"].values,
        "order":       moved["order"].values,
        "lost_slot":   moved["prev_ttp"].values,
        "recorded_on": moved["snap"].values,
        "kind":        np.where(moved["ttp"].isna(), "cancelled", "rescheduled"),
        # No direction flag in this export, so derive it the same way the LTD table labels it.
        "direction":   np.where(moved["ttp"].isna(), None,
                                np.where(moved["ttp"] > moved["prev_ttp"],
                                         "Postponed", "Moved Up")),
        "reason":      np.nan,
    }), [os.path.basename(path)]


# ------------------------------------------------------------------------------ entry point
def cancellation_events(input_dir, threshold_days=THRESHOLD_DAYS,
                        directions=COUNT_DIRECTIONS):
    """One row per short-notice lost slot. Prefers the LTD exports, falls back to the snapshot
    history. Returns (events, source, filenames); source is 'ltd', 'hist' or 'none'."""
    frame, files = ltd_events(input_dir)
    source = "ltd"
    if frame is None:
        frame, files = hist_events(input_dir)
        source = "hist"
    if frame is None:
        return None, "none", []
    return apply_rule(frame, threshold_days, directions), source, files

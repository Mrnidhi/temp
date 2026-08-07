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

ONE EVENT SOURCE
    LTD_Reschedules and LTD_Cancellations are the only analytics inputs for metric 3. They
    record the cancellation or reschedule itself, including its recorded timestamp and lost
    slot. bai_list_of_orders_hist is snapshot history and may be retained only for archive
    diagnosis; it is never an event-source fallback and is never added to the LTD events.

GRAIN AND DIRECTION
    Both are open business questions, so both are named constants here rather than decisions
    buried in the code.
"""
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
    """Parse dates while allowing genuinely blank lost-slot dates only."""
    raw = s.astype("string").str.strip()
    missing = raw.isna() | raw.eq("")
    out = pd.to_datetime(raw, errors="coerce")
    bad = ~missing & out.isna()
    if bad.any():
        raise ValueError(f"{label} has {int(bad.sum())} non-blank value(s) that did not parse; "
                         f"sample values: {raw[bad].head(3).tolist()}")
    return out.dt.normalize()


def _required_order(s, label="ORDER_ID"):
    out = s.astype("string").str.strip()
    bad = out.isna() | out.eq("")
    if bad.any():
        raise ValueError(f"{label} has {int(bad.sum())} blank order id(s); cannot map an event "
                         "to a centre.")
    return out


def _required_direction(s):
    out = s.astype("string").str.strip()
    bad = out.isna() | out.eq("") | ~out.isin(COUNT_DIRECTIONS)
    if bad.any():
        raise ValueError("RESCHEDULED_CATEGORY contains blank or unmapped value(s): "
                         f"{sorted(out[bad].dropna().unique().tolist())[:10]}. "
                         f"Allowed values: {sorted(COUNT_DIRECTIONS)}")
    return out


# -------------------------------------------------------------------------------- the rule
def apply_rule(df, threshold_days=THRESHOLD_DAYS, directions=None):
    """The 7-day rule. Input needs order, lost_slot, recorded_on, kind, and optionally center,
    direction and reason. Returns one row per counted event.

    Only changes made BEFORE the booked date count. A change recorded after the date had
    already passed is administrative cleanup, not a lost slot.

    Every dropped row is counted by reason and attached to the result as .attrs["drops"], so
    the caller can show that the funnel adds back up to the rows that went in.
    """
    d = df.copy()
    d["days_notice"] = (d["lost_slot"] - d["recorded_on"]).dt.days

    no_slot = d["lost_slot"].isna()          # cancelled before any slot was booked
    after = ~no_slot & (d["days_notice"] < 0)             # tidied up after the date passed
    beyond = ~no_slot & (d["days_notice"] > threshold_days)   # enough notice to refill
    keep = ~(no_slot | after | beyond)

    wrong_direction = pd.Series(False, index=d.index)
    if directions is not None and "direction" in d.columns:
        # A blank direction is a cancellation, which has no direction and always counts.
        wrong_direction = keep & ~(d["direction"].isna() | d["direction"].isin(directions))
        keep &= ~wrong_direction

    d = d[keep]
    blank = pd.Series(np.nan, index=d.index, dtype=object)
    out = pd.DataFrame({
        "center":      (d["center"] if "center" in d.columns else blank).values,
        "order":       d["order"].values,
        "event_date":  d["lost_slot"].values,
        "recorded_on": d["recorded_on"].values,
        "days_notice": d["days_notice"].values,
        "kind":        d["kind"].values,
        "direction":   (d["direction"] if "direction" in d.columns else blank).values,
        "reason":      (d["reason"] if "reason" in d.columns else blank).values,
    }, index=d.index)
    out.attrs["drops"] = {
        "rows in":                     int(len(df)),
        "no slot was ever booked":     int(no_slot.sum()),
        "recorded after the date":     int(after.sum()),
        f"more than {threshold_days} days notice": int(beyond.sum()),
        "direction not counted":       int(wrong_direction.sum()),
        "counted":                     int(len(out)),
    }
    return out


# ------------------------------------------------------- source: LTD event exports
def find_ltd(input_dir):
    """Return the required (reschedules path, cancellations path)."""
    return (_find(input_dir, "ltd_reschedules", "reschedules"),
            _find(input_dir, "ltd_cancellations", "cancellations"))


def ltd_events(input_dir):
    """Normalize both LTD exports into the rule's input shape. Returns (frame, filenames)."""
    resch_path, canc_path = find_ltd(input_dir)
    missing = [name for path, name in ((resch_path, "LTD_Reschedules"),
                                       (canc_path, "LTD_Cancellations")) if path is None]
    if missing:
        raise FileNotFoundError("Metric 3 requires both LTD event exports. Missing: "
                                + ", ".join(missing)
                                + ". bai_list_of_orders_hist is archive-only and is not a fallback.")
    parts, files = [], []

    if resch_path:
        r = _read_any(resch_path, ["ORDER_ID", "TTP_DATE_PREV"])
        if not _has(r, "RESCHEDULED_CATEGORY"):
            raise KeyError("LTD_Reschedules is missing required RESCHEDULED_CATEGORY")
        parts.append(pd.DataFrame({
            "order":       _required_order(_col(r, "ORDER_ID")),
            "lost_slot":   _dates(_col(r, "TTP_DATE_PREV"), "TTP_DATE_PREV"),
            "recorded_on": _dates(_col(r, "SNAPSHOT_DATE_TIME_CURR"),
                                  "SNAPSHOT_DATE_TIME_CURR"),
            "kind":        "rescheduled",
            "direction":   _required_direction(_col(r, "RESCHEDULED_CATEGORY")),
            "reason":      np.nan,
        }))
        files.append(os.path.basename(resch_path))

    if canc_path:
        c = _read_any(canc_path, ["ORDER_ID", "TTP_DATE"])
        parts.append(pd.DataFrame({
            "order":       _required_order(_col(c, "ORDER_ID")),
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


# ------------------------------------------------------------------------------ entry point
def cancellation_events(input_dir, threshold_days=THRESHOLD_DAYS,
                        directions=COUNT_DIRECTIONS):
    """One row per short-notice LTD event. Returns source 'ltd' or 'none'."""
    frame, files = ltd_events(input_dir)
    if frame is None:
        return None, "none", []
    return apply_rule(frame, threshold_days, directions), "ltd", files

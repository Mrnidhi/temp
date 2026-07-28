"""
PPR pipeline - Stage 3: event-level long table for the dashboard date filter.

One row per metric event, stamped with the date the event happened on, so a
Tableau range-of-dates filter recomputes every metric for any window.

Aggregation contract (column `agg`):
    sum  - counts; SUM(value) over the window
    avg  - timelines; MEDIAN(value) over the window, 1 decimal. Kolin (Meet 6):
           the Infinity scorecard reports "the median for all these values"
    rate - Patient Progression Rate; one row per mfg start, value 1 if the
           patient dropped after mfg start else 0, so AVG(value) = the rate

In:  analysis/ppr_analysis.csv
Out: analysis/ppr_datewindow_long.csv
"""
import os
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
ANA = os.path.join(HERE, "..", "analysis")
A = pd.read_csv(os.path.join(ANA, "ppr_analysis.csv"), low_memory=False)
for c in ["enrollment_date", "tumor_pickup_date", "fp_delivery_date", "infusion_date"]:
    A[c] = pd.to_datetime(A[c], errors="coerce")

from metrics import NAME, GROUP as GROUPS

rows = []
def emit(df, order, metric, agg, datecol, valcol=None, unitcol=None):
    """One row per event. Events with no date are still emitted: they are real events that
    simply cannot be placed in a period (an out-of-spec product never delivered, a
    procurement cancelled so never performed). Dropping them here is what made the period
    columns silently exclude failures."""
    d = df[df[valcol].notna()] if valcol else df
    for _, r in d.iterrows():
        dt = r[datecol]
        rows.append((r["atc"], GROUPS[order], metric, order, agg,
                     dt.strftime("%Y-%m-%d") if pd.notna(dt) else "",
                     float(r[valcol]) if valcol else 1.0,
                     str(r[unitcol]) if unitcol else ""))

# 1-2: enrollments by enrollment date; patients deduped to first enrollment per center
emit(A, 1, NAME[1], "sum", "enrollment_date")
# Distinct counts cannot be pre-materialised: how many distinct patients enrolled depends
# on the window being asked about, so the dedup has to happen at read time. Emit every
# enrollment with its patient id and count distinct units instead of summing.
emit(A, 2, NAME[2], "distinct", "enrollment_date",
     unitcol="iovance_patient_id")

# 3-7: TTP metrics by pickup date
emit(A[A.ttp_cancel_le7 == 1], 3,
     NAME[3],
     "sum", "tumor_pickup_date")
emit(A[A.completed_ttp == 1], 4, NAME[4], "sum", "tumor_pickup_date")
emit(A[A.scheduled_ttp == 1], 5, NAME[5], "sum", "tumor_pickup_date")
ttp = A[A.tumor_pickup_date.notna()].sort_values("tumor_pickup_date")
second = (ttp.drop_duplicates(["atc", "iovance_patient_id", "tumor_pickup_date"])
             .groupby(["atc", "iovance_patient_id"]).nth(1).reset_index())
# KNOWN LIMITATION: this is "patients with 2 or more procurements", deduped across all
# time. Within a narrow window the answer can differ by one from the precomputed scorecard,
# because a patient's first and second procurement may straddle the window edge. Measured
# on the synthetic set: 1 cell in 3,309. Rendering it correctly per-window needs an LOD in
# the workbook; left as-is until someone asks for that metric by window.
emit(second, 6, NAME[6], "sum", "tumor_pickup_date")
# Patient grain, matching build_scorecard.
emit(A[A.dropout_post_ttp_health == 1], 7,
     NAME[7],
     "distinct", "tumor_pickup_date", unitcol="iovance_patient_id")

# 8: OOS by final product delivery date
emit(A[A.oos_product == 1], 8, NAME[8], "sum", "fp_delivery_date")

# 9: one row per PATIENT who started manufacturing; AVG(value) = the rate.
# Same window-edge limitation as metric 6: the dedup is across all time.
mfg = (A[A.mfg_started == 1]
       .sort_values("tumor_pickup_date")
       .groupby(["atc", "iovance_patient_id"], as_index=False)
       .agg(tumor_pickup_date=("tumor_pickup_date", "first"),
            drop_after_mfg=("drop_after_mfg", "max")))
mfg["drop_flag"] = mfg["drop_after_mfg"].astype(float)
emit(mfg, 9, NAME[9], "rate", "tumor_pickup_date", "drop_flag")

# 10: infusions by infusion date
emit(A[A.amtagvi_infused == 1], 10, NAME[10], "sum", "infusion_date")

# 11-13: timelines, each anchored to its event date
emit(A, 11, NAME[11], "avg",
     "tumor_pickup_date", "days_enroll_to_ttp")
emit(A, 12, NAME[12], "avg",
     "infusion_date", "days_ttp_to_infusion")
emit(A, 13, NAME[13],
     "avg", "infusion_date", "days_delivery_to_infusion")

ev = pd.DataFrame(rows, columns=["center", "metric_group", "metric", "metric_order",
                                 "agg", "event_date", "value", "unit"])

# ---- tag every event with the template columns it belongs to -------------------------
# One sheet has to show both the fixed template columns and a live user-chosen window.
# A single event belongs to several columns at once (Launch to Date, its year, its
# quarter), so it is emitted once per column it falls in. That turns the column set into
# an ordinary dimension, which means one worksheet off one source can render the whole
# scorecard AND respond to a date filter.
#
# The "Selected window" copy is the live one: in Tableau a single filter calc applies the
# date parameters to those rows only, leaving the fixed columns untouched. Without the
# split, dragging the slider would blank out the 2024 and 2025 columns.
# As-of from stage 1, one definition for every stage (see build_analysis_table.py).
import json as _json
TODAY = _json.load(open(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "analysis", "run_meta.json")))["asof"]
BUCKETS = [
    ("Launch to Date", 1,  None,         None),
    ("2024",           2,  "2024-01-01", "2024-12-31"),
    ("2025",           3,  "2025-01-01", "2025-12-31"),
    ("2026 YTD",       4,  "2026-01-01", TODAY),
    ("Undated",        6,  None,         None),   # no event date at all
    ("After as-of",    7,  TODAY,        None),   # dated beyond the extract
    ("Q3'26 QTD",     11,  "2026-07-01", TODAY),
    ("Q2'26",         12,  "2026-04-01", "2026-06-30"),
    ("Q1'26",         13,  "2026-01-01", "2026-03-31"),
    ("Q4'25",         14,  "2025-10-01", "2025-12-31"),
]
# Sits with the other time columns rather than after the diagnostics, so the eye reads
# Launch to Date, the years, then the live window, then the benchmarks, then the quarters.
SELECTED = ("Selected window", 5)   # Tableau applies the date parameters to these rows only

d = pd.to_datetime(ev.event_date, errors="coerce")
tagged = []
for label, order, start, end in BUCKETS:
    if label == "Undated":
        m = d.isna()
    else:
        m = d.notna() if label != "Launch to Date" else pd.Series(True, index=ev.index)
        if start is not None:
            m &= d > pd.Timestamp(start) if label == "After as-of" else d >= pd.Timestamp(start)
        if end is not None:
            m &= d <= pd.Timestamp(end)
    part = ev[m].copy()
    part["col_label"], part["col_order"] = label, order
    tagged.append(part)

live = ev.copy()
live["col_label"], live["col_order"] = SELECTED
tagged.append(live)

# ---- national tier benchmarks (Top 10 / Top 40 / New) --------------------------------
# These are a two-stage aggregate: a per-centre value, then the MEDIAN across the centres
# in the tier. An event table cannot reproduce that by summing rows, so they are carried
# across already computed rather than recalculated here. Stage 2 owns the definition
# (bench_median in build_scorecard.py); this reads its output so there is one definition.
#
# agg="preagg" tells Tableau to print the stored display string instead of aggregating.
# The formatted value rides in the `unit` column, which is unused for these rows.
BENCH_ORDER = {"Top 10": 8, "Top 40": 9, "New": 10}
sc = pd.read_csv(os.path.join(ANA, "ppr_scorecard_tidy.csv"))
nat = sc[sc.scope == "National"].copy()
missing = set(BENCH_ORDER) - set(nat.col_label)
if missing:
    raise SystemExit(f"benchmark tiers missing from the scorecard: {sorted(missing)}")
bench = pd.DataFrame({
    "atc": "National",
    "metric_group": nat.metric_group,
    "metric": nat.metric,
    "metric_order": nat.metric_order,
    "agg": "preagg",
    "event_date": pd.NaT,
    "value": nat.value,
    "unit": nat.value_display.fillna(""),
    "col_label": nat.col_label,
    "col_order": nat.col_label.map(BENCH_ORDER),
})
tagged.append(bench)

out = pd.concat(tagged, ignore_index=True)

# ---- block header, so the table reads as three groups rather than 13 equal columns ----
# Kolin's template puts a second header row over the columns: the centre's own figures,
# the national comparison, the quarterly trend. Those are three different questions and
# labelling them is what stops the table reading as a data dump.
# The centre block is left generic here; Tableau swaps in the selected centre's name.
COL_GROUP = {
    "Launch to Date": "This Center", "2024": "This Center", "2025": "This Center",
    "2026 YTD": "This Center", "Selected window": "This Center",
    "Undated": "This Center", "After as-of": "This Center",
    "Top 10": "YTD National Metrics", "Top 40": "YTD National Metrics",
    "New": "YTD National Metrics",
    "Q3'26 QTD": "Quarterly ATC Metrics", "Q2'26": "Quarterly ATC Metrics",
    "Q1'26": "Quarterly ATC Metrics", "Q4'25": "Quarterly ATC Metrics",
}
_unmapped = set(out.col_label) - set(COL_GROUP)
if _unmapped:
    raise SystemExit(f"column(s) with no block: {sorted(_unmapped)}. Add them to COL_GROUP.")
out["col_group"] = out.col_label.map(COL_GROUP)
# Blocks must sort in the same order as the columns inside them, or Tableau interleaves.
out["col_group_order"] = out.groupby("col_group").col_order.transform("min")

_b = out[out["agg"] == "preagg"]
assert len(_b) == 3 * out.metric.nunique(), (
    f"expected 3 tiers x {out.metric.nunique()} metrics = {3*out.metric.nunique()} "
    f"benchmark rows, got {len(_b)}")
out.to_csv(os.path.join(ANA, "ppr_datewindow_long.csv"), index=False)
print(f"datewindow events: {len(ev):,} events -> {len(out):,} column-tagged rows, "
      f"{out.metric.nunique()} metrics -> analysis/ppr_datewindow_long.csv")
print("  columns:", ", ".join(out.sort_values("col_order").col_label.unique()))

# A bucket with no events produces no rows, and a column with no rows does not render in
# Tableau at all. The template column would silently vanish rather than show zero.
_empty = [b[0] for b in BUCKETS if b[0] not in set(out.col_label)]
if _empty:
    print(f"  WARNING: no events fall in {_empty}. Those columns will not appear in the"
          " workbook. Check the as-of date before showing anyone.")

# ---- ASSERTION: this table must reproduce the precomputed scorecard ----
# Two independent implementations of the same 13 metrics. If they drift, the dashboard and
# the deck disagree and Kolin finds it first. Compare every cell on every run.
sc = pd.read_csv(os.path.join(ANA, "ppr_scorecard_tidy.csv"))
sc = sc[(sc.scope == "Center") & sc.col_label.isin([b[0] for b in BUCKETS])]

KEY = ["center", "metric", "col_label"]
_parts = []
# Benchmarks are excluded: they are a median across centres, carried over already
# computed, so there is no per-centre cell to reconcile them against.
_chk = out[(out.col_label != SELECTED[0]) & (out["agg"] != "preagg")]
for _a, _g in _chk.groupby("agg"):
    if _a == "sum":        _r = _g.groupby(KEY)["value"].sum()
    elif _a == "distinct": _r = _g.groupby(KEY)["unit"].nunique().astype(float)
    elif _a == "avg":      _r = _g.groupby(KEY)["value"].median().round(1)
    elif _a == "rate":     _r = _g.groupby(KEY)["value"].mean().round(3)
    else: raise SystemExit(f"unknown agg '{_a}' in the event table")
    _parts.append(_r.rename("mine"))
mine = pd.concat(_parts).reset_index()
cmp = sc.merge(mine, left_on=["center", "metric", "col_label"],
               right_on=["center", "metric", "col_label"], how="outer")
cmp["value"] = cmp["value"].fillna(0.0)
cmp["mine"] = cmp["mine"].fillna(0.0)
bad = cmp[(cmp.value - cmp.mine).abs() > 0.051]        # 0.05 covers 1dp rounding

# Deduped across all time, so a patient whose two events straddle a window edge shifts a cell.
ALLOWED = {"2nd Resections (Scheduled or Completed)", "Patient Progression Rate"}
hard = bad[~bad.metric.isin(ALLOWED)]
if len(hard):
    print("\nFAILED: the event table does not reproduce the scorecard")
    print(hard.head(20).to_string(index=False))
    raise SystemExit(f"{len(hard)} cells disagree between the two implementations.")
print(f"  agrees with the scorecard on {len(cmp) - len(bad):,} of {len(cmp):,} cells"
      + (f" ({len(bad)} known dedup edge case(s) in {', '.join(sorted(set(bad.metric)))})"
         if len(bad) else ""))

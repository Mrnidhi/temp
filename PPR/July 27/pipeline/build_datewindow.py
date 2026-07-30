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
import json
import os
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
ANA = os.path.join(HERE, "..", "analysis")
A = pd.read_csv(os.path.join(ANA, "ppr_analysis.csv"), low_memory=False)
for c in ["enrollment_date", "tumor_pickup_date", "fp_delivery_date", "infusion_date"]:
    A[c] = pd.to_datetime(A[c], errors="coerce")

from metrics import NAME, GROUP as GROUPS, LOWER_IS_BETTER, HIGHER_IS_BETTER

rows = []
undated = []   # (center, metric, order id, missing field) - Kolin asked for these 07/28
def emit(df, order, metric, agg, datecol, valcol=None, unitcol=None):
    """One row per event. Events with no date are still emitted: they are real events that
    simply cannot be placed in a period (an out-of-spec product never delivered, a
    procurement cancelled so never performed). Dropping them here is what made the period
    columns silently exclude failures."""
    d = df[df[valcol].notna()] if valcol else df
    for _, r in d.iterrows():
        dt = r[datecol]
        if pd.isna(dt):
            undated.append((r["atc"], metric,
                            r.get("order_request__til_order_name", ""), datecol))
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
# 3: cancellations. Real rule from the snapshot history when present (event-grained, dated
# on the lost slot); the resection_rescheduled_ proxy on the order table otherwise. Stage 1
# decides the source and records it in run_meta.json.
_M3SRC = json.load(open(os.path.join(ANA, "run_meta.json"))).get("m3_source", "proxy")
if _M3SRC == "hist":
    _cev = pd.read_csv(os.path.join(ANA, "ppr_cancellations.csv"))
    _cev["event_date"] = pd.to_datetime(_cev["event_date"], errors="coerce")
    _cev = _cev.rename(columns={"center_disp": "atc"})
    emit(_cev, 3, NAME[3], "sum", "event_date")
else:
    emit(A[A.ttp_cancel_le7 == 1], 3, NAME[3], "sum", "tumor_pickup_date")
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

# ---- the one benchmark arm per centre (Kolin, 07/28 Daily Connect) -------------------
# His template's red note says "Pick one comparative arm depending on ATC". The rule from
# the meeting: the arm is the centre's own tier. Froedtert (a New centre) compares to New;
# MSK compares to the Top 10. So instead of three shared "National" columns, every centre
# gets 13 rows carrying ITS tier's medians, under its own centre name. Keep Center in the
# workbook then needs no special case.
#
# Stage 2 owns the median definition (bench_median); this carries its output across so
# there is one definition. agg="preagg" tells the workbook to print the stored display
# string (in `unit`) instead of aggregating.
#
# Each centre compares against its own segment. No mapping decision left to make: the arm is
# the segment, which is why switching to Iovance's segmentation removed the old "Other sees
# Top 40" assumption that was ours to justify.
ARM_FOR_TIER = {"Top Account": "Top Account",
                "High Potential": "High Potential",
                "Other": "Other"}
BENCH_COL_ORDER = 8

sc = pd.read_csv(os.path.join(ANA, "ppr_scorecard_tidy.csv"))
nat = sc[sc.scope == "National"]
missing = set(ARM_FOR_TIER.values()) - set(nat.col_label)
if missing:
    raise SystemExit(f"benchmark tiers missing from the scorecard: {sorted(missing)}")

tier_of = A.drop_duplicates("atc").set_index("atc")["atc_tier"]
_untiered = tier_of[~tier_of.isin(ARM_FOR_TIER)].index.tolist()
if _untiered:
    raise SystemExit(f"centre(s) with an unknown tier: {_untiered[:5]}")

bench_parts = []
for arm, g in nat.groupby("col_label"):
    centres = tier_of[tier_of.map(ARM_FOR_TIER) == arm].index
    if len(centres) == 0:
        continue
    block = g[["metric_group", "metric", "metric_order", "value", "value_display"]]
    for c in centres:
        b = block.copy()
        b["center"] = c
        bench_parts.append(b)
bench_all = pd.concat(bench_parts, ignore_index=True)
bench = pd.DataFrame({
    "center": bench_all.center,
    "metric_group": bench_all.metric_group,
    "metric": bench_all.metric,
    "metric_order": bench_all.metric_order,
    "agg": "preagg",
    "event_date": pd.NaT,
    "value": bench_all.value,
    "unit": bench_all.value_display.fillna(""),
    # the column label names the arm, so the header says which tier this centre sees
    "col_label": tier_of.loc[bench_all.center].map(ARM_FOR_TIER).values,
    "col_order": BENCH_COL_ORDER,
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
    "Top Account": "YTD National Metrics", "High Potential": "YTD National Metrics",
    "Other": "YTD National Metrics",
    "Q3'26 QTD": "Quarterly ATC Metrics", "Q2'26": "Quarterly ATC Metrics",
    "Q1'26": "Quarterly ATC Metrics", "Q4'25": "Quarterly ATC Metrics",
}
_unmapped = set(out.col_label) - set(COL_GROUP)
if _unmapped:
    raise SystemExit(f"column(s) with no block: {sorted(_unmapped)}. Add them to COL_GROUP.")
# ---- performance heat, one colour per Launch to Date cell (Kolin, 07/28) -------------
# The centre's launch-to-date value against the median of ITS OWN benchmark arm.
# Direction-aware; neutral metrics and blank values keep the plain row band.
# THRESHOLDS ARE A PROPOSAL pending Kolin: at/better than the median = green, within
# half (or double, for lower-is-better) = amber, beyond = orange.
def heat_band(v, m, lower_better):
    if pd.isna(v) or pd.isna(m):
        return None
    if lower_better:
        if m == 0:
            return "green" if v == 0 else "amber"
        return "green" if v <= m else ("amber" if v <= 2 * m else "orange")
    return "green" if v >= m else ("amber" if v >= 0.5 * m else "orange")

ctr_l2d = (sc[(sc.scope == "Center") & (sc.col_label == "Launch to Date")]
           .set_index(["center", "metric"]).value)
arm_med = nat.set_index(["col_label", "metric"]).value
heat = {}
for (center, metric), v in ctr_l2d.items():
    if metric in LOWER_IS_BETTER:
        lower = True
    elif metric in HIGHER_IS_BETTER:
        lower = False
    else:
        continue
    arm = ARM_FOR_TIER[tier_of[center]]
    band = heat_band(v, arm_med.get((arm, metric)), lower)
    if band:
        heat[(center, metric)] = band

GROUP_BAND = {g: ("band_blue" if i % 2 == 0 else "band_gray")
              for i, g in enumerate(dict.fromkeys(GROUPS.values()))}
out["cell_color"] = out.metric_group.map(GROUP_BAND)
_l2d = out.col_label == "Launch to Date"
out.loc[_l2d, "cell_color"] = [
    heat.get((c, m), GROUP_BAND[g])
    for c, m, g in zip(out.loc[_l2d, "center"], out.loc[_l2d, "metric"],
                       out.loc[_l2d, "metric_group"])]

# A centre with ZERO events on a directional metric has no row to colour, yet a zero on
# a lower-is-better metric is the best result there is. Emit one zero-value stub per such
# cell so the cell renders "0" and takes its colour. Value 0 changes no sum anywhere.
_have = set(map(tuple, out.loc[_l2d, ["center", "metric"]].drop_duplicates().values))
_stub = []
_morder = {m: o for o, m in NAME.items()}
for (center, metric), band in heat.items():
    if (center, metric) not in _have:
        _stub.append(dict(center=center, metric_group=GROUPS[_morder[metric]],
                          metric=metric, metric_order=_morder[metric], agg="sum",
                          event_date=pd.NaT, value=0.0, unit="",
                          col_label="Launch to Date", col_order=1,
                          col_group="This Center", col_group_order=1,
                          cell_color=band))
if _stub:
    out = pd.concat([out, pd.DataFrame(_stub)], ignore_index=True)
    print(f"heat stubs for zero-event cells: {len(_stub)}")

_allowed = {"band_blue", "band_gray", "green", "amber", "orange"}
assert set(out.cell_color) <= _allowed, set(out.cell_color) - _allowed
_hot = out[out.cell_color.isin({"green", "amber", "orange"})]
assert (_hot.col_label == "Launch to Date").all(), "heat leaked off the Launch to Date column"
print(f"heat: {_hot.groupby('cell_color').center.nunique().to_dict()} centres coloured, "
      f"{len(heat)} centre-metric cells banded")

out["col_group"] = out.col_label.map(COL_GROUP)
# Every row must carry a centre, or the workbook's centre filter silently drops it.
_nc = int(out["center"].isna().sum())
if _nc:
    raise SystemExit(f"{_nc} rows have no centre. They would vanish from the workbook.")
# Blocks must sort in the same order as the columns inside them, or Tableau interleaves.
out["col_group_order"] = out.groupby("col_group").col_order.transform("min")

_b = out[out["agg"] == "preagg"]
_nc = out[out["agg"] != "preagg"].center.nunique()
assert len(_b) == 13 * _nc, (
    f"expected 13 benchmark rows for each of {_nc} centres = {13*_nc}, got {len(_b)}")
assert _b.groupby("center").col_label.nunique().max() == 1, (
    "a centre carries more than one benchmark arm")
und = pd.DataFrame(undated, columns=["center", "metric", "order_id", "missing_date_field"])
und.to_csv(os.path.join(ANA, "undated_events.csv"), index=False)
print(f"undated events for review: {len(und):,} -> analysis/undated_events.csv "
      "(Kolin asked to see these, 07/28)")

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

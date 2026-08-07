"""
PPR pipeline - Stage 3: compute the P&PR scorecard.

From work/ppr_analysis.csv, compute the 13 scorecard metrics for every center across the
time cuts and quarters, plus the national ATC-tier benchmarks. One row per center x
column x metric.

Stage 4 rebuilds the same 13 metrics a different way and reconciles against this file
cell by cell, so this is the reference half of that check.

Out: work/ppr_scorecard_tidy.csv
"""
import os
import numpy as np
import pandas as pd

HERE = os.path.dirname(__file__)
OUT_DIR = os.path.join(HERE, "..", "work")
A = pd.read_csv(os.path.join(OUT_DIR, "ppr_analysis.csv"), low_memory=False)
# As-of date comes from stage 1, one definition for every stage. run_meta.json also
# says whether this run is on the test sample, so the dashboard can label itself.
_META_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "work", "run_meta.json")
if not os.path.exists(_META_PATH):
    raise SystemExit("work/run_meta.json missing. Run build_analysis_table.py (stage 1) first.")
import json as _json
RUN_META = _json.load(open(_META_PATH))
TODAY = RUN_META["asof"]

M3_SOURCE = RUN_META.get("m3_source")
if M3_SOURCE != "ltd":
    raise SystemExit(f"Metric 3 requires LTD events, received source {M3_SOURCE!r}.")
M3_EVENTS = True
CANC = pd.read_csv(os.path.join(OUT_DIR, "ppr_cancellations.csv"))
if len(CANC):
    CANC["event_date"] = pd.to_datetime(CANC["event_date"], errors="coerce")
elif M3_EVENTS:
    print(f"WARNING: run_meta.json says m3_source={M3_SOURCE!r} but "
          "work/ppr_cancellations.csv has no rows. Metric 3 will read 0 everywhere; "
          "check the stage 2 output before trusting it.")

from metrics import (METRICS, EVENT_DATE, NON_ADDITIVE,
                     M1, M2, M3, M4, M5, M6, M7, M8, M9, M10, M11, M12, M13)

def _win(df, datecol, start, end):
    """Rows whose event date for this metric falls inside the window (None = no bound)."""
    if start is None and end is None:
        return df
    d = pd.to_datetime(df[datecol], errors="coerce")
    m = d.notna()
    if start is not None: m &= d >= pd.Timestamp(start)
    if end   is not None: m &= d <= pd.Timestamp(end)
    return df[m]

def compute(df, start=None, end=None, avg="median", undated=False, future=False, canc=None):
    """13 metrics. Each is filtered on ITS OWN event date, so a column means
    'what happened in this period'.

    undated=True instead selects rows whose own event date is MISSING. Those rows are
    real events that cannot be placed in any period. They belong in Launch to Date and in
    no year column, and the difference has to be visible rather than silently dropped:
    missingness here correlates with the outcome (an out-of-spec product is often never
    delivered, a cancelled procurement never happened), so hiding it biases every period
    column optimistic.

    future=True selects rows dated AFTER the as-of date. Period columns stop at the as-of
    date, so these also sit in Launch to Date and in no period column. Scheduled TTPs are
    future by definition and belong here; future-dated infusions do not and are flagged
    below."""
    if undated:
        w = {m: df[pd.to_datetime(df[col], errors="coerce").isna()]
             for m, col in EVENT_DATE.items()}
    elif future:
        w = {m: df[pd.to_datetime(df[col], errors="coerce") > pd.Timestamp(TODAY)]
             for m, col in EVENT_DATE.items()}
    else:
        w = {m: _win(df, col, start, end) for m, col in EVENT_DATE.items()}
    # The source scorecard reports medians for these, not averages.
    agg = (lambda s: s.mean()) if avg == "mean" else (lambda s: s.median())

    # Metrics 7 and 9 describe patients, and a patient can hold several orders, so
    # counting orders over-weights them. Always understates the rate.
    def patients(frame, flag):
        f = frame[flag].fillna(False).astype(bool)
        return frame.loc[f, "iovance_patient_id"].nunique()

    mfg = patients(w[M9], "mfg_started")
    drop_after_mfg = patients(w[M9], "drop_after_mfg")
    # 2nd Resections = distinct PATIENTS with 2+ real TTP dates
    ttp = w[M6].dropna(subset=["tumor_pickup_date"])
    mult = ttp.groupby("iovance_patient_id")["tumor_pickup_date"].nunique()

    def days(frame, col):
        v = agg(frame[col].dropna())
        return round(float(v), 1) if pd.notna(v) else np.nan

    # Metric 3 from real cancellation events (dated on the lost slot) when an event
    # source produced them. The window logic mirrors build_datewindow.
    if M3_EVENTS and canc is not None:
        ed = canc["event_date"]
        if undated:
            m3 = int(ed.isna().sum())
        elif future:
            m3 = int((ed > pd.Timestamp(TODAY)).sum())
        elif start is None and end is None:
            m3 = int(len(canc))                       # Launch to Date: every event
        else:
            cm = ed.notna()
            if start is not None: cm &= ed >= pd.Timestamp(start)
            if end   is not None: cm &= ed <= pd.Timestamp(end)
            m3 = int(cm.sum())
    else:
        m3 = int(w[M3]["ttp_cancel_le7"].sum())

    return {
        M1:  w[M1]["order_request__til_order_name"].nunique(),
        M2:  w[M2]["iovance_patient_id"].nunique(),
        M3:  m3,
        M4:  int(w[M4]["completed_ttp"].sum()),
        M5:  int(w[M5]["scheduled_ttp"].sum()),
        M6:  int((mult >= 2).sum()),
        M7:  patients(w[M7], "dropout_post_ttp_health"),
        M8:  int(w[M8]["oos_product"].sum()),
        M9:  round(drop_after_mfg / mfg, 3) if mfg else np.nan,
        M10: int(w[M10]["amtagvi_infused"].sum()),
        M11: days(w[M11], "days_enroll_to_ttp"),
        M12: days(w[M12], "days_ttp_to_infusion"),
        M13: days(w[M13], "days_delivery_to_infusion"),
    }

A["enrollment_date"] = pd.to_datetime(A["enrollment_date"])
A["enroll_year"] = A["enrollment_date"].dt.year
A["enroll_q"] = A["enrollment_date"].dt.to_period("Q").astype(str)

# ---- column definitions: (col_group, label, order, start, end) ----
# Windows, not cohort filters: each metric is counted on its own event date (see EVENT_DATE).
TIME_COLS = [
    ("Time", "Launch to Date", 1, None,         None),
    ("Time", "2024",           2, "2024-01-01", "2024-12-31"),
    ("Time", "2025",           3, "2025-01-01", "2025-12-31"),
    ("Time", "2026 YTD",       4, "2026-01-01", TODAY),
]
# template shows quarters most-recent-first (Q3'26 QTD leftmost)
QUARTER_COLS = [
    ("Quarter", "Q3'26 QTD", 10, "2026-07-01", TODAY),
    ("Quarter", "Q2'26",     11, "2026-04-01", "2026-06-30"),
    ("Quarter", "Q1'26",     12, "2026-01-01", "2026-03-31"),
    ("Quarter", "Q4'25",     13, "2025-10-01", "2025-12-31"),
]
UNDATED_COL = ("Time", "Undated", 5, None, None)   # no event date at all
FUTURE_COL  = ("Time", "After as-of", 6, None, None)   # dated beyond the extract date
CENTER_COLS = TIME_COLS + QUARTER_COLS
# Tier medians. See the tier block in build_analysis_table.py for how membership is set.
BENCH_COLS = [
    ("Benchmark", "Top 10", 7, "Top 10"),
    ("Benchmark", "Top 40", 8, "Top 40"),
    ("Benchmark", "New",    9, "New"),
]
mreg = {m[2]: (m[0], m[1], m[3]) for m in METRICS}

rows = []
def emit(scope, center, col_group, col_label, col_order, vals):
    for mname, v in vals.items():
        order, group, vtype = mreg[mname]
        rows.append(dict(scope=scope, center=center, col_group=col_group, col_label=col_label,
                         col_order=col_order, metric_group=group, metric=mname,
                         metric_order=order, value_type=vtype, value=v))

# per-center: time + quarter columns
def _canc_for(disp):
    """The cancellation events for one centre, matched on the display name stage 1 carried."""
    return CANC[CANC["center_disp"] == disp] if len(CANC) else CANC

for center, g in A.groupby("center_key"):
    disp = g["atc"].iloc[0]
    gc = _canc_for(disp)
    for cg, label, order, st, en in CENTER_COLS:
        emit("Center", disp, cg, label, order, compute(g, st, en, canc=gc))
    emit("Center", disp, UNDATED_COL[0], UNDATED_COL[1], UNDATED_COL[2],
         compute(g, undated=True, canc=gc))
    emit("Center", disp, FUTURE_COL[0], FUTURE_COL[1], FUTURE_COL[2],
         compute(g, future=True, canc=gc))

# Tier benchmark = per-center MEDIAN within the tier, launch-to-date. Median rather than sum
# or average, so a handful of very large centers do not carry the comparison.
def bench_median(tiername):
    per_center = [compute(g, canc=_canc_for(g["atc"].iloc[0]))
                  for _, g in A[A.atc_tier == tiername].groupby("center_key")]
    out = {}
    for mname in mreg:
        vals = [pc[mname] for pc in per_center
                if pc[mname] is not None and not (isinstance(pc[mname], float) and np.isnan(pc[mname]))]
        out[mname] = float(np.median(vals)) if vals else np.nan
    return out

for cg, label, order, tiername in BENCH_COLS:
    emit("National", "National", cg, label, order, bench_median(tiername))

# The old Excel view (25th/50th/75th percentile and national average across all ATCs)
# used to be emitted here as a "CurrentTemplate" scope, so the new and old could be shown
# side by side. Removed 2026-07-27: quartiles were hard to explain in the field. The tier
# medians above replace them, and col_order 12-15 came free.

tidy = pd.DataFrame(rows)

# display helpers so Tableau sorts by plain alpha (no fragile sort specs) and shows
# type-aware text (counts as ints, days 1dp, rate as %).
tidy["row_label"] = tidy["metric_order"].map(lambda i: f"{i:02d}  {[m[2] for m in METRICS if m[0]==i][0]}")
# ---- every counted event lands in exactly one bucket ----
# Launch to Date must equal the year columns plus Undated plus After as-of. Without this a
# metric dated on a column that is null for exactly the rows it counts would vanish from
# every period column while still showing in Launch to Date.
_chk = tidy[(tidy.scope == "Center") & (tidy.value_type == "count")
            & (~tidy.metric.isin(NON_ADDITIVE))]
_ltd = _chk[_chk.col_label == "Launch to Date"].set_index(["center", "metric"]).value
_buckets = ["2024", "2025", "2026 YTD", "Undated", "After as-of"]
_parts = (_chk[_chk.col_label.isin(_buckets)].groupby(["center", "metric"]).value.sum())
_cmp = _ltd.to_frame("ltd").join(_parts.to_frame("parts"), how="outer").fillna(0)
_bad = _cmp[(_cmp.ltd - _cmp.parts).abs() > 1e-9]
if len(_bad):
    print("\nFAILED: year columns + Undated + After as-of != Launch to Date")
    print(_bad.assign(gap=lambda d: d.ltd - d.parts)
          .sort_values("gap", key=abs, ascending=False).head(20).to_string())
    raise SystemExit(f"{len(_bad)} center/metric cells do not reconcile.")
print(f"reconciles: {len(_cmp):,} center/metric cells "
      "(year + undated + after-as-of == launch-to-date)")

# ---- WARNING: events dated after the extract date ----
# Scheduled TTPs are future by definition and belong here. Infusions do not: an infusion
# recorded with a future date has not been performed, so counting it in a metric called
# "Infusions Performed" overstates treated patients.
_fut = (tidy[(tidy.scope == "Center") & (tidy.col_label == "After as-of")
             & (tidy.value_type == "count")]      # summing medians would be meaningless
        .groupby("metric").value.sum())
_fut = _fut[_fut > 0]
if len(_fut):
    print("\nevents dated after the as-of date (in Launch to Date, in no period column):")
    for m, v in _fut.items():
        note = "  <- expected, these are future bookings" if m == M5 else \
               "  <- REVIEW: not yet performed, but counted as performed" if m == M10 else ""
        print(f"  {int(v):>4}  {m}{note}")

tidy["col_final"] = tidy.apply(lambda r: f"{r.col_order:02d} {r.col_label}", axis=1)
def fmt(r):
    if pd.isna(r.value):
        return ""
    if r.value_type == "rate":
        return f"{r.value*100:.1f}%"
    if r.value_type == "days":
        return f"{r.value:.1f}"
    return f"{int(round(r.value))}"
tidy["value_display"] = tidy.apply(fmt, axis=1)

tidy.to_csv(os.path.join(OUT_DIR, "ppr_scorecard_tidy.csv"), index=False)
print(f"tidy scorecard: {len(tidy)} rows -> work/ppr_scorecard_tidy.csv")

# ---- optional preview payload ----
# Only written when the HTML preview stage is present. The pipeline's output is the final
# table; the preview is a convenience, and without it this block writes nothing.
import json
PREVIEW = os.path.exists(os.path.join(HERE, "build_dashboard_html.py"))
metrics = [{"metric_order": m[0], "metric_group": m[1], "metric": m[2], "value_type": m[3]} for m in METRICS]
time_cols = [c for _, c, o, _, _ in sorted(TIME_COLS + QUARTER_COLS, key=lambda x: x[2])]
bench_cols = [c for _, c, o, _ in sorted(BENCH_COLS, key=lambda x: x[2])]
cv, bv = {}, {}
# value_display lookups keyed [center][metric][col_label] and [metric][col_label]
for _, r in tidy.iterrows():
    if r["scope"] == "Center":
        cv.setdefault(r["center"], {}).setdefault(r["metric"], {})[r["col_label"]] = r["value_display"]
    elif r["scope"] == "National":
        bv.setdefault(r["metric"], {})[r["col_label"]] = r["value_display"]

# ---- raw per-center rows, so the dashboard can compute any custom date window ----
# One row per order with the few dates/flags the 13 metrics need. Lets the UI answer
# "Jan'25 - Sept'25 vs Oct'25 - May'26" without a pipeline rerun.
RAW_COLS = ["order_request__til_order_name", "iovance_patient_id", "enrollment_date",
            "tumor_pickup_date", "fp_delivery_date", "infusion_date", "completed_ttp",
            "scheduled_ttp", "ttp_cancel_le7", "oos_product", "mfg_started",
            "dropout_post_ttp_health", "drop_after_mfg", "amtagvi_infused",
            "days_enroll_to_ttp", "days_ttp_to_infusion", "days_delivery_to_infusion"]
raw = A[["atc"] + RAW_COLS].copy()
for c in ["enrollment_date", "tumor_pickup_date", "fp_delivery_date", "infusion_date"]:
    raw[c] = pd.to_datetime(raw[c], errors="coerce").dt.strftime("%Y-%m-%d")
for c in ["completed_ttp", "scheduled_ttp", "ttp_cancel_le7", "oos_product", "mfg_started",
          "dropout_post_ttp_health", "drop_after_mfg", "amtagvi_infused"]:
    raw[c] = raw[c].astype(bool).astype(int)
raw = raw.where(pd.notna(raw), None)

if PREVIEW:
    DASH = os.path.join(HERE, "..", "dashboard")
    payload = {"metrics": metrics, "time_cols": time_cols, "bench_cols": bench_cols,
               "event_date": EVENT_DATE,
               "centers": sorted(tidy[tidy.scope == "Center"].center.unique().tolist()),
               "cv": cv, "bv": bv, "asof": TODAY, "synthetic": RUN_META["synthetic"],
               "raw": raw.to_dict(orient="records")}
    os.makedirs(DASH, exist_ok=True)
    json.dump(payload, open(os.path.join(DASH, "scorecard_payload.json"), "w"))
    print(f"preview payload -> dashboard/scorecard_payload.json "
          f"({len(payload['centers'])} centers)")

# ---- wide sample for one center + benchmarks, human eyeball ----
top_center = A.groupby("atc")["order_request__til_order_name"].nunique().idxmax()
sample = tidy[(tidy.center == top_center) | (tidy.scope == "National")].copy()
wide = (sample.sort_values(["metric_order", "col_order"])
        .pivot_table(index=["metric_order", "metric_group", "metric"],
                     columns=["col_order", "col_label"], values="value", aggfunc="first")
        .sort_index(axis=1))
wide.columns = [c[1] for c in wide.columns]
wide = wide.reset_index().drop(columns="metric_order")
print(f"\nSCORECARD for busiest center: {top_center}\n")
with pd.option_context("display.width", 200, "display.max_columns", 20):
    print(wide.to_string(index=False))

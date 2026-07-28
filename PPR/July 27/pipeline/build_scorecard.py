"""
PPR pipeline - Stage 2: compute the P&PR scorecard (tidy long table).

From analysis/ppr_analysis.csv, compute the 13 scorecard metrics for every center
across the time cuts and quarters, plus the national ATC-tier benchmarks. Output is
tidy (one row per center x column x metric) so Tableau just renders it.

Out: analysis/ppr_scorecard_tidy.csv   (the Tableau data source)
"""
import os
import numpy as np
import pandas as pd

HERE = os.path.dirname(__file__)
OUT_DIR = os.path.join(HERE, "..", "analysis")
A = pd.read_csv(os.path.join(OUT_DIR, "ppr_analysis.csv"), low_memory=False)
TODAY = "2026-07-21"   # extract as-of date; keep in step with build_analysis_table.TODAY

# ---- metric registry: exact (Proposed) P&PR Metrics.xlsx template wording ----
M1  = "Enrollments in IovanceCares"
M2  = "Patients Enrolled in IovanceCares"
M3  = "TTPs Cancelled or Rescheduled within 7 Days Prior to Slot Reservation"
M4  = "Completed TTPs"
M5  = "Scheduled TTPs"
M6  = "2nd Resections (Scheduled or Completed)"
M7  = "Patient Related Drop-outs following TTP due to patient health"
M8  = "OOS Products"
M9  = "Patient Progression Rate"
M10 = "AMTAGVI Infusions Performed"
M11 = "Median Time From Enrollment Date to TTP (Days)"
M12 = "Median Time From TTP to AMTAGVI Infusion (Days)"
M13 = "Median Time From Final Product Delivery Date to AMTAGVI Infusion (Days)"
METRICS = [
    (1,  "Patient Identification & Enrollment", M1,  "count"),
    (2,  "Patient Identification & Enrollment", M2,  "count"),
    (3,  "Patient Identification & Enrollment", M3,  "count"),
    (4,  "Tumor Tissue Procurement",            M4,  "count"),
    (5,  "Tumor Tissue Procurement",            M5,  "count"),
    (6,  "Tumor Tissue Procurement",            M6,  "count"),
    (7,  "AMTAGVI Regimen",                     M7,  "count"),
    (8,  "AMTAGVI Regimen",                     M8,  "count"),
    (9,  "AMTAGVI Regimen",                     M9,  "rate"),
    (10, "AMTAGVI Regimen",                     M10, "count"),
    (11, "AMTAGVI Treatment Timelines",         M11, "days"),
    (12, "AMTAGVI Treatment Timelines",         M12, "days"),
    (13, "AMTAGVI Treatment Timelines",         M13, "days"),
]

# Which date each metric is counted on. Confirmed by Kolin's real per-center decks
# (footnote: "Timing metrics based upon the TTP or Infusion Date") - a metric belongs to
# the period its EVENT happened in, not the period the patient enrolled in. So the 2025
# column of "AMTAGVI Infusions Performed" means infusions performed in 2025.
EVENT_DATE = {
    M1:  "enrollment_date",    M2:  "enrollment_date",   M3:  "tumor_pickup_date",
    M4:  "tumor_pickup_date",  M5:  "tumor_pickup_date", M6:  "tumor_pickup_date",
    M7:  "tumor_pickup_date",  M8:  "fp_delivery_date",  M9:  "tumor_pickup_date",
    M10: "infusion_date",      M11: "tumor_pickup_date", M12: "infusion_date",
    M13: "infusion_date",
}

def _win(df, datecol, start, end):
    """Rows whose event date for this metric falls inside the window (None = no bound)."""
    if start is None and end is None:
        return df
    d = pd.to_datetime(df[datecol], errors="coerce")
    m = d.notna()
    if start is not None: m &= d >= pd.Timestamp(start)
    if end   is not None: m &= d <= pd.Timestamp(end)
    return df[m]

def compute(df, start=None, end=None, avg="median", undated=False, future=False):
    """13 metrics. Each is filtered on ITS OWN event date, so a column means
    'what happened in this period', matching Kolin's decks.

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
    # Kolin, Meet 6: the Infinity scorecard shows "the median for all these values".
    agg = (lambda s: s.mean()) if avg == "mean" else (lambda s: s.median())

    mfg = int(w[M9]["mfg_started"].sum())
    drop_after_mfg = int(w[M9]["drop_after_mfg"].sum())
    # 2nd Resections = distinct PATIENTS with 2+ real TTP dates (Kolin, Meet 6)
    ttp = w[M6].dropna(subset=["tumor_pickup_date"])
    mult = ttp.groupby("iovance_patient_id")["tumor_pickup_date"].nunique()

    def days(frame, col):
        v = agg(frame[col].dropna())
        return round(float(v), 1) if pd.notna(v) else np.nan

    return {
        M1:  w[M1]["order_request__til_order_name"].nunique(),
        M2:  w[M2]["iovance_patient_id"].nunique(),
        M3:  int(w[M3]["ttp_cancel_le7"].sum()),
        M4:  int(w[M4]["completed_ttp"].sum()),
        M5:  int(w[M5]["scheduled_ttp"].sum()),
        M6:  int((mult >= 2).sum()),
        M7:  int(w[M7]["dropout_post_ttp_health"].sum()),
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
for center, g in A.groupby("center_key"):
    disp = g["atc"].iloc[0]
    for cg, label, order, st, en in CENTER_COLS:
        emit("Center", disp, cg, label, order, compute(g, st, en))
    emit("Center", disp, UNDATED_COL[0], UNDATED_COL[1], UNDATED_COL[2],
         compute(g, undated=True))
    emit("Center", disp, FUTURE_COL[0], FUTURE_COL[1], FUTURE_COL[2],
         compute(g, future=True))

# national tier benchmarks = per-center MEDIAN within the tier, launch-to-date.
# Kolin (Meet 6): the existing scorecard shows "the median for all these values"; he compared
# a center to "launch-to-date top 10". Median (not sum, not average) resists the big-center
# skew he flagged in Meet 4.5 ("the average is always going to be skewed by certain patients").
def bench_median(tiername):
    per_center = [compute(g) for _, g in A[A.atc_tier == tiername].groupby("center_key")]
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
# side by side. Removed 2026-07-27. Kolin, Meet 6: quartiles "confuse the hell out of our
# sales folks" and "we are actively trying to move away from them". The mandated benchmark
# is the Top 10 / Top 40 / New tier median above, so nothing here is unreplaced.
# It also freed col_order 12-15, which the quartile block shared with Q1'26 and Q4'25.

tidy = pd.DataFrame(rows)

# display helpers so Tableau sorts by plain alpha (no fragile sort specs) and shows
# type-aware text (counts as ints, days 1dp, rate as %).
tidy["row_label"] = tidy["metric_order"].map(lambda i: f"{i:02d}  {[m[2] for m in METRICS if m[0]==i][0]}")
# ---- ASSERTION: every counted event lands in exactly one bucket ----
# Launch to Date must equal the year columns plus Undated plus After as-of. This is the
# invariant that catches silently dropped events: a metric dated on a column that is null
# for exactly the rows it counts (an out-of-spec product never delivered, a procurement
# cancelled so never performed) would otherwise vanish from every period column while still
# appearing in Launch to Date, biasing the periods optimistic.
#
# Applies to ADDITIVE counts only. Patients Enrolled and 2nd Resections are distinct counts
# over patients: one patient with orders in two years is counted once launch-to-date but
# once in each year, so they legitimately do not sum. Excluded by name rather than silently.
NON_ADDITIVE = {M2, M6}
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
print(f"tidy scorecard: {len(tidy)} rows -> analysis/ppr_scorecard_tidy.csv")

# ---- dashboard payload (single source, no ad-hoc inline step) ----
import json
DASH = os.path.join(HERE, "..", "dashboard")   # payload written only if this exists
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

DASH = os.path.join(HERE, "..", "dashboard")
payload = {"metrics": metrics, "time_cols": time_cols, "bench_cols": bench_cols,
           "event_date": EVENT_DATE,
           "centers": sorted(tidy[tidy.scope == "Center"].center.unique().tolist()),
           "cv": cv, "bv": bv, "asof": TODAY,
           "raw": raw.to_dict(orient="records")}
os.makedirs(DASH, exist_ok=True)     # build_dashboard_html.py is a RUN_ALL step, so always write
json.dump(payload, open(os.path.join(DASH, "scorecard_payload.json"), "w"))
print(f"dashboard payload -> dashboard/scorecard_payload.json ({len(payload['centers'])} centers)")

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

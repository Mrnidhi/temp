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
M11 = "Average Time From Enrollment Date to TTP (Days)"
M12 = "Average Time From TTP to AMTAGVI Infusion (Days)"
M13 = "Average Time From Final Product Delivery Date to AMTAGVI Infusion (Days)"
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

def compute(df, start=None, end=None, avg="mean"):
    """13 metrics. Each is filtered on ITS OWN event date, so a column means
    'what happened in this period', matching Kolin's decks."""
    w = {m: _win(df, col, start, end) for m, col in EVENT_DATE.items()}
    agg = (lambda s: s.median()) if avg == "median" else (lambda s: s.mean())

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
    ("Quarter", "Q3'26 QTD", 8,  "2026-07-01", TODAY),
    ("Quarter", "Q2'26",     9,  "2026-04-01", "2026-06-30"),
    ("Quarter", "Q1'26",     10, "2026-01-01", "2026-03-31"),
    ("Quarter", "Q4'25",     11, "2025-10-01", "2025-12-31"),
]
CENTER_COLS = TIME_COLS + QUARTER_COLS
BENCH_COLS = [
    ("Benchmark", "Top 10", 5, "Top 10"),
    ("Benchmark", "Top 40", 6, "Top 40"),
    ("Benchmark", "New",    7, "New"),
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

# ---- Current Template (to retire): the workbook's second sheet ----
# Kolin's old Excel (Meet 6): pick an ATC, see its launch-to-date metrics against
# quartiles and the national average across all centers. Same 13 metrics.
CT_COLS = [
    ("Current", "25th Percentile",  12),
    ("Current", "Median",           13),
    ("Current", "75th Percentile",  14),
    ("Current", "National Average", 15),
]
per_center_ltd = [compute(g) for _, g in A.groupby("center_key")]
ct_vals = {label: {} for _, label, _ in CT_COLS}
for mname in mreg:
    vals = [pc[mname] for pc in per_center_ltd
            if pc[mname] is not None and not (isinstance(pc[mname], float) and np.isnan(pc[mname]))]
    if vals:
        q1, med, q3 = np.percentile(vals, [25, 50, 75])
        ct_vals["25th Percentile"][mname] = float(q1)
        ct_vals["Median"][mname] = float(med)
        ct_vals["75th Percentile"][mname] = float(q3)
        ct_vals["National Average"][mname] = float(np.mean(vals))
    else:
        for _, label, _ in CT_COLS:
            ct_vals[label][mname] = np.nan
for cg, label, order in CT_COLS:
    emit("CurrentTemplate", "National", cg, label, order, ct_vals[label])

tidy = pd.DataFrame(rows)

# display helpers so Tableau sorts by plain alpha (no fragile sort specs) and shows
# type-aware text (counts as ints, days 1dp, rate as %).
tidy["row_label"] = tidy["metric_order"].map(lambda i: f"{i:02d}  {[m[2] for m in METRICS if m[0]==i][0]}")
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
cv, bv, qv = {}, {}, {}
# value_display lookups keyed [center][metric][col_label] and [metric][col_label]
for _, r in tidy.iterrows():
    if r["scope"] == "Center":
        cv.setdefault(r["center"], {}).setdefault(r["metric"], {})[r["col_label"]] = r["value_display"]
    elif r["scope"] == "National":
        bv.setdefault(r["metric"], {})[r["col_label"]] = r["value_display"]
    else:  # CurrentTemplate quartile / average columns
        qv.setdefault(r["metric"], {})[r["col_label"]] = r["value_display"]
ct_cols = [label for _, label, _ in CT_COLS]

# ---- quartile RANGE columns, the way Kolin's real Launch-to-Date slide shows them ----
# Four columns worst -> best, each a range like "1 - 5", and the center's own cell is
# heat-colored by which band it falls in. Lower-is-better metrics have the direction
# flipped so the best band is always rightmost.
LOWER_IS_BETTER = {M3, M7, M8, M9, M13}
qranges, qbounds = {}, {}
for mname in mreg:
    vals = sorted(pc[mname] for pc in per_center_ltd
                  if pc[mname] is not None and not (isinstance(pc[mname], float) and np.isnan(pc[mname])))
    if not vals:
        continue
    cuts = [float(np.min(vals)), *[float(x) for x in np.percentile(vals, [25, 50, 75])], float(np.max(vals))]
    edges = list(zip(cuts[:-1], cuts[1:]))          # ascending bands
    if mname in LOWER_IS_BETTER:
        edges = edges[::-1]                          # worst (highest) first
    vt = mreg[mname][2]
    def f(x):
        return f"{x*100:.2f}%" if vt == "rate" else (f"{x:.1f}" if vt == "days" else f"{int(round(x))}")
    qranges[mname] = [f"{f(a)} - {f(b)}" for a, b in edges]
    qbounds[mname] = [[a, b] for a, b in edges]

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
           "ct_cols": ct_cols, "qv": qv, "qranges": qranges, "qbounds": qbounds,
           "lower_is_better": sorted(LOWER_IS_BETTER),
           "event_date": EVENT_DATE,
           "centers": sorted(tidy[tidy.scope == "Center"].center.unique().tolist()),
           "cv": cv, "bv": bv, "asof": TODAY,
           "raw": raw.to_dict(orient="records")}
if os.path.isdir(DASH):
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

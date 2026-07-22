"""
PPR pipeline - Stage 2: compute the P&PR scorecard (tidy long table).

From analysis/ppr_analysis.csv, compute the 13 scorecard metrics for every center
across the time cuts and quarters, plus the national ATC-tier benchmarks. Output is
tidy (one row per center x column x metric) so Tableau just renders it.

Out: analysis/ppr_scorecard_tidy.csv   (the Tableau data source)
     analysis/ppr_scorecard_wide_sample.csv  (human eyeball for one center)
"""
import os
import numpy as np
import pandas as pd

HERE = os.path.dirname(__file__)
OUT_DIR = os.path.join(HERE, "..", "analysis")
A = pd.read_csv(os.path.join(OUT_DIR, "ppr_analysis.csv"))

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

def compute(df):
    mfg = int(df["mfg_started"].sum())
    # 2nd Resections = distinct PATIENTS with 2+ real TTP dates (Kolin, Meet 6)
    ttp = df.dropna(subset=["tumor_pickup_date"])
    mult = ttp.groupby("iovance_patient_id")["tumor_pickup_date"].nunique()
    second = int((mult >= 2).sum())
    # Patient Progression Rate = patient-related drop-offs after mfg start / mfg starts (template)
    drop_after_mfg = int(df["drop_after_mfg"].sum())
    return {
        M1:  df["order_request__til_order_name"].nunique(),
        M2:  df["iovance_patient_id"].nunique(),
        M3:  int(df["ttp_cancel_le7"].sum()),
        M4:  int(df["completed_ttp"].sum()),
        M5:  int(df["scheduled_ttp"].sum()),
        M6:  second,
        M7:  int(df["dropout_post_ttp_health"].sum()),
        M8:  int(df["oos_product"].sum()),
        M9:  round(drop_after_mfg / mfg, 3) if mfg else np.nan,
        M10: int(df["amtagvi_infused"].sum()),
        M11: round(df["days_enroll_to_ttp"].mean(), 1),
        M12: round(df["days_ttp_to_infusion"].mean(), 1),
        M13: round(df["days_delivery_to_infusion"].mean(), 1),
    }

A["enrollment_date"] = pd.to_datetime(A["enrollment_date"])
A["enroll_year"] = A["enrollment_date"].dt.year
A["enroll_q"] = A["enrollment_date"].dt.to_period("Q").astype(str)

# ---- column definitions: (col_group, label, order, filter fn) ----
TIME_COLS = [
    ("Time", "Launch to Date", 1, lambda d: d),
    ("Time", "2024",           2, lambda d: d[d.enroll_year == 2024]),
    ("Time", "2025",           3, lambda d: d[d.enroll_year == 2025]),
    ("Time", "2026 YTD",       4, lambda d: d[d.enroll_year == 2026]),
]
# template shows quarters most-recent-first (Q3'26 QTD leftmost)
QUARTER_COLS = [
    ("Quarter", "Q3'26 QTD", 8,  lambda d: d[d.enroll_q == "2026Q3"]),
    ("Quarter", "Q2'26",     9,  lambda d: d[d.enroll_q == "2026Q2"]),
    ("Quarter", "Q1'26",     10, lambda d: d[d.enroll_q == "2026Q1"]),
    ("Quarter", "Q4'25",     11, lambda d: d[d.enroll_q == "2025Q4"]),
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
    for cg, label, order, fn in CENTER_COLS:
        emit("Center", disp, cg, label, order, compute(fn(g)))

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
DASH = os.path.join(HERE, "..", "dashboard")
os.makedirs(DASH, exist_ok=True)
metrics = [{"metric_order": m[0], "metric_group": m[1], "metric": m[2], "value_type": m[3]} for m in METRICS]
time_cols = [c for _, c, o, _ in sorted(TIME_COLS + QUARTER_COLS, key=lambda x: x[2])]
bench_cols = [c for _, c, o, _ in sorted(BENCH_COLS, key=lambda x: x[2])]
cv, bv = {}, {}
# value_display lookups keyed [center][metric][col_label] and [metric][col_label]
for _, r in tidy.iterrows():
    if r["scope"] == "Center":
        cv.setdefault(r["center"], {}).setdefault(r["metric"], {})[r["col_label"]] = r["value_display"]
    else:
        bv.setdefault(r["metric"], {})[r["col_label"]] = r["value_display"]
payload = {"metrics": metrics, "time_cols": time_cols, "bench_cols": bench_cols,
           "centers": sorted(tidy[tidy.scope == "Center"].center.unique().tolist()),
           "cv": cv, "bv": bv, "asof": "2026-07-21"}
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
wide.to_csv(os.path.join(OUT_DIR, "ppr_scorecard_wide_sample.csv"), index=False)
print(f"\nSCORECARD for busiest center: {top_center}\n")
with pd.option_context("display.width", 200, "display.max_columns", 20):
    print(wide.to_string(index=False))

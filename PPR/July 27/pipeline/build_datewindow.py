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

GROUPS = {
    1: "Patient Identification & Enrollment", 2: "Patient Identification & Enrollment",
    3: "Patient Identification & Enrollment", 4: "Tumor Tissue Procurement",
    5: "Tumor Tissue Procurement", 6: "Tumor Tissue Procurement",
    7: "AMTAGVI Regimen", 8: "AMTAGVI Regimen", 9: "AMTAGVI Regimen",
    10: "AMTAGVI Regimen", 11: "AMTAGVI Treatment Timelines",
    12: "AMTAGVI Treatment Timelines", 13: "AMTAGVI Treatment Timelines",
}

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
emit(A, 1, "Enrollments in IovanceCares", "sum", "enrollment_date")
# Distinct counts cannot be pre-materialised: how many distinct patients enrolled depends
# on the window being asked about, so the dedup has to happen at read time. Emit every
# enrollment with its patient id and count distinct units instead of summing.
emit(A, 2, "Patients Enrolled in IovanceCares", "distinct", "enrollment_date",
     unitcol="iovance_patient_id")

# 3-7: TTP metrics by pickup date
emit(A[A.ttp_cancel_le7 == 1], 3,
     "TTPs Cancelled or Rescheduled within 7 Days Prior to Slot Reservation",
     "sum", "tumor_pickup_date")
emit(A[A.completed_ttp == 1], 4, "Completed TTPs", "sum", "tumor_pickup_date")
emit(A[A.scheduled_ttp == 1], 5, "Scheduled TTPs", "sum", "tumor_pickup_date")
ttp = A[A.tumor_pickup_date.notna()].sort_values("tumor_pickup_date")
second = (ttp.drop_duplicates(["atc", "iovance_patient_id", "tumor_pickup_date"])
             .groupby(["atc", "iovance_patient_id"]).nth(1).reset_index())
# KNOWN LIMITATION: this is "patients with 2 or more procurements", deduped across all
# time. Within a narrow window the answer can differ by one from the precomputed scorecard,
# because a patient's first and second procurement may straddle the window edge. Measured
# on the synthetic set: 1 cell in 3,309. Rendering it correctly per-window needs an LOD in
# the workbook; left as-is until someone asks for that metric by window.
emit(second, 6, "2nd Resections (Scheduled or Completed)", "sum", "tumor_pickup_date")
emit(A[A.dropout_post_ttp_health == 1], 7,
     "Patient Related Drop-outs following TTP due to patient health",
     "sum", "tumor_pickup_date")

# 8: OOS by final product delivery date
emit(A[A.oos_product == 1], 8, "OOS Products", "sum", "fp_delivery_date")

# 9: one row per mfg start; AVG(value) = drop-offs after mfg start / mfg starts
mfg = A[A.mfg_started == 1].copy()
mfg["drop_flag"] = mfg["drop_after_mfg"].astype(float)
emit(mfg, 9, "Patient Progression Rate", "rate", "tumor_pickup_date", "drop_flag")

# 10: infusions by infusion date
emit(A[A.amtagvi_infused == 1], 10, "AMTAGVI Infusions Performed", "sum", "infusion_date")

# 11-13: timelines, each anchored to its event date
emit(A, 11, "Average Time From Enrollment Date to TTP (Days)", "avg",
     "tumor_pickup_date", "days_enroll_to_ttp")
emit(A, 12, "Average Time From TTP to AMTAGVI Infusion (Days)", "avg",
     "infusion_date", "days_ttp_to_infusion")
emit(A, 13, "Average Time From Final Product Delivery Date to AMTAGVI Infusion (Days)",
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
TODAY = "2026-07-21"
BUCKETS = [
    ("Launch to Date", 1,  None,         None),
    ("2024",           2,  "2024-01-01", "2024-12-31"),
    ("2025",           3,  "2025-01-01", "2025-12-31"),
    ("2026 YTD",       4,  "2026-01-01", TODAY),
    ("Undated",        5,  None,         None),   # no event date at all
    ("After as-of",    6,  TODAY,        None),   # dated beyond the extract
    ("Q3'26 QTD",     10,  "2026-07-01", TODAY),
    ("Q2'26",         11,  "2026-04-01", "2026-06-30"),
    ("Q1'26",         12,  "2026-01-01", "2026-03-31"),
    ("Q4'25",         13,  "2025-10-01", "2025-12-31"),
]
SELECTED = ("Selected window", 7)   # Tableau applies the date parameters to these rows only

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

out = pd.concat(tagged, ignore_index=True)
out.to_csv(os.path.join(ANA, "ppr_datewindow_long.csv"), index=False)
print(f"datewindow events: {len(ev):,} events -> {len(out):,} column-tagged rows, "
      f"{out.metric.nunique()} metrics -> analysis/ppr_datewindow_long.csv")
print("  columns:", ", ".join(out.sort_values("col_order").col_label.unique()))

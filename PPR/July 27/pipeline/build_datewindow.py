"""
PPR pipeline - Stage 3: event-level long table for the dashboard date filter.

One row per metric event, stamped with the date the event happened on, so a
Tableau range-of-dates filter recomputes every metric for any window.

Aggregation contract (column `agg`):
    sum  - counts; SUM(value) over the window
    avg  - timelines; AVG(value) over the window, 1 decimal
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
def emit(df, order, metric, agg, datecol, valcol=None):
    d = df[df[datecol].notna()]
    if valcol:
        d = d[d[valcol].notna()]
    for _, r in d.iterrows():
        rows.append((r["atc"], GROUPS[order], metric, order, agg,
                     r[datecol].strftime("%Y-%m-%d"),
                     float(r[valcol]) if valcol else 1.0))

# 1-2: enrollments by enrollment date; patients deduped to first enrollment
emit(A, 1, "Enrollments in IovanceCares", "sum", "enrollment_date")
first = A.sort_values("enrollment_date").drop_duplicates("iovance_patient_id")
emit(first, 2, "Patients Enrolled in IovanceCares", "sum", "enrollment_date")

# 3-7: TTP metrics by pickup date
emit(A[A.ttp_cancel_le7 == 1], 3,
     "TTPs Cancelled or Rescheduled within 7 Days Prior to Slot Reservation",
     "sum", "tumor_pickup_date")
emit(A[A.completed_ttp == 1], 4, "Completed TTPs", "sum", "tumor_pickup_date")
emit(A[A.scheduled_ttp == 1], 5, "Scheduled TTPs", "sum", "tumor_pickup_date")
ttp = A[A.tumor_pickup_date.notna()].sort_values("tumor_pickup_date")
second = (ttp.drop_duplicates(["iovance_patient_id", "tumor_pickup_date"])
             .groupby("iovance_patient_id").nth(1).reset_index())
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

out = pd.DataFrame(rows, columns=["center", "metric_group", "metric", "metric_order",
                                  "agg", "event_date", "value"])
out.to_csv(os.path.join(ANA, "ppr_datewindow_long.csv"), index=False)
print(f"datewindow events: {len(out)} rows, {out.metric.nunique()} metrics "
      f"-> analysis/ppr_datewindow_long.csv")

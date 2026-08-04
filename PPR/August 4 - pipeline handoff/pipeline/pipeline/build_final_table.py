"""
PPR pipeline - Stage 5: write the final table as CSV.

The dashboard reads ONE table: the event-level long table. Written here as CSV in the
exact column order the Redshift table uses, so the same file can be loaded straight into
ppr.ppr_events or handed to anyone rebuilding this job for comparison.

Two reference exports go alongside it. Neither drives the dashboard.

Out: output/ppr_events.csv      the final table
     output/ppr_scorecard.csv   the precomputed scorecard, for checking cell by cell
     output/ppr_analysis.csv    one row per order with the derived flags
"""
import os

import pandas as pd

HERE = os.path.dirname(__file__)
ANA = os.path.join(HERE, "..", "analysis")
OUT = os.path.join(HERE, "..", "output")
os.makedirs(OUT, exist_ok=True)

# The column contract, verbatim and in order. Same list as create_events_table.sql; a
# rename or a reorder here silently breaks the Redshift copy, so it is asserted below.
EVENTS_COLUMNS = ["center", "metric_group", "metric", "metric_order", "agg", "event_date",
                  "value", "unit", "col_label", "col_order", "cell_color", "col_group",
                  "col_group_order"]

# Order-grain columns worth carrying. The rest of the order table is free-text noise.
ANALYSIS_COLUMNS = ["order_request__til_order_name", "iovance_patient_id", "atc", "center_key",
                    "veeva_name", "region", "territory", "atc_segment", "center_matched",
                    "atc_tier", "enrollment_date", "enroll_year", "enroll_q",
                    "tumor_pickup_date", "infusion_date", "fp_delivery_date", "order_status",
                    "fp_status", "oos_status", "til_order_cancellation_reason", "has_slot",
                    "has_tumor", "has_infusion", "amtagvi_infused", "completed_ttp",
                    "scheduled_ttp", "oos_product", "mfg_started", "dropout_post_ttp_health",
                    "patient_related_dropout", "drop_after_mfg", "ttp_cancel_le7", "tpf_count",
                    "days_enroll_to_ttp", "days_ttp_to_infusion", "days_delivery_to_infusion"]

BOOL_COLUMNS = ["center_matched", "has_slot", "has_tumor", "has_infusion", "amtagvi_infused",
                "completed_ttp", "scheduled_ttp", "oos_product", "mfg_started",
                "dropout_post_ttp_health", "patient_related_dropout", "drop_after_mfg",
                "ttp_cancel_le7"]


def write(df, name):
    path = os.path.join(OUT, name)
    df.to_csv(path, index=False)
    print(f"{name}: {len(df):,} rows x {df.shape[1]} cols")
    return path


# ---- the final table ------------------------------------------------------------------
ev = pd.read_csv(os.path.join(ANA, "ppr_datewindow_long.csv"), low_memory=False)

missing = [c for c in EVENTS_COLUMNS if c not in ev.columns]
extra = [c for c in ev.columns if c not in EVENTS_COLUMNS]
assert not missing, f"the event table is missing {missing}; the Redshift copy would fail"
assert not extra, f"the event table has unexpected column(s) {extra}; update EVENTS_COLUMNS " \
                  "and create_events_table.sql together or the copy loads into the wrong columns"

# Dates as plain YYYY-MM-DD. Blank means the event genuinely has no date, which is a real
# state here (see the Undated column), so it must stay blank rather than become a zero date.
ev["event_date"] = pd.to_datetime(ev["event_date"], errors="coerce").dt.strftime("%Y-%m-%d")

for col in ["metric_order", "col_order", "col_group_order"]:
    assert ev[col].notna().all(), f"{col} has blanks; it is an int column in Redshift"
    ev[col] = ev[col].astype(int)

# Every row must carry a centre or it vanishes from the dashboard's centre filter.
blank_center = int(ev["center"].isna().sum())
assert blank_center == 0, f"{blank_center} rows have no centre"

ev = ev[EVENTS_COLUMNS]
write(ev, "ppr_events.csv")

# ---- reference exports ----------------------------------------------------------------
tidy = pd.read_csv(os.path.join(ANA, "ppr_scorecard_tidy.csv"))
write(tidy, "ppr_scorecard.csv")

ana = pd.read_csv(os.path.join(ANA, "ppr_analysis.csv"), low_memory=False)
ana = ana[[c for c in ANALYSIS_COLUMNS if c in ana.columns]].copy()
for c in BOOL_COLUMNS:
    if c in ana.columns:
        ana[c] = ana[c].astype("boolean")
write(ana, "ppr_analysis.csv")

print("final table ->", os.path.abspath(os.path.join(OUT, "ppr_events.csv")))

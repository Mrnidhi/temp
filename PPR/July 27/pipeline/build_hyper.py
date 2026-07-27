"""
PPR pipeline - Tableau extracts. Writes native .hyper sources for Tableau Desktop.

- tableau/ppr_scorecard.hyper  (table "Scorecard"): the pre-shaped tidy matrix. Primary
  source for the mandated scorecard - Tableau pivots metric x column-label, no heavy calcs.
- tableau/ppr_analysis.hyper   (table "Orders"): order-grain rows with the derived flags and
  dates, for native calc-field builds (the 13 metrics as Tableau calcs) and custom views.

Repoint story: on the office laptop, rerun the pipeline on the real Infinity files, rerun this,
then refresh the workbook's extract. .hyper is Tableau's native format, so this is the robust
source to build against.
"""
import os
import pandas as pd
import pantab

HERE = os.path.dirname(__file__)
ANA = os.path.join(HERE, "..", "analysis")
OUT = os.path.join(HERE, "..", "tableau")
os.makedirs(OUT, exist_ok=True)

DATE_COLS = ["enrollment_date", "tumor_pickup_date", "fp_delivery_date", "infusion_date",
             "order_request__created_date", "final_product_shipping_date",
             "suggested_infusion_date"]

def clean_text(df):
    """Coerce object columns to pandas string dtype so pantab writes clean TEXT columns."""
    for c in df.columns:
        if df[c].dtype == object:
            df[c] = df[c].astype("string")
    return df

# ---- 1. tidy scorecard (primary matrix source) ----
tidy = pd.read_csv(os.path.join(ANA, "ppr_scorecard_tidy.csv"))
tidy["col_order"] = tidy["col_order"].astype("int32")
tidy["metric_order"] = tidy["metric_order"].astype("int32")
tidy["value"] = pd.to_numeric(tidy["value"], errors="coerce").astype("float64")
tidy = clean_text(tidy)
sc_path = os.path.join(OUT, "ppr_scorecard.hyper")
if os.path.exists(sc_path):
    os.remove(sc_path)
pantab.frame_to_hyper(tidy, sc_path, table="Scorecard")
print(f"ppr_scorecard.hyper: {len(tidy)} rows, table 'Scorecard'")

# ---- 2. order-grain analysis (native calc-field source) ----
ana = pd.read_csv(os.path.join(ANA, "ppr_analysis.csv"), low_memory=False)
for c in DATE_COLS:
    if c in ana.columns:
        ana[c] = pd.to_datetime(ana[c], errors="coerce")
# keep the columns a Tableau metric build actually needs (drop free-text noise)
keep = ["order_request__til_order_name", "iovance_patient_id", "atc", "center_key",
        "veeva_name", "region", "territory", "atc_segment", "center_matched", "atc_tier",
        "enrollment_date", "enroll_year", "enroll_q", "tumor_pickup_date", "infusion_date",
        "fp_delivery_date", "order_status", "fp_status", "oos_status",
        "til_order_cancellation_reason", "has_slot", "has_tumor", "has_infusion",
        "amtagvi_infused", "completed_ttp", "scheduled_ttp", "oos_product", "mfg_started",
        "dropout_post_ttp_health", "patient_related_dropout", "drop_after_mfg",
        "ttp_cancel_le7", "tpf_count", "days_enroll_to_ttp", "days_ttp_to_infusion",
        "days_delivery_to_infusion"]
ana = ana[[c for c in keep if c in ana.columns]].copy()
# bool-ish columns to real booleans
for c in ["center_matched", "has_slot", "has_tumor", "has_infusion", "amtagvi_infused",
          "completed_ttp", "scheduled_ttp", "oos_product", "mfg_started",
          "dropout_post_ttp_health", "patient_related_dropout", "drop_after_mfg", "ttp_cancel_le7"]:
    if c in ana.columns:
        ana[c] = ana[c].astype("boolean")
ana = clean_text(ana)
an_path = os.path.join(OUT, "ppr_analysis.hyper")
if os.path.exists(an_path):
    os.remove(an_path)
pantab.frame_to_hyper(ana, an_path, table="Orders")
print(f"ppr_analysis.hyper: {len(ana)} rows x {ana.shape[1]} cols, table 'Orders'")
print("Tableau extracts written ->", OUT)

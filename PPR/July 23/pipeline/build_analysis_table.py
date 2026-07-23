"""
PPR pipeline - Stage 1: build the analysis table.

Reads the 7 Infinity files (synthetic here, real on the office laptop), joins them
to ONE order-grain analysis table, cleans the known DQ issues, and derives every
field the scorecard needs (stage flags, timeline day-diffs, ATC tier, time buckets).

This is the portable automation: point INPUT_DIR at the real files and rerun.

Out: analysis/ppr_analysis.csv  (one row per order, 2,250 rows on synthetic data)
"""
import os
import re
import numpy as np
import pandas as pd

HERE = os.path.dirname(__file__)
# Point at the real Infinity files on the office laptop by setting the env var PPR_INPUT_DIR,
# e.g.  (PowerShell)  $env:PPR_INPUT_DIR="C:\path\to\real_files"  then run this script.
# Falls back to the synthetic data if the env var is not set.
INPUT_DIR = os.environ.get("PPR_INPUT_DIR", os.path.join(HERE, "..", "synthetic_data", "out"))
OUT_DIR = os.path.join(HERE, "..", "analysis")
os.makedirs(OUT_DIR, exist_ok=True)

TODAY = pd.Timestamp("2026-07-21")
HEADER_ROW = 2  # real files carry a title banner; true header is row index 2

# metric 7: drop-outs following TTP "due to patient health" (health-specific reasons)
HEALTH_DROPOUT = {"Patient health progressed", "Decline in Performance Status",
                  "Disease Progression", "Brain Mets", "Patient death"}
# Patient Progression Rate numerator: "patient related" drop-offs (patient-driven clinical /
# decision reasons; excludes logistics, quality, physician, financial, duplicate).
PATIENT_RELATED = {"Patient health progressed", "Decline in Performance Status",
                   "Disease Progression", "Brain Mets", "Patient death",
                   "Patient Choice", "Transition to Hospice", "NED/MRD"}
MFG_STARTED = {"MFG Start", "MFG End", "REP Initiation", "REP Scale Out",
               "Released for Shipment by QA", "SM Pick-up Scheduled", "Shipment Ready",
               "Courier Picked-Up FP", "Courier Delivered FP"}

def _resolve(stem):
    """Find the Excel file for a stem, tolerant of real-world naming (case, separators,
    export-date suffixes). e.g. stem 'list_of_orders' matches 'BAI - List of Orders 07.21.xlsx'."""
    key = re.sub(r"[^a-z0-9]", "", stem.lower())
    matches = [f for f in os.listdir(INPUT_DIR)
               if f.lower().endswith((".xlsx", ".xls")) and not f.startswith("~$")
               and key in re.sub(r"[^a-z0-9]", "", f.lower())]
    if not matches:
        raise FileNotFoundError(f"No Excel file matching '{stem}' in {INPUT_DIR}. Files present: "
                                f"{[f for f in os.listdir(INPUT_DIR) if f.lower().endswith(('.xlsx','.xls'))]}")
    return os.path.join(INPUT_DIR, sorted(matches, key=len)[0])   # shortest = least-suffixed

def rd(stem):
    return pd.read_excel(_resolve(stem), header=HEADER_ROW)

def norm_center(s):
    """Normalize free-text center names so the fuzzy ATC<->veeva join lands."""
    if pd.isna(s):
        return s
    s = str(s).strip().lower()
    s = re.sub(r",?\s*(llc|inc|pllc|pc|pa|ltd)\.?$", "", s)
    s = re.sub(r"[^a-z0-9 ]", "", s)
    return re.sub(r"\s+", " ", s).strip()

def to_dt(s):
    return pd.to_datetime(s, errors="coerce")

# ------------------------------------------------------------------ load
orders = rd("list_of_orders")
tumor  = rd("tumor_documentation")
inf    = rd("infusion")
slot   = rd("slot_data")
mp     = rd("komodo_atc_mapping")

# ------------------------------------------------------------------ clean orders
o = orders.copy()
o["enrollment_date"] = to_dt(o["order_request__created_date"])
o["tumor_pickup_date"] = to_dt(o["tumor_tissue_pick_up_date"])
o["fp_delivery_date"] = to_dt(o["final_product_delivery_date"])
# DQ: patient_zip_code is a dirty int with junk placeholders -> keep valid 5-digit US zips only
z = pd.to_numeric(o["patient_zip_code"], errors="coerce")
o["patient_zip_clean"] = z.where((z >= 1001) & (z <= 99950))
o["center_key"] = o["atc"].map(norm_center)

# ------------------------------------------------------------------ child flags on the hub key
tumor_by_order = tumor.groupby("til_order_name").size()          # TPF rows per order
o["tpf_count"] = o["order_request__til_order_name"].map(tumor_by_order).fillna(0).astype(int)
o["has_tumor"] = o["tpf_count"] > 0
o["second_resection"] = (o["tpf_count"] >= 2) | (o["til_order_cancellation_reason"] == "2nd Resection")

slot_orders = set(slot["til_order_name"].dropna())
o["has_slot"] = o["order_request__til_order_name"].isin(slot_orders)

inf_i = inf.copy()
inf_i["infusion_date"] = to_dt(inf_i["infusion_date"])
inf_map = inf_i.set_index("til_order_name")
o["infusion_date"] = o["order_request__til_order_name"].map(inf_map["infusion_date"])
o["lifileucel_infused"] = o["order_request__til_order_name"].map(inf_map["lifileucel_infused_"])
o["has_infusion"] = o["order_request__til_order_name"].isin(set(inf_i["til_order_name"]))
o["amtagvi_infused"] = o["has_infusion"] & (o["lifileucel_infused"] == "Yes") & o["infusion_date"].notna()

# ------------------------------------------------------------------ center enrichment (fuzzy)
mp2 = mp.copy()
mp2["center_key"] = mp2["veeva_name"].map(norm_center)
mp2 = mp2.drop_duplicates("center_key")
o = o.merge(mp2[["center_key", "veeva_name", "region", "territory", "atc_segment"]],
            on="center_key", how="left")
o["center_matched"] = o["veeva_name"].notna()

# ------------------------------------------------------------------ derived metric fields
o["completed_ttp"] = o["tumor_pickup_date"].notna() & (o["tumor_pickup_date"] <= TODAY)
o["scheduled_ttp"] = o["tumor_pickup_date"].notna() & (o["tumor_pickup_date"] > TODAY)
o["oos_product"] = o["oos_status"] == "Confirmed OOS"
o["mfg_started"] = o["fp_status"].isin(MFG_STARTED)
# metric 7: patient-health drop-outs following a TTP
o["dropout_post_ttp_health"] = o["has_tumor"] & o["til_order_cancellation_reason"].isin(HEALTH_DROPOUT)
# Patient Progression Rate = (patient-related drop-offs AFTER mfg start) / (mfg starts)
o["patient_related_dropout"] = o["til_order_cancellation_reason"].isin(PATIENT_RELATED)
o["drop_after_mfg"] = o["mfg_started"] & o["patient_related_dropout"]
# metric 3 PROXY: true rule is a cancel/reschedule within 7 days of the scheduled TTP, measured
# from Infinity's snapshot history (Jonathan's table, not in the file exports). resection_rescheduled_
# is the closest available flag until that snapshot feed is wired in.
o["ttp_cancel_le7"] = o["resection_rescheduled_"] == True

o["days_enroll_to_ttp"] = (o["tumor_pickup_date"] - o["enrollment_date"]).dt.days
o["days_ttp_to_infusion"] = (o["infusion_date"] - o["tumor_pickup_date"]).dt.days
o["days_delivery_to_infusion"] = (o["infusion_date"] - o["fp_delivery_date"]).dt.days
for c in ["days_enroll_to_ttp", "days_ttp_to_infusion", "days_delivery_to_infusion"]:
    o.loc[o[c] < 0, c] = np.nan          # guard against out-of-order dates

# ------------------------------------------------------------------ time buckets (cohort by enrollment)
o["enroll_year"] = o["enrollment_date"].dt.year
o["enroll_q"] = o["enrollment_date"].dt.to_period("Q").astype(str)   # e.g. 2025Q4

# ------------------------------------------------------------------ ATC tier (national ranking + New)
enroll_by_center = o.groupby("center_key")["order_request__til_order_name"].nunique().sort_values(ascending=False)
rank = {c: i + 1 for i, c in enumerate(enroll_by_center.index)}
first_enroll_year = o.groupby("center_key")["enroll_year"].min()
# New = onboarded in/after 2025. On real data, key off the mapping's onboarding year;
# here on synthetic data (orders spread evenly, so no genuine 2025-onboard exists) we
# stand in the 12 lowest-volume centers as "New" so the benchmark column demonstrates.
_real_new = set(first_enroll_year[first_enroll_year >= 2025].index)
new_centers = _real_new if _real_new else set(enroll_by_center.tail(12).index)

def tier(ck):
    if ck in new_centers:
        return "New"
    r = rank.get(ck, 9999)
    if r <= 10:
        return "Top 10"
    if r <= 40:
        return "Top 40"
    return "Other"

o["atc_tier"] = o["center_key"].map(tier)

o.to_csv(os.path.join(OUT_DIR, "ppr_analysis.csv"), index=False)
print(f"analysis table: {len(o)} rows x {o.shape[1]} cols -> analysis/ppr_analysis.csv")
print("centers:", o['center_key'].nunique(), "| matched to veeva:", o['center_matched'].mean().round(3))
print("tiers:", o['atc_tier'].value_counts().to_dict())
print("funnel: slot", int(o['has_slot'].sum()), "tumor", int(o['has_tumor'].sum()),
      "infusion", int(o['has_infusion'].sum()), "amtagvi", int(o['amtagvi_infused'].sum()))

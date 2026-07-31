"""
PPR pipeline - Stage 1: build the analysis table.

Reads the 7 Infinity files (synthetic here, real on the office laptop), joins them
to ONE order-grain analysis table, cleans the known DQ issues, and derives every
field the scorecard needs (stage flags, timeline day-diffs, ATC tier, time buckets).

This is the portable automation: point INPUT_DIR at the real files and rerun.

Out: analysis/ppr_analysis.csv  (one row per order, 2,250 rows on synthetic data)
"""
import json
import os
import re
import numpy as np
import pandas as pd

from cancellations import norm_center   # shared name normalizer (also used by stage 2)

HERE = os.path.dirname(__file__)
# Input resolution, first match wins:
#   1. PPR_INPUT_DIR env var
#   2. data/ next to RUN_ALL.py (office laptop: drop the 7 Infinity .xlsx there)
#   3. synthetic sample (Mac dev only)
_CANDIDATES = [os.environ.get("PPR_INPUT_DIR"),
               os.path.join(HERE, "..", "data"),
               os.path.join(HERE, "..", "synthetic_data", "out")]
INPUT_DIR = next(p for p in _CANDIDATES
                 if p and os.path.isdir(p) and any(f.endswith(".xlsx") for f in os.listdir(p)))
print("input:", os.path.abspath(INPUT_DIR))
OUT_DIR = os.path.join(HERE, "..", "analysis")
os.makedirs(OUT_DIR, exist_ok=True)

HEADER_ROW = 2  # real files carry a title banner; true header is row index 2

# As-of date. Never read the clock: same inputs must give the same outputs on any day.
# PPR_ASOF (YYYY-MM-DD) wins when set; otherwise the newest order-creation date in the
# extract stands in for the export date, since orders are created daily across 85
# centers. Recorded in analysis/run_meta.json and shown on every output.
_ASOF_ENV = os.environ.get("PPR_ASOF")

# Cancellation reasons, categorised once. Metrics reference the categories, never raw
# strings, so the difference between metric 7 and metric 9 is one visible line here
# instead of two hardcoded sets that can drift apart.
#   health    clinical deterioration
#   choice    patient-driven, non-clinical
#   favourable  came off the pathway because treatment was not needed
REASON_CATEGORY = {
    "Patient health progressed":      "health",
    "Decline in Performance Status":  "health",
    "Disease Progression":            "health",
    "Brain Mets":                     "health",
    "Patient death":                  "health",
    "Transition to Hospice":          "health",   # hospice transition is clinical, not choice
    "Patient Choice":                 "choice",
    "NED/MRD":                        "favourable",
    # Everything below is NOT patient-related, so it counts toward neither metric 7 nor 9.
    # Listed explicitly so the categorisation is a decision on the record, not an omission.
    "2nd Resection":                     "operational",  # planned re-procurement, not a drop-out
    "Duplicate Patient":                 "operational",  # data artefact
    "Physician decision":                "physician",
    "Alternate Therapy":                 "physician",
    "Clinical Trial/IST/Collaboration":  "physician",
    "Financial Clearance":               "access",
    "Peer to Peer Consult":              "access",
    "Quality Status: Do Not Proceed":    "quality",
    "Other":                             "other",
    # Exact strings seen in the REAL picklist (10 values). Kept alongside the synthetic
    # spellings above because the two sets do not match.
    "Quality: Do Not Proceed":           "quality",
    "Clinical Trial/IST":                "physician",
    "Peer-to-Peer":                      "access",
    # Exact strings confirmed against the source picklist (2026-07-30). These are the two
    # values the build had been warning about: same reasons as the entries above, spelled
    # differently in the data. Categories unchanged, so no metric value moves; this only
    # stops them falling into no bucket.
    "Clinical Trial /IST/ Collaboration": "physician",
    "Peer to Peer Consult Decision":      "access",
}
# Seen in pick_up_cancellation_reason / fp_delivery_cancellation_reason but NOT in
# til_order_cancellation_reason, which is the only reason column the metrics read. They
# categorise nothing today. Each needs a category before either column is used:
#   Acute Event, Hospital Schedule Conflict, ATC Switching Patients,
#   Tumor No Longer Amenable to Surgery, FP Hold, Patient First, Treatment on Hold
# metric 7: drop-outs following TTP due to patient health
HEALTH_DROPOUT = {r for r, c in REASON_CATEGORY.items() if c == "health"}
# metric 9 numerator: patient-related drop-offs after manufacturing started.
# NED/MRD is deliberately excluded: no evidence of disease means the patient responded,
# so counting it as progression would report a good outcome as a failure.
PATIENT_RELATED = {r for r, c in REASON_CATEGORY.items() if c in ("health", "choice")}
# Manufacturing actually started. SM = starting material (the tumour courier leg), which
# happens BEFORE manufacturing, so the two SM states are deliberately excluded. On real
# data "SM Pick-up Scheduled" alone is 305 orders, so including it would inflate metric 9's
# denominator by roughly a third and understate the progression rate.
MFG_STARTED = {"MFG Start", "MFG End", "REP Initiation", "REP Scale Out",
               "Released for Shipment by QA", "Shipment Ready",
               "Courier Picked-Up FP", "Courier Delivered FP", "FP CAH"}
SM_PRE_MFG = {"SM Pick-up Scheduled", "Courier Picked-Up SM", "Warehouse Received SM",
              "MFG QA Released SM", "MFG Received SM"}   # pre-manufacturing, never counted

def _norm(s):
    return re.sub(r"[^a-z0-9]", "", str(s).lower())

def _resolve(stem):
    """Find the Excel file for a stem, tolerant of real-world naming (case, separators,
    export-date suffixes). e.g. stem 'list_of_orders' matches 'BAI - List of Orders 07.21.xlsx'."""
    key = _norm(stem)
    matches = [f for f in os.listdir(INPUT_DIR)
               if f.lower().endswith((".xlsx", ".xls")) and not f.startswith("~$")
               and key in _norm(f)]
    # 'bai_list_of_orders_hist' CONTAINS 'list_of_orders'. That file is the snapshot history:
    # several rows per order, read by build_cancellations.py. Reading it as the orders table
    # would multiply every count with no error, so it is never a match for a non-hist stem.
    if "hist" not in key:
        matches = [f for f in matches if "hist" not in _norm(f)]
    if not matches:
        raise FileNotFoundError(f"No Excel file matching '{stem}' in {INPUT_DIR}. Files present: "
                                f"{[f for f in os.listdir(INPUT_DIR) if f.lower().endswith(('.xlsx','.xls'))]}")
    # Shortest name = least-suffixed. Refuse instead of guessing when two genuinely different
    # files still match: a silently wrong input file poisons every number downstream.
    chosen = sorted(matches, key=len)[0]
    ambiguous = [f for f in matches if abs(len(f) - len(chosen)) > 6]
    if ambiguous:
        raise FileNotFoundError(
            f"'{stem}' matches more than one file in {INPUT_DIR}: {sorted(matches)}. "
            "Remove or rename the ones that are not the current export.")
    return os.path.join(INPUT_DIR, chosen)

def rd(stem):
    return pd.read_excel(_resolve(stem), header=HEADER_ROW)

def to_dt(s):
    return pd.to_datetime(s, errors="coerce")

# ------------------------------------------------------------------ load
orders = rd("list_of_orders")
tumor  = rd("tumor_documentation")
inf    = rd("infusion")
slot   = rd("slot_data")
mp     = rd("komodo_atc_mapping")

# ------------------------------------------------------------------ as-of + run metadata
if _ASOF_ENV:
    TODAY = pd.Timestamp(_ASOF_ENV)
else:
    TODAY = to_dt(orders["order_request__created_date"]).max()
    if pd.isna(TODAY):
        raise SystemExit("Cannot derive an as-of date: no parseable order creation dates. "
                         "Set PPR_ASOF=YYYY-MM-DD and rerun.")
_meta = {"asof": TODAY.strftime("%Y-%m-%d"),
         "asof_source": "PPR_ASOF" if _ASOF_ENV else "max order_request__created_date",
         "input_dir": os.path.abspath(INPUT_DIR),
         "synthetic": "synthetic" in os.path.abspath(INPUT_DIR).lower()}
with open(os.path.join(OUT_DIR, "run_meta.json"), "w") as _f:
    json.dump(_meta, _f, indent=1)
print(f"as-of: {_meta['asof']} ({_meta['asof_source']})  synthetic: {_meta['synthetic']}")

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
# Completed and Scheduled TTPs are disjoint by definition (pickup date past vs future), so
# they can be added for a total procurement count. Not the same as the retired "Patients
# Scheduled for TTP", which was cumulative.
o["completed_ttp"] = o["tumor_pickup_date"].notna() & (o["tumor_pickup_date"] <= TODAY)
o["scheduled_ttp"] = o["tumor_pickup_date"].notna() & (o["tumor_pickup_date"] > TODAY)
o["oos_product"] = o["oos_status"] == "Confirmed OOS"
o["mfg_started"] = o["fp_status"].isin(MFG_STARTED)
# metric 7: patient-health drop-outs following a TTP
o["dropout_post_ttp_health"] = o["has_tumor"] & o["til_order_cancellation_reason"].isin(HEALTH_DROPOUT)
# Patient Progression Rate = (patient-related drop-offs AFTER mfg start) / (mfg starts)
o["patient_related_dropout"] = o["til_order_cancellation_reason"].isin(PATIENT_RELATED)
o["drop_after_mfg"] = o["mfg_started"] & o["patient_related_dropout"]
# Fallback only. The real rule needs the snapshot history; resection_rescheduled_ is the
# closest flag available from the file exports and fires far too often to be trusted.
o["ttp_cancel_le7"] = o["resection_rescheduled_"] == True

# Guard rails: a new reason or status from Infinity must fail the build, not fall
# silently into no bucket and quietly change a metric.
_seen = set(o["til_order_cancellation_reason"].dropna().unique())
_new = _seen - set(REASON_CATEGORY)
if _new:
    print(f"  WARNING: {len(_new)} unmapped cancellation reason(s), treated as uncategorised "
          f"and excluded from metrics 7 and 9: {sorted(_new)}")
    print("  -> add them to REASON_CATEGORY before trusting those two metrics.")
    # A spacing variant of a known reason and a genuinely new reason need different fixes.
    def _squash(s):
        return "".join(str(s).lower().split()).replace("-", "")
    _known = {_squash(k): k for k in REASON_CATEGORY}
    for _r in sorted(_new):
        _hit = _known.get(_squash(_r))
        if _hit:
            print(f"     '{_r}'  looks like a spacing variant of '{_hit}' "
                  f"({REASON_CATEGORY[_hit]}) - add the exact string above")
        else:
            print(f"     '{_r}'  is genuinely new - needs a category")

o["days_enroll_to_ttp"] = (o["tumor_pickup_date"] - o["enrollment_date"]).dt.days
o["days_ttp_to_infusion"] = (o["infusion_date"] - o["tumor_pickup_date"]).dt.days
o["days_delivery_to_infusion"] = (o["infusion_date"] - o["fp_delivery_date"]).dt.days
for c in ["days_enroll_to_ttp", "days_ttp_to_infusion", "days_delivery_to_infusion"]:
    o.loc[o[c] < 0, c] = np.nan          # guard against out-of-order dates

# ------------------------------------------------------------------ time buckets (cohort by enrollment)
o["enroll_year"] = o["enrollment_date"].dt.year
o["enroll_q"] = o["enrollment_date"].dt.to_period("Q").astype(str)   # e.g. 2025Q4

# ------------------------------------------------------------------ ATC tier
# Top 10 / Top 40 / New, ranked from enrolment counts on every run, so a centre that climbs
# into the top ten displaces another on the next run. The commercial segmentation
# (atc_segment) is joined on and available, but it uses internal labels a centre would not
# recognise, so it does not drive the comparison arm.
enroll_by_center = o.groupby("center_key")["order_request__til_order_name"].nunique().sort_values(ascending=False)
rank = {c: i + 1 for i, c in enumerate(enroll_by_center.index)}
first_enroll_year = o.groupby("center_key")["enroll_year"].min()
# New = first enrolment in or after 2025. This is a proxy: the mapping carries no onboarding
# date, and start_segment is an incentive-programme field rather than a lifecycle stage, so a
# centre that enrolled once before 2025 is mislabelled. Needs an authoritative list.
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

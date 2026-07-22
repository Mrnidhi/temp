"""
Generate a synthetic stand-in for the 7 Infinity Excel files.

Matches the office-laptop schema profile exactly: same file names, same columns,
dtypes, null rates, categorical value sets, ID formats, date ranges, and the
order -> slot -> tumor -> infusion funnel with the real overlap counts.

No real data is used. Output is a drop-in shape match, so a Tableau workbook built
on these files can be repointed to the real Infinity files by a connection swap.

Run:  python generate_synthetic.py
Out:  ./out/*.xlsx  (title banner in row 1, headers in row 3, matching the real layout)
"""
import os
import string
import numpy as np
import pandas as pd

SEED = 42
rng = np.random.default_rng(SEED)
OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)

# ----------------------------------------------------------------------------- helpers
def tokens(pattern, n, unique=True):
    """Expand a mask: X=uppercase letter, #=digit, other chars literal. Return n strings."""
    seen, out = set(), []
    letters = np.array(list(string.ascii_uppercase))
    while len(out) < n:
        s = []
        for ch in pattern:
            if ch == "X":
                s.append(rng.choice(letters))
            elif ch == "#":
                s.append(str(rng.integers(0, 10)))
            else:
                s.append(ch)
        val = "".join(s)
        if unique and val in seen:
            continue
        seen.add(val)
        out.append(val)
    return out

def sample_dates(n, dmin, dmax, dmed, skew=None):
    """Sample n dates in [dmin, dmax] concentrated near the median."""
    lo, hi, med = (pd.Timestamp(x) for x in (dmin, dmax, dmed))
    span = (hi - lo).days
    mode_frac = np.clip((med - lo).days / span, 0.05, 0.95)
    # triangular gives control of the peak (median-ish) inside the range
    frac = rng.triangular(0.0, mode_frac, 1.0, size=n)
    return np.array([lo + pd.Timedelta(days=int(f * span)) for f in frac], dtype="datetime64[ns]")

def nullify(arr, rate):
    """Set ~rate fraction of entries to NaN/NaT/None (object dtype friendly)."""
    a = pd.Series(list(arr), dtype="object")
    mask = rng.random(len(a)) < rate
    a[mask] = None
    return a

def cat(n, values, weights=None):
    return rng.choice(values, size=n, p=weights)

def free_text(n, distinct, prefix):
    pool = [f"{prefix} note {i}" for i in range(distinct)]
    return rng.choice(pool, size=n)

def names(n, distinct, kind="Dr"):
    first = ["Alex","Sam","Jordan","Taylor","Morgan","Casey","Riley","Jamie","Avery","Quinn",
             "Drew","Reese","Skyler","Rowan","Emerson","Hayden","Parker","Sage","Blake","Cameron"]
    last = ["Nguyen","Patel","Garcia","Kim","Smith","Johnson","Lee","Martinez","Brown","Davis",
            "Lopez","Wilson","Anderson","Thomas","Chen","Rao","Shah","Cohen","Murphy","Reyes"]
    pool = []
    i = 0
    while len(pool) < distinct:
        f = first[i % len(first)]
        l = last[(i // len(first)) % len(last)]
        pool.append(f"{kind} {f} {l}".strip() if kind else f"{f} {l}")
        i += 1
    return rng.choice(pool[:distinct], size=n)

def write_xlsx(df, fname, title):
    """Write with a title banner in row 1 and headers in row 3 (index 2), matching real files."""
    path = os.path.join(OUT, fname)
    with pd.ExcelWriter(path, engine="openpyxl") as xl:
        df.to_excel(xl, index=False, startrow=2, sheet_name="Sheet1")
        ws = xl.sheets["Sheet1"]
        ws["A1"] = title
    print(f"  wrote {fname:34s} {len(df):>6d} rows x {df.shape[1]} cols")

# ----------------------------------------------------------------------------- centers
N_CENTERS = 85
center_names = [f"{c} Cancer Center" for c in tokens("XXXXXXXX", N_CENTERS)]
# veeva mapping holds 84 names: 79 exact matches + 5 variant spellings (simulates ~94% fuzzy join)
veeva_exact = center_names[:79]
veeva_variants = [n.replace(" Cancer Center", ", LLC") for n in center_names[79:84]]
veeva_names = veeva_exact + veeva_variants
# slot site names: 77 of the centers
slot_sites = center_names[:77]

# ============================================================================= 1. orders (master)
N_ORD = 2250
til = tokens("XXX-XXX####", N_ORD)                       # PK / hub join key
coi = tokens("########X", N_ORD)                         # secondary join key
# 2096 distinct patients across 2250 orders -> 154 orders reuse an existing patient
pat_unique = tokens("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX", 2096)  # SHA-256-like
pat = list(pat_unique) + list(rng.choice(pat_unique, size=N_ORD - 2096))
rng.shuffle(pat)

created = sample_dates(N_ORD, "2024-02-16", "2026-07-16", "2025-07-08")
orders = pd.DataFrame({
    "order_request__til_order_name": til,
    "order_request__created_date": pd.to_datetime(created).date,
    "iovance_patient_id": pat,
    "atc": cat(N_ORD, center_names),
})
# submission datetime ~ created + a little, 7.5% null
subm = pd.to_datetime(created) + pd.to_timedelta(rng.integers(0, 5, N_ORD), "D") \
       + pd.to_timedelta(rng.integers(0, 24*60, N_ORD), "m")
orders["til_order_submission_date"] = nullify(subm, 0.075)
orders["treating_physician"] = nullify(names(N_ORD, 199), 0.003)
orders["tumor_procurement_surgeon"] = nullify(names(N_ORD, 399), 0.063)
orders["patient_status"] = cat(N_ORD, ["Consented","Inactive","Registered"], [0.6,0.15,0.25])
orders["order_status"] = cat(N_ORD, ["Canceled","Completed","Draft","Lot Received","Lot Requested",
                                     "Manufacturing","TOR Confirmed","TOR Submitted"])
orders["fp_status"] = cat(N_ORD, ["Courier Delivered FP","Courier Picked-Up FP","MFG End","MFG Start",
    "Not Started","REP Initiation","REP Scale Out","RM Received","Released for Shipment by QA",
    "SM Pick-up Scheduled","Shipment Ready"])

# ---- funnel membership (subsets of orders, on the hub key) ----
idx = np.arange(N_ORD)
booked_idx = rng.choice(idx, size=1643, replace=False)                 # slot / ttp orders
tumor_idx  = rng.choice(booked_idx, size=869, replace=False)           # tumor orders (subset of booked)
booked_not_tumor = np.setdiff1d(booked_idx, tumor_idx)
inf_from_tumor = rng.choice(tumor_idx, size=537, replace=False)        # infusion ∩ tumor
inf_extra      = rng.choice(booked_not_tumor, size=1002-537, replace=False)
infusion_idx   = np.concatenate([inf_from_tumor, inf_extra])           # 1002 infusion orders

# per-order timeline anchors (enroll -> TTP ~43d -> infusion ~47d)
ttp_date = pd.to_datetime(created) + pd.to_timedelta(np.round(rng.normal(43, 12, N_ORD)).clip(5,180), "D")
inf_date = ttp_date + pd.to_timedelta(np.round(rng.normal(47, 14, N_ORD)).clip(7,220), "D")
deliv    = inf_date - pd.to_timedelta(rng.integers(1, 10, N_ORD), "D")
ship     = deliv - pd.to_timedelta(rng.integers(1, 4, N_ORD), "D")
sugg     = inf_date + pd.to_timedelta(rng.integers(-7, 7, N_ORD), "D")

def stage_col(series, member_idx, extra_null):
    """Value present only for orders that reached the stage, then add profile null rate."""
    s = pd.Series([pd.NaT]*N_ORD)
    vals = pd.Series(pd.to_datetime(series).values)
    s.iloc[member_idx] = vals.iloc[member_idx].values
    present = ~s.isna()
    drop = present & (rng.random(N_ORD) < extra_null)
    s[drop] = pd.NaT
    return pd.to_datetime(s).dt.date

# tumor pickup present for tumor orders (27% null overall -> ~73% present ~ tumor+some)
orders["tumor_tissue_pick_up_date"] = stage_col(ttp_date, np.union1d(tumor_idx, inf_extra), 0.0)
orders["resection_rescheduled_"] = cat(N_ORD, [False, True], [0.85, 0.15])
orders["final_product_shipping_date"]  = stage_col(ship,  infusion_idx, 0.02)
orders["final_product_delivery_date"]  = stage_col(deliv, infusion_idx, 0.02)
orders["suggested_infusion_date"]      = stage_col(sugg,  np.union1d(infusion_idx, booked_not_tumor), 0.0)
orders["infusion_release_status"] = nullify(cat(N_ORD, ["Do Not Infuse","Released for Infusion"], [0.15,0.85]), 0.407)
orders["manufacturing_plant"] = nullify(cat(N_ORD, ["Advanced Therapies","ICTC"]), 0.27)
orders["oos_status"] = nullify(cat(N_ORD, ["Confirmed OOS","In Spec","Potential OOS"], [0.1,0.8,0.1]), 0.824)
orders["til_order_cancellation_reason"] = nullify(cat(N_ORD, [
    "2nd Resection","Alternate Therapy","Brain Mets","Clinical Trial/IST/Collaboration",
    "Decline in Performance Status","Disease Progression","Duplicate Patient","Financial Clearance",
    "NED/MRD","Other","Patient Choice","Patient death","Patient health progressed","Physician decision",
    "Quality Status: Do Not Proceed","Transition to Hospice","Peer to Peer Consult"]), 0.582)
orders["til_order_cancellation_reason_other"] = nullify(free_text(N_ORD, 309, "cancel"), 0.849)
orders["pick_up_cancellation_reason"] = nullify(free_text(N_ORD, 19, "pickup"), 0.808)
orders["pick_up_cancellation_reason_other_desc"] = nullify(free_text(N_ORD, 230, "pickupdesc"), 0.896)
orders["fp_delivery_cancellation_reason"] = nullify(free_text(N_ORD, 24, "fpdeliv"), 0.631)
orders["fp_delivery_cancellation_reason_other_desc"] = nullify(free_text(N_ORD, 323, "fpdelivdesc"), 0.832)
orders["prior_authorization"] = cat(N_ORD, [False, True], [0.4, 0.6])
age_bands = ["18 UNDER","31 YOUNG","46 MIDDLE","61 SENIOR","76 ELDER"]
orders["person_account__age"] = cat(N_ORD, [f"{rng.integers(20,85)} {b.split()[1]}" for b in
                                            rng.choice(age_bands, N_ORD)])
orders["lot_number"] = nullify(tokens("XXX####", N_ORD, unique=False), 0.256)
orders["coi_number"] = coi
orders["referring_physician"] = nullify(names(N_ORD, 950), 0.348)
# patient_zip_code: dirty int with junk (min 0, huge max) as flagged
zips = rng.integers(1001, 99950, N_ORD).astype("int64")
junk = rng.random(N_ORD) < 0.02
zips[junk] = rng.integers(0, 9_072_523_324, junk.sum())
orders["patient_zip_code"] = zips

order_cols = ["order_request__til_order_name","order_request__created_date","iovance_patient_id",
    "til_order_submission_date","atc","treating_physician","tumor_procurement_surgeon","patient_status",
    "order_status","fp_status","tumor_tissue_pick_up_date","resection_rescheduled_",
    "final_product_shipping_date","final_product_delivery_date","suggested_infusion_date",
    "infusion_release_status","manufacturing_plant","oos_status","til_order_cancellation_reason",
    "til_order_cancellation_reason_other","pick_up_cancellation_reason","pick_up_cancellation_reason_other_desc",
    "fp_delivery_cancellation_reason","fp_delivery_cancellation_reason_other_desc","prior_authorization",
    "person_account__age","lot_number","coi_number","referring_physician","patient_zip_code"]
orders = orders[order_cols]

# maps from order index -> keys, for child files
til_by_idx = np.array(til)
coi_by_idx = np.array(coi)
center_by_idx = orders["atc"].to_numpy()

# ============================================================================= 2/3. slot & ttp
def make_slot_frame():
    N = 2583
    booked_til = til_by_idx[booked_idx]                 # 1643 real order links
    til_col = np.array([None]*N, dtype=object)
    booked_rows = rng.choice(np.arange(N), size=1643, replace=False)
    til_col[booked_rows] = booked_til
    # center follows the linked order where booked; profile null 36.4% (== unbooked rows)
    site = np.array([None]*N, dtype=object)
    order_pos = {t: i for i, t in enumerate(til_by_idx)}
    for r in booked_rows:
        site[r] = center_by_idx[order_pos[til_col[r]]]
    df = pd.DataFrame({
        "manufacturing_plant__account_name": cat(N, ["Advanced Therapies","ICTC"]),
        "slot_name": tokens("XX-####", N),
        "slot_date": pd.to_datetime(sample_dates(N, "2024-02-16","2026-09-16","2025-06-19")).date,
        "cm_slot_visible": cat(N, [False, True], [0.3, 0.7]),
        "slot_status": cat(N, ["Available","Claimed","Unavailable"], [0.4,0.4,0.2]),
        "booking_status": cat(N, ["Available","Reserved","Unavailable"], [0.4,0.4,0.2]),
        "til_order_name": til_col,
        "lost_capacity": cat(N, [False, True], [0.85, 0.15]),
        "slot_booked_by__full_name": [None]*N,
        "site__account_name": site,
        "unavailable_reason": nullify(cat(N, ["Clinical","Converted","Manufacturer","Reserved",
                                              "Slot Reallocated"]), 0.875),
    })
    bn = names(1643, 228)
    bb = np.array([None]*N, dtype=object); bb[booked_rows] = bn
    df["slot_booked_by__full_name"] = bb
    return df

# ============================================================================= 4. tumor documentation
def make_tumor_frame():
    # 869 tumor orders, 1126 rows (257 orders get a 2nd TPF)
    t_idx = tumor_idx
    base_til = til_by_idx[t_idx]; base_coi = coi_by_idx[t_idx]
    extra = rng.choice(np.arange(869), size=1126-869, replace=True)   # which orders repeat
    row_til = np.concatenate([base_til, base_til[extra]])
    row_coi = np.concatenate([base_coi, base_coi[extra]])
    order = rng.permutation(1126)
    row_til, row_coi = row_til[order], row_coi[order]
    N = 1126
    df = pd.DataFrame({
        "coi": row_coi,
        "til_order_name": row_til,
        "tumor_procurement_form_name": tokens("XXX-####", N),
        "name": tokens("XXX-#####", N),
        "tpf_status": cat(N, ["Canceled","Complete","Ready"], [0.15,0.7,0.15]),
        "location": free_text(N, 41, "loc"),
        "lesion_type": nullify(cat(N, ["Adrenal","Axillary","Central Nervous System","Cervical",
            "Cutaneous/Subcutaneous","Deep Pelvic","Inguinal","Lymph Node","Mucosal","Osseous","Other",
            "Peritoneum/Omentum","Skin/Cutaneous","Soft Tissue","Subcutaneous","Visceral",
            "Visceral - Adrenal","Visceral - Intestines (Small)","Visceral - Liver","Visceral - Lung",
            "Visceral Organ - Thyroid/Parathyroid"]), 0.001),
        "location_other": nullify(free_text(N, 71, "locoth"), 0.924),
        "orientation": nullify(cat(N, ["Center","Left Side","Other","Right Side"]), 0.119),
        "lesion_type_other": nullify(free_text(N, 79, "lesoth"), 0.892),
        "method_of_surgery": cat(N, ["Endoscopic","Laparoscopic","Open Surgery","Other","Robotic",
                                     "Thoracoscopic"]),
        "method_of_surgery_other": nullify(free_text(N, 14, "surgoth"), 0.976),
        "additional_notes": nullify(free_text(N, 223, "addl"), 0.788),
        "created_by_full_name": names(N, 269, kind=""),
        "tumor_tissue_pick_up_date": nullify(pd.to_datetime(sample_dates(
            N, "2025-05-27","2026-07-17","2026-01-16")).date, 0.001),
    })
    return df

# ============================================================================= 5. veeva call activity
def make_veeva_frame():
    N = 70533
    npi = rng.integers(1_000_000_000, 2_020_032_642, N).astype("int64")
    npi = pd.Series(npi, dtype="object")
    npi[rng.random(N) < 0.302] = None
    parents = [f"{p} Account" for p in tokens("XXXXXXXX", 4410)]
    df = pd.DataFrame({
        "date": pd.to_datetime(sample_dates(N, "2022-01-04","2026-11-10","2025-07-22")).date,
        "npi": npi,
        "name": names(N, 14537, kind="Dr"),
        "key_opinion_leader": nullify(cat(N, ["Cell Therapy","Cervical","Gyn/Onc","Head & Neck",
            "Melanoma","NSCLC","Other","Surgical Oncology"]), 0.872),
        "interaction_type": nullify(cat(N, ["Email","In-Person Meeting","Phone","Remote Meeting"]), 0.303),
        "interaction_name": tokens("X########", N),
        "primary_parent_name": nullify(rng.choice(parents, N), 0.054),
        "territory": free_text(N, 139, "terr"),
        "community_top_50": cat(N, [False, True], [0.6, 0.4]),
        "community_top_25": cat(N, [False, True], [0.75, 0.25]),
        "atc_target": cat(N, [False, True], [0.5, 0.5]),
        "community_target": cat(N, [False, True], [0.6, 0.4]),
        "pulse_alert": cat(N, [False, True], [0.9, 0.1]),
        "status": cat(N, ["Planned","Saved","Submitted"], [0.2,0.2,0.6]),
        "location": nullify(cat(N, ["ATC - main site","ATC - satellite","Community","LCP site"]), 0.849),
    })
    return df

# ============================================================================= 6. infusion
def make_infusion_frame():
    N = 1002
    inf_til = til_by_idx[infusion_idx]
    # infusion_date follows the SAME per-order timeline used for the orders file
    # (ttp + ~47d), so TTP->infusion and delivery->infusion metrics are realistic.
    row_inf_date = pd.Series(pd.to_datetime(inf_date).values).iloc[infusion_idx].reset_index(drop=True)
    df = pd.DataFrame({
        "til_order_name": inf_til,
        "coc_closure": tokens("XXX XXXXXXX - ####", N),
        "did_patient_receive_plan_il_2_regimen_": nullify(cat(N, ["No","Yes"], [0.2,0.8]), 0.538),
        "how_many_hd_il_2_doses_were_omitted_": nullify(rng.integers(1, 7, N).astype("int64"), 0.713),
        "did_patient_receive_plan_nma_ld_regimen_": nullify(cat(N, ["No","Yes"], [0.2,0.8]), 0.525),
        "nma_lymphodepletion__nma_ld___start_date": nullify(pd.to_datetime(sample_dates(
            N, "2024-03-30","2026-07-06","2025-06-23")).date, 0.523),
        "nma_lymphodepletion__nma_ld___end_date": nullify(pd.to_datetime(sample_dates(
            N, "2024-04-03","2026-07-12","2025-07-04")).date, 0.529),
        "cyclophosphamide_doses": nullify(rng.integers(0, 3, N).astype("int64"), 0.921),
        "fludarabine_doses": nullify(rng.integers(0, 6, N).astype("int64"), 0.923),
        "lifileucel_infused_": nullify(cat(N, ["No","Yes"], [0.1,0.9]), 0.063),
        "infusion_date": nullify(row_inf_date.dt.date, 0.10),
        "reason_not_infused": nullify(cat(N, ["Other","Patient death","Patient health progressed",
            "Quality Status: Do Not Proceed","Transition to Hospice"]), 0.979),
        "last_modified_by__full_name": names(N, 133, kind=""),
    })
    return df

# ============================================================================= 7. veeva komodo atc mapping
def make_mapping_frame():
    N = 84
    df = pd.DataFrame({
        "veeva_name": veeva_names,
        "city": free_text(N, 65, "City").astype(object),
        "state": cat(N, [f"S{i:02d}" for i in range(35)]),
        "zip": rng.integers(2114, 98110, N).astype("int64"),
        "county": nullify(free_text(N, 58, "County"), 0.012),
        "territory": cat(N, ["AR/MO/Tulsa","CT/NYC","Carolinas","Desert Plains","Great South",
            "IN/KY/Cincy","Illinois","Los Angeles","MN/WI","Mid-Atlantic","Midwest","New England",
            "North FL/GA","North TX/OK","Northern Cal","Northern NJ & NYC","OH/MI","Pacific Northwest",
            "Philly","Pittsburgh/Cleveland","Rocky Mountains","San Diego/OC","South FL","South TX/LA"]),
        "region": cat(N, ["Central","Great Lakes","Northeast","South","West"]),
        "pps_status": nullify(np.array(["Exempt"]*N, dtype=object), 0.881),
        "ic_ttp_baseline": np.round(rng.triangular(0.0, 0.5, 3.6, N), 1),
        "atc_segment": cat(N, ["High Potential","Other","Top Account"]),
        "start_segment": nullify(cat(N, ["Declined","Exempt","High OOS","New Low Volume"]), 0.25),
    })
    return df

# ----------------------------------------------------------------------------- write all
print("Generating synthetic Infinity files -> out/")
write_xlsx(make_mapping_frame(), "veeva_komodo_atc_mapping.xlsx", "Veeva Komodo ATC Mapping")
write_xlsx(make_slot_frame(),    "bai_ttp_data.xlsx",             "BAI TTP Data")
write_xlsx(make_slot_frame(),    "bai_slot_data.xlsx",            "BAI Slot Data")
write_xlsx(make_tumor_frame(),   "bai_tumor_documentation.xlsx",  "BAI Tumor Documentation")
write_xlsx(make_veeva_frame(),   "veeva_call_activity.xlsx",      "Veeva Call Activity")
write_xlsx(orders,               "bai_list_of_orders.xlsx",       "BAI - List of Orders")
write_xlsx(make_infusion_frame(),"bai_infusion.xlsx",             "BAI Infusion")
print("Done.")

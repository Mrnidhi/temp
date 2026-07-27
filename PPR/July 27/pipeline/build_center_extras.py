"""
PPR pipeline - Stage 2b: per-center analytics beyond the mandated scorecard.

Computes the views a real center review needs but the raw template lacks:
funnel conversion, yield rates, peer-tier benchmark deltas, timeline variance,
quarterly trend, and national manufacturing-slot capacity context.

Out: dashboard/extras_payload.json
"""
import os, json
import numpy as np
import pandas as pd

HERE = os.path.dirname(__file__)
A = pd.read_csv(os.path.join(HERE, "..", "analysis", "ppr_analysis.csv"))
SLOT = pd.read_excel(os.path.join(HERE, "..", "synthetic_data", "out", "bai_slot_data.xlsx"), header=2)
OUT = os.path.join(HERE, "..", "dashboard", "extras_payload.json")
QTRS = ["2025Q4", "2026Q1", "2026Q2", "2026Q3"]
QLAB = ["Q4'25", "Q1'26", "Q2'26", "Q3'26"]

A["enrollment_date"] = pd.to_datetime(A["enrollment_date"])
A["infusion_date"] = pd.to_datetime(A["infusion_date"], errors="coerce")
A["days_enroll_to_infusion"] = (A["infusion_date"] - A["enrollment_date"]).dt.days
A.loc[A["days_enroll_to_infusion"] < 0, "days_enroll_to_infusion"] = None
A["enroll_q"] = A["enrollment_date"].dt.to_period("Q").astype(str)

def agg(df):
    enrolled = df["order_request__til_order_name"].nunique()
    slot = int(df["has_slot"].sum())
    tumor = int(df["has_tumor"].sum())
    ttp_done = int(df["completed_ttp"].sum())
    mfg = int(df["mfg_started"].sum())
    infused = int(df["amtagvi_infused"].sum())
    oos = int(df["oos_product"].sum())
    drop = int(df["dropout_post_ttp_health"].sum())
    def rate(a, b): return round(100 * a / b, 1) if b else None
    return {
        "enrolled": enrolled, "slot": slot, "tumor": tumor, "ttp_done": ttp_done,
        "mfg": mfg, "infused": infused, "oos": oos, "drop": drop,
        # clean, monotonic process funnel: enrolled >= slot booked >= TTP completed >= infused
        "funnel": [["Enrolled", enrolled], ["Slot Booked", slot],
                   ["TTP Completed", ttp_done], ["AMTAGVI Infused", infused]],
        # yield / health rates (all on complete order-level fields, not the noisy status col)
        "slot_rate": rate(slot, enrolled),
        "ttp_completion": rate(ttp_done, enrolled),
        "infusion_yield": rate(infused, enrolled),
        "dropout_rate": rate(drop, ttp_done),
        "oos_rate": rate(oos, infused),
        # timelines
        "d_enroll_ttp": round(df["days_enroll_to_ttp"].mean(), 1) if df["days_enroll_to_ttp"].notna().any() else None,
        "d_ttp_inf": round(df["days_ttp_to_infusion"].mean(), 1) if df["days_ttp_to_infusion"].notna().any() else None,
        "d_deliv_inf": round(df["days_delivery_to_infusion"].mean(), 1) if df["days_delivery_to_infusion"].notna().any() else None,
        "d_enroll_inf": round(df["days_enroll_to_infusion"].mean(), 1) if df["days_enroll_to_infusion"].notna().any() else None,
    }

def quarterly(df):
    enr = [int((df.enroll_q == q).sum()) for q in QTRS]
    inf = [int(((df.enroll_q == q) & df.amtagvi_infused).sum()) for q in QTRS]
    return {"labels": QLAB, "enrolled": enr, "infused": inf}

# per center
centers = {}
for ck, g in A.groupby("center_key"):
    disp = g["atc"].iloc[0]
    reg = g["region"].dropna().iloc[0] if g["region"].notna().any() else "Unmapped"
    terr = g["territory"].dropna().iloc[0] if g["territory"].notna().any() else "Unmapped"
    centers[disp] = {**agg(g), "tier": g["atc_tier"].iloc[0], "region": reg,
                     "territory": terr, "matched": bool(g["center_matched"].iloc[0]),
                     "trend": quarterly(g)}

# per tier (peer benchmark)
tiers = {t: agg(A[A.atc_tier == t]) for t in ["Top 10", "Top 40", "New", "Other"]}
national = agg(A)

# national manufacturing-slot capacity (the EMQ / utilization thread)
tot = len(SLOT)
booked = int(SLOT["til_order_name"].notna().sum())
lost = int((SLOT["lost_capacity"] == True).sum())
claimed = int((SLOT["slot_status"] == "Claimed").sum())
unavail_reasons = (SLOT["unavailable_reason"].dropna().value_counts().to_dict())
capacity = {
    "total_slots": tot, "booked": booked, "utilization": round(100 * booked / tot, 1),
    "lost_capacity": round(100 * lost / tot, 1), "claimed": claimed,
    "unavailable_reasons": {k: int(v) for k, v in unavail_reasons.items()},
    "util_target": 75.0,
}

# ---------------------------------------------------------------- portfolio (leadership view)
def trend_dir(tr):
    # compare the two most recent COMPLETE quarters (Q1'26 vs Q2'26); the last
    # column is Q3'26 QTD (partial) and would bias every center downward.
    e = tr["enrolled"]
    prev, last = e[1], e[2]
    if last > prev: return "up"
    if last < prev: return "down"
    return "flat"

leaderboard = []
for name, c in centers.items():
    peer = tiers.get(c["tier"], national)
    pd_delta = None
    if c["infusion_yield"] is not None and peer["infusion_yield"] is not None:
        pd_delta = round(c["infusion_yield"] - peer["infusion_yield"], 1)
    leaderboard.append({
        "center": name, "tier": c["tier"], "region": c["region"],
        "enrolled": c["enrolled"], "infused": c["infused"],
        "yield": c["infusion_yield"], "peer_yield": peer["infusion_yield"],
        "yield_delta": pd_delta, "d_enroll_inf": c["d_enroll_inf"],
        "trend": trend_dir(c["trend"]),
    })
leaderboard.sort(key=lambda r: r["enrolled"], reverse=True)

# focus watchlist: enough volume to judge, and materially below peer yield
watchlist = sorted(
    [r for r in leaderboard if r["yield_delta"] is not None and r["enrolled"] >= 10 and r["yield_delta"] <= -4],
    key=lambda r: r["yield_delta"])[:12]

tier_mix = []
for t in ["Top 10", "Top 40", "New", "Other"]:
    n = sum(1 for r in leaderboard if r["tier"] == t)
    tier_mix.append({"tier": t, "n_centers": n, "enrolled": tiers[t]["enrolled"],
                     "infused": tiers[t]["infused"], "yield": tiers[t]["infusion_yield"]})

regions = {}
for r in leaderboard:
    d = regions.setdefault(r["region"], {"centers": 0, "enrolled": 0, "infused": 0})
    d["centers"] += 1; d["enrolled"] += r["enrolled"]; d["infused"] += r["infused"]
region_rows = sorted(
    [{"region": k, **v, "yield": round(100*v["infused"]/v["enrolled"], 1) if v["enrolled"] else None}
     for k, v in regions.items()], key=lambda r: r["enrolled"], reverse=True)

active_centers = sum(1 for r in leaderboard if r["enrolled"] > 0)
portfolio = {
    "active_centers": active_centers, "total_centers": len(centers),
    "enrolled": national["enrolled"], "infused": national["infused"],
    "infusion_yield": national["infusion_yield"], "d_enroll_inf": national["d_enroll_inf"],
    "funnel": national["funnel"], "leaderboard": leaderboard, "watchlist": watchlist,
    "tier_mix": tier_mix, "regions": region_rows,
}

payload = {"centers": centers, "tiers": tiers, "national": national,
           "capacity": capacity, "portfolio": portfolio, "asof": "2026-07-21",
           "tier_order": ["Top 10", "Top 40", "New", "Other"]}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump(payload, open(OUT, "w"))
print("centers", len(centers), "| capacity util%", capacity["utilization"],
      "lost%", capacity["lost_capacity"])
# sanity: busiest center
bc = max(centers, key=lambda c: centers[c]["enrolled"])
c = centers[bc]
print(f"{bc}: tier {c['tier']} yield {c['infusion_yield']}% vs Top40 {tiers['Top 40']['infusion_yield']}%")
print("funnel:", c["enrolled"], c["slot"], c["tumor"], c["mfg"], c["infused"])

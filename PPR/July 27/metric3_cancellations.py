"""
Metric 3, computed properly: TTPs Cancelled or Rescheduled within 7 Days.

WHY
The pipeline currently stands in resection_rescheduled_, which on real data is True on
347 of 1,295 orders (26.8%) while Kolin's UK Chandler deck reports 0. A flag firing on a
quarter of all orders is not approximating something that reads zero.

THE RULE (Kolin, Meet 6)
"They had a TTP date of August 14th 2024, and they cancelled it on August 9th. So it's
checking the days between the snapshot, August 9th, and when it was cancelled, August 14th,
and it's 5. So this would flag as a last-minute cancellation."
Also: "I think it might use 3 today, but I think we want to use 7 moving forward."

So: walk each order's snapshots in record_number order. Whenever the planned pickup date
moves or is cleared, measure from that snapshot's load date back to the date that HAD been
booked. A gap of 0-7 days means the slot could not realistically be refilled, so it counts.

INPUT
Export from Infinity and save into ../data/ (csv or xlsx, any filename containing "hist"):
    SELECT order_request__til_order_name, record_number, load_datetime,
           tumor_tissue_pick_up_date, atc
    FROM bai_list_of_orders_hist

USAGE
    python metric3_cancellations.py
Real data never leaves the office laptop. Only the printed summary needs to travel.
"""
import glob
import os
import sys

import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
THRESHOLD_DAYS = 7          # Kolin: "we want to use 7 moving forward"

# The pipeline computes the same rule from pipeline/cancellations.py. Import it so this
# script can prove the two agree on every run (one rule, two callers). Wrapped so a path
# hiccup never breaks this diagnostic.
try:
    sys.path.insert(0, os.path.join(HERE, "pipeline"))
    from cancellations import cancellation_events as _shared_events
except Exception:
    _shared_events = None

# Column aliases. Infinity, the xlsx export and the current table all name these
# differently, so accept any of them rather than break on a rename.
ALIASES = {
    "order": ["order_request__til_order_name", "til_order_name", "til_order_number"],
    "record": ["record_number"],
    "load": ["load_datetime"],
    "ttp": ["tumor_tissue_pick_up_date", "tumor_pickup_date"],
    "atc": ["atc"],
    "fp": ["fp_status"],
    "reason": ["til_order_cancellation_reason"],
}


def optional(df, key):
    """Same as pick(), but returns None instead of exiting when the column is absent."""
    cols = {str(c).lower().strip(): c for c in df.columns}
    for a in ALIASES[key]:
        if a in cols:
            return cols[a]
    return None


def find_file():
    pats = ["*hist*.csv", "*hist*.xlsx", "*orders_hist*"]
    hits = [f for p in pats for f in glob.glob(os.path.join(DATA, p))]
    if not hits:
        sys.exit(f"No history export found in {DATA}\n"
                 "Save the Infinity download there (filename must contain 'hist').")
    return sorted(hits, key=os.path.getmtime)[-1]


def load(path):
    """Read csv or xlsx. The xlsx exports carry a two-row title banner."""
    if path.lower().endswith(".csv"):
        return pd.read_csv(path, low_memory=False)
    for header in (0, 2):                      # try flat, then banner layout
        df = pd.read_excel(path, header=header)
        if any(c.lower().strip() in ALIASES["record"] for c in map(str, df.columns)):
            return df
    return pd.read_excel(path, header=2)


def pick(df, key):
    cols = {str(c).lower().strip(): c for c in df.columns}
    for a in ALIASES[key]:
        if a in cols:
            return cols[a]
    sys.exit(f"Could not find a column for '{key}'. Looked for {ALIASES[key]}.\n"
             f"Columns present: {list(df.columns)}")


def parse_load(s):
    """load_datetime is a string like 20241007T024217. Take the date part."""
    t = s.astype(str).str.strip().str.replace("-", "", regex=False)
    return pd.to_datetime(t.str[:8], format="%Y%m%d", errors="coerce")


def main():
    path = find_file()
    df = load(path)
    print(f"file    : {os.path.basename(path)}")
    print(f"rows    : {len(df):,}")

    c_ord, c_rec = pick(df, "order"), pick(df, "record")
    c_load, c_ttp = pick(df, "load"), pick(df, "ttp")
    c_atc = pick(df, "atc")

    d = pd.DataFrame({
        "ord": df[c_ord].astype(str).str.strip(),
        "rec": pd.to_numeric(df[c_rec], errors="coerce"),
        "snap": parse_load(df[c_load]),
        "ttp": pd.to_datetime(df[c_ttp], errors="coerce"),
        "atc": df[c_atc].astype(str).str.strip(),
    })

    bad_snap, bad_rec = d.snap.isna().sum(), d.rec.isna().sum()
    print(f"orders  : {d.ord.nunique():,}   snapshots/order median: {d.groupby('ord').size().median():.0f}")
    print(f"parsed  : load_datetime null {bad_snap}, record_number null {bad_rec}, "
          f"pickup date present {d.ttp.notna().sum():,}")
    if bad_snap > len(d) * 0.5:
        sys.exit("load_datetime did not parse. Print a few raw values and adjust parse_load().")

    # walk each order's snapshots in sequence and look at what the pickup date was before
    d = d.sort_values(["ord", "rec"])
    d["prev_ttp"] = d.groupby("ord")["ttp"].shift(1)

    moved = d[d.prev_ttp.notna() & (d.ttp.isna() | (d.ttp != d.prev_ttp))].copy()
    moved["days_notice"] = (moved.prev_ttp - moved.snap).dt.days
    moved["kind"] = np.where(moved.ttp.isna(), "cancelled", "rescheduled")

    # Only changes made BEFORE the booked date count. A change recorded after the date had
    # already passed is administrative cleanup, not a lost slot.
    fwd = moved[moved.days_notice >= 0]
    late = fwd[fwd.days_notice <= THRESHOLD_DAYS]

    # Prove this script and the pipeline's shared rule return the same count on this file.
    if _shared_events is not None:
        _n = len(_shared_events(df))
        print(f"\n[shared-rule check] pipeline/cancellations.py returns {_n} events; "
              f"this script returns {len(late)} -> "
              + ("match" if _n == len(late) else "MISMATCH, investigate before trusting either"))

    print("\n" + "=" * 64)
    print("CHANGES TO A BOOKED PICKUP DATE")
    print(f"  any change            {len(moved):,}")
    print(f"  made before the date  {len(fwd):,}")
    print(f"  within 3 days         {(fwd.days_notice <= 3).sum():,}")
    print(f"  within 7 days         {len(late):,}   <- METRIC 3")
    print(f"  of which cancelled    {(late.kind == 'cancelled').sum():,}")
    print(f"  of which rescheduled  {(late.kind == 'rescheduled').sum():,}")
    print(f"  distinct orders hit   {late.ord.nunique():,}")

    print("\nSANITY CHECK")
    print("  The old proxy (resection_rescheduled_) flags 347 orders / 26.8%.")
    print(f"  This returns {late.ord.nunique():,} orders. If it is anywhere near 347,")
    print("  the logic is wrong, not the data. Send the numbers back before trusting them.")

    per = (late.groupby("atc").size().sort_values(ascending=False)
           .rename("ttps_cancelled_or_resched_le7"))
    print("\nPER CENTRE (non-zero only)")
    print(per.to_string() if len(per) else "  none")

    out = os.path.join(HERE, "metric3_by_center.csv")
    per.to_csv(out)
    print(f"\nwrote {out}")

    print("\nAUDIT TRAIL, first 15 - use these to defend any number")
    cols = ["atc", "ord", "prev_ttp", "ttp", "snap", "days_notice", "kind"]
    print(late[cols].head(15).to_string(index=False))

    # ---- two questions the history table answers on its own ----
    # Both were nearly sent to the source-system owner. Neither needed to be.
    c_fp, c_rsn = optional(df, "fp"), optional(df, "reason")

    if c_fp is not None and c_rsn is not None:
        h = pd.DataFrame({
            "ord": df[c_ord].astype(str).str.strip(),
            "rec": pd.to_numeric(df[c_rec], errors="coerce"),
            "fp": df[c_fp].astype(str).str.strip().replace({"nan": "", "None": ""}),
            "rsn": df[c_rsn].astype(str).str.strip().replace({"nan": "", "None": ""}),
        }).sort_values(["ord", "rec"])

        print("\n" + "=" * 64)
        print("Q: is fp_status overwritten when an order is cancelled?")
        print("   (decides whether the progression-rate denominator decays over time)")
        cancelled = h[h.rsn != ""].ord.unique()
        last = h[h.ord.isin(cancelled)].groupby("ord").tail(1)
        MFG = {"MFG Start", "MFG End", "REP Initiation", "REP Scale Out",
               "Released for Shipment by QA", "SM Pick-up Scheduled", "Shipment Ready",
               "Courier Picked-Up FP", "Courier Delivered FP"}
        ever_mfg = h[h.fp.isin(MFG)].ord.unique()
        both = set(cancelled) & set(ever_mfg)
        kept = last[last.ord.isin(both) & last.fp.isin(MFG)].ord.nunique()
        print(f"   cancelled orders                     {len(cancelled):,}")
        print(f"   of those, ever held a mfg status     {len(both):,}")
        print(f"   still holding a mfg status at latest {kept:,}")
        if len(both):
            pct = kept / len(both) * 100
            print(f"   -> {pct:.0f}% retain it. "
                  + ("Denominator is SAFE, status is not overwritten."
                     if pct > 90 else
                     "Denominator DECAYS - metric 9 undercounts and must be rebuilt from history."))

        print("\nQ: when was each order cancelled?")
        print("   (the load date of the first snapshot carrying a reason)")
        firstc = (h[h.rsn != ""].groupby("ord").rec.min().rename("first_rec").reset_index())
        snapmap = d[["ord", "rec", "snap"]].rename(columns={"rec": "first_rec"})
        cdates = firstc.merge(snapmap, on=["ord", "first_rec"], how="left")
        got = cdates.snap.notna().sum()
        print(f"   recovered a cancellation date for {got:,} of {len(cdates):,} cancelled orders")
        if got:
            print(f"   range {cdates.snap.min().date()} to {cdates.snap.max().date()}")
            out = os.path.join(HERE, "cancellation_dates.csv")
            cdates[["ord", "snap"]].rename(columns={"snap": "cancelled_on"}).to_csv(out, index=False)
            print(f"   wrote {out}  <- the missing event date, recovered not requested")
    else:
        print("\n(fp_status / cancellation reason not in this export - "
              "re-export with those two columns to answer the other two questions)")


if __name__ == "__main__":
    main()

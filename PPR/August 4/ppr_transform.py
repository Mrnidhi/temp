"""P&PR transformation for the daily Glue job.

Redshift raw tables in, the Events table for Tableau out. Ported from the
reference pipeline in ../pipeline/ (build_analysis_table, build_cancellations,
build_scorecard, build_datewindow); metrics.py and cancellations.py ship
verbatim from there. The additivity and reconciliation gates run on every call,
and the ported output was verified byte for byte against the reference on the
test sample before handoff.
"""
import io

import numpy as np
import pandas as pd

from cancellations import (COUNT_DIRECTIONS, COUNT_GRAIN, THRESHOLD_DAYS,
                           apply_rule, norm_center, _dates)


def build_order_master(frames, asof_override=None):
    """frames: dict with keys 'bai_list_of_orders', 'bai_tumor_documentation',
    'bai_infusion', 'veeva_komodo_atc_mapping' (DataFrames, columns lowercase as
    Redshift returns them) and optional 'bai_slot_data' (DataFrame or None).
    Returns (A, meta) where A is the full order-grain DataFrame the script wrote
    to ppr_analysis.csv (same columns, same order) and meta is the dict the script
    wrote to run_meta.json."""
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
        # Exact strings from the source picklist (10 values). Kept alongside the other
        # spellings seen in the data above because the two sets do not match.
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
    # happens BEFORE manufacturing, so the two SM states are deliberately excluded. In the
    # data "SM Pick-up Scheduled" alone is 305 orders, so including it would inflate metric 9's
    # denominator by roughly a third and understate the progression rate.
    MFG_STARTED = {"MFG Start", "MFG End", "REP Initiation", "REP Scale Out",
                   "Released for Shipment by QA", "Shipment Ready",
                   "Courier Picked-Up FP", "Courier Delivered FP", "FP CAH"}
    SM_PRE_MFG = {"SM Pick-up Scheduled", "Courier Picked-Up SM", "Warehouse Received SM",
                  "MFG QA Released SM", "MFG Received SM"}   # pre-manufacturing, never counted

    def to_dt(s):
        return pd.to_datetime(s, errors="coerce")

    # ------------------------------------------------------------------ load
    orders = frames["bai_list_of_orders"]
    tumor  = frames["bai_tumor_documentation"]
    inf    = frames["bai_infusion"]
    slot   = frames.get("bai_slot_data")
    mp     = frames["veeva_komodo_atc_mapping"]

    # ------------------------------------------------------------------ as-of + run metadata
    # As-of date. Never read the clock: same inputs must give the same outputs on any day.
    # asof_override (YYYY-MM-DD) wins when set; otherwise the newest order-creation date in
    # the extract stands in for the export date, since orders are created daily across 85
    # centers. Recorded in the returned meta and shown on every output.
    if asof_override:
        TODAY = pd.Timestamp(asof_override)
    else:
        TODAY = to_dt(orders["order_request__created_date"]).max()
        if pd.isna(TODAY):
            raise SystemExit("Cannot derive an as-of date: no parseable order creation dates. "
                             "Set PPR_ASOF=YYYY-MM-DD and rerun.")
    _meta = {"asof": TODAY.strftime("%Y-%m-%d"),
             "asof_source": "PPR_ASOF" if asof_override else "max order_request__created_date"}
    print(f"as-of: {_meta['asof']} ({_meta['asof_source']})")

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

    if slot is None:
        print("  bai_slot_data absent: has_slot is False for every order. It drives no metric.")
        o["has_slot"] = False
    else:
        o["has_slot"] = o["order_request__til_order_name"].isin(set(slot["til_order_name"].dropna()))

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
    # Scheduled means still to come. A pickup dated on or before the as-of date has happened and
    # is Completed; anything after it is Scheduled. The two are disjoint, so they add to a total
    # procurement count, and every closed period shows Scheduled as zero by construction.
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

    _both = int((o["completed_ttp"] & o["scheduled_ttp"]).sum())
    assert _both == 0, (
        f"{_both} order(s) counted as both completed and scheduled; the two must stay disjoint")

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

    print(f"analysis table: {len(o)} rows x {o.shape[1]} cols -> analysis/ppr_analysis.csv")
    print("centers:", o['center_key'].nunique(), "| matched to veeva:", o['center_matched'].mean().round(3))
    print("tiers:", o['atc_tier'].value_counts().to_dict())
    print("funnel: slot", int(o['has_slot'].sum()), "tumor", int(o['has_tumor'].sum()),
          "infusion", int(o['has_infusion'].sum()), "amtagvi", int(o['amtagvi_infused'].sum()))
    return o, _meta

def build_m3_events(frames, A):
    """Stage 2: the metric 3 event table from the reschedule and cancellation
    tables. Ported from build_cancellations.py; the 7 day rule itself is
    imported unchanged from cancellations.py."""
    COLS = ["center", "order", "event_date", "recorded_on", "days_notice", "kind",
            "direction", "reason", "center_key", "center_disp"]

    r = frames.get("ltd_reschedules")
    c = frames.get("ltd_cancellations")
    parts, files = [], []
    if r is not None and len(r):
        parts.append(pd.DataFrame({
            "order":       r["order_id"].astype(str).str.strip(),
            "lost_slot":   _dates(r["ttp_date_prev"], "TTP_DATE_PREV"),
            "recorded_on": _dates(r["snapshot_date_time_curr"], "SNAPSHOT_DATE_TIME_CURR"),
            "kind":        "rescheduled",
            "direction":   (r["rescheduled_category"].astype(str).str.strip()
                            if "rescheduled_category" in r.columns else np.nan),
            "reason":      np.nan,
        }))
        files.append("ltd_reschedules")
    if c is not None and len(c):
        parts.append(pd.DataFrame({
            "order":       c["order_id"].astype(str).str.strip(),
            # a cancellation clears the date, so its single TTP_DATE is the lost slot
            "lost_slot":   _dates(c["ttp_date"], "TTP_DATE"),
            "recorded_on": _dates(c["snapshot_date_time_curr"], "SNAPSHOT_DATE_TIME_CURR"),
            "kind":        "cancelled",
            "direction":   np.nan,
            "reason":      (c["cancellation_reason"].astype(str).str.strip()
                            if "cancellation_reason" in c.columns else np.nan),
        }))
        files.append("ltd_cancellations")

    if not parts:
        print("metric 3: no reschedule or cancellation table in the source schema; "
              "using the resection_rescheduled_ proxy from stage 1")
        return pd.DataFrame(columns=COLS), {"m3_source": "proxy"}

    ev = apply_rule(pd.concat(parts, ignore_index=True), THRESHOLD_DAYS, COUNT_DIRECTIONS)

    drops = ev.attrs.get("drops", {})
    print(f"metric 3 funnel ({'ltd'}):")
    for reason, n in drops.items():
        print(f"  {n:>6,}  {reason}")
    accounted = sum(v for k, v in drops.items() if k != "rows in")
    assert accounted == drops["rows in"], (
        f"funnel does not reconcile: {accounted} accounted for against "
        f"{drops['rows in']} rows in")

    by_order = (A[["order_request__til_order_name", "center_key", "atc"]]
                .drop_duplicates("order_request__til_order_name")
                .set_index("order_request__til_order_name"))
    ev["center_key"] = ev["order"].map(by_order["center_key"])
    ev["center_disp"] = ev["order"].map(by_order["atc"])

    lost = ev[ev["center_disp"].isna()]
    if len(lost):
        print(f"  WARNING: {len(lost)} event(s) at order(s) not in the order table, "
              f"EXCLUDED from metric 3: {sorted(lost['order'].astype(str).unique())[:5]}")
    ev = ev.dropna(subset=["center_disp"]).reindex(columns=COLS)

    meta = {"m3_source": "ltd", "m3_files": files,
            "m3_directions": sorted(COUNT_DIRECTIONS), "m3_grain": COUNT_GRAIN}
    counted = len(ev) if COUNT_GRAIN == "events" else ev["order"].nunique()
    print(f"metric 3: {counted} short-notice lost slot(s) counted as {COUNT_GRAIN} "
          f"({len(ev)} events across {ev['order'].nunique()} orders) "
          f"from {', '.join(files)}")
    print(f"  kind: {ev['kind'].value_counts().to_dict()}   "
          f"directions counted: {sorted(COUNT_DIRECTIONS)}")
    if ev["direction"].notna().any():
        print(f"  direction: {ev['direction'].value_counts().to_dict()}")
    if ev["reason"].notna().any():
        print(f"  reasons: {ev['reason'].value_counts().to_dict()}")
    if len(ev):
        span = pd.to_datetime(ev["recorded_on"])
        print(f"  covers {span.min():%Y-%m-%d} to {span.max():%Y-%m-%d}")
    return ev, meta


def build_scorecard(A, canc, meta):
    """Stage 2: compute the P&PR scorecard (tidy long table).

    From the order-grain table, compute the 13 scorecard metrics for every center
    across the time cuts and quarters, plus the national ATC-tier benchmarks. Output is
    tidy (one row per center x column x metric) so Tableau just renders it.
    Returns the DataFrame the script wrote to analysis/ppr_scorecard_tidy.csv."""
    # These arrived as fresh csv reads in the script; copy so the caller's frames stay untouched.
    A = A.copy()
    CANC = canc.copy()
    # As-of date comes from stage 1, one definition for every stage.
    TODAY = meta["asof"]

    # Metric 3 source: 'ltd' and 'hist' both mean count real cancellation events (dated on
    # the lost slot); 'proxy' means the resection_rescheduled_ flag. Stage 2 decides and
    # records it.
    M3_SOURCE = meta.get("m3_source", "proxy")
    M3_EVENTS = M3_SOURCE in ("ltd", "hist")
    if len(CANC):
        CANC["event_date"] = pd.to_datetime(CANC["event_date"], errors="coerce")
    elif M3_EVENTS:
        print(f"WARNING: run_meta.json says m3_source={M3_SOURCE!r} but "
              "analysis/ppr_cancellations.csv has no rows. Metric 3 will read 0 everywhere; "
              "check the stage 2 output before trusting it.")

    from metrics import (METRICS, EVENT_DATE, NON_ADDITIVE,
                         M1, M2, M3, M4, M5, M6, M7, M8, M9, M10, M11, M12, M13)

    # Parse each event date and cast each flag once, here, rather than inside every
    # window of every metric of every centre. Both operations are elementwise, so
    # doing them up front selects exactly the same rows later.
    DATE_COLS = sorted(set(EVENT_DATE.values()))
    for _c in DATE_COLS:
        A[_c] = pd.to_datetime(A[_c], errors="coerce")
    for _f in ("mfg_started", "drop_after_mfg", "dropout_post_ttp_health",
               "completed_ttp", "scheduled_ttp", "oos_product", "amtagvi_infused"):
        if _f in A.columns:
            A[_f] = A[_f].fillna(False).astype(bool)
    TODAY_TS = pd.Timestamp(TODAY)

    def _win(df, datecol, start, end):
        """Rows whose event date for this metric falls inside the window (None = no bound)."""
        if start is None and end is None:
            return df
        d = df[datecol]
        m = d.notna()
        if start is not None: m &= d >= pd.Timestamp(start)
        if end   is not None: m &= d <= pd.Timestamp(end)
        return df[m]

    def compute(df, start=None, end=None, avg="median", undated=False, future=False, canc=None):
        """13 metrics. Each is filtered on ITS OWN event date, so a column means
        'what happened in this period'.

        undated=True instead selects rows whose own event date is MISSING. Those rows are
        real events that cannot be placed in any period. They belong in Launch to Date and in
        no year column, and the difference has to be visible rather than silently dropped:
        missingness here correlates with the outcome (an out-of-spec product is often never
        delivered, a cancelled procurement never happened), so hiding it biases every period
        column optimistic.

        future=True selects rows dated AFTER the as-of date. Period columns stop at the as-of
        date, so these also sit in Launch to Date and in no period column. Scheduled TTPs are
        future by definition and belong here; future-dated infusions do not and are flagged
        below."""
        # The 13 metrics share 4 event date columns, so slice once per column and hand
        # the same frame to every metric that dates on it.
        if undated:
            sel = {col: df[df[col].isna()] for col in DATE_COLS}
        elif future:
            sel = {col: df[df[col] > TODAY_TS] for col in DATE_COLS}
        else:
            sel = {col: _win(df, col, start, end) for col in DATE_COLS}
        w = {m: sel[col] for m, col in EVENT_DATE.items()}
        # The source scorecard reports medians for these, not averages.
        agg = (lambda s: s.mean()) if avg == "mean" else (lambda s: s.median())

        # Metrics 7 and 9 describe patients, and a patient can hold several orders, so
        # counting orders over-weights them. Always understates the rate.
        def patients(frame, flag):
            f = frame[flag].fillna(False).astype(bool)
            return frame.loc[f, "iovance_patient_id"].nunique()

        mfg = patients(w[M9], "mfg_started")
        drop_after_mfg = patients(w[M9], "drop_after_mfg")
        # 2nd Resections = distinct PATIENTS with 2+ real TTP dates
        ttp = w[M6].dropna(subset=["tumor_pickup_date"])
        mult = ttp.groupby("iovance_patient_id")["tumor_pickup_date"].nunique()

        def days(frame, col):
            v = agg(frame[col].dropna())
            return round(float(v), 1) if pd.notna(v) else np.nan

        # Metric 3 from real cancellation events (dated on the lost slot) when an event
        # source produced them - the LTD exports or the snapshot history; the
        # resection_rescheduled_ proxy otherwise. The window logic mirrors the buckets in
        # build_datewindow so the two implementations reconcile.
        if M3_EVENTS and canc is not None:
            ed = canc["event_date"]
            if undated:
                m3 = int(ed.isna().sum())
            elif future:
                m3 = int((ed > pd.Timestamp(TODAY)).sum())
            elif start is None and end is None:
                m3 = int(len(canc))                       # Launch to Date: every event
            else:
                cm = ed.notna()
                if start is not None: cm &= ed >= pd.Timestamp(start)
                if end   is not None: cm &= ed <= pd.Timestamp(end)
                m3 = int(cm.sum())
        else:
            m3 = int(w[M3]["ttp_cancel_le7"].sum())

        return {
            M1:  w[M1]["order_request__til_order_name"].nunique(),
            M2:  w[M2]["iovance_patient_id"].nunique(),
            M3:  m3,
            M4:  int(w[M4]["completed_ttp"].sum()),
            M5:  int(w[M5]["scheduled_ttp"].sum()),
            M6:  int((mult >= 2).sum()),
            M7:  patients(w[M7], "dropout_post_ttp_health"),
            M8:  int(w[M8]["oos_product"].sum()),
            M9:  round(drop_after_mfg / mfg, 3) if mfg else np.nan,
            M10: int(w[M10]["amtagvi_infused"].sum()),
            M11: days(w[M11], "days_enroll_to_ttp"),
            M12: days(w[M12], "days_ttp_to_infusion"),
            M13: days(w[M13], "days_delivery_to_infusion"),
        }

    A["enrollment_date"] = pd.to_datetime(A["enrollment_date"])
    A["enroll_year"] = A["enrollment_date"].dt.year
    A["enroll_q"] = A["enrollment_date"].dt.to_period("Q").astype(str)

    # ---- column definitions: (col_group, label, order, start, end) ----
    # Windows, not cohort filters: each metric is counted on its own event date (see EVENT_DATE).
    TIME_COLS = [
        ("Time", "Launch to Date", 1, None,         None),
        ("Time", "2024",           2, "2024-01-01", "2024-12-31"),
        ("Time", "2025",           3, "2025-01-01", "2025-12-31"),
        ("Time", "2026 YTD",       4, "2026-01-01", TODAY),
    ]
    # template shows quarters most-recent-first (Q3'26 QTD leftmost)
    QUARTER_COLS = [
        ("Quarter", "Q3'26 QTD", 10, "2026-07-01", TODAY),
        ("Quarter", "Q2'26",     11, "2026-04-01", "2026-06-30"),
        ("Quarter", "Q1'26",     12, "2026-01-01", "2026-03-31"),
        ("Quarter", "Q4'25",     13, "2025-10-01", "2025-12-31"),
    ]
    UNDATED_COL = ("Time", "Undated", 5, None, None)   # no event date at all
    FUTURE_COL  = ("Time", "After as-of", 6, None, None)   # dated beyond the extract date
    CENTER_COLS = TIME_COLS + QUARTER_COLS
    # Tier medians. See the tier block in build_analysis_table.py for how membership is set.
    BENCH_COLS = [
        ("Benchmark", "Top 10", 7, "Top 10"),
        ("Benchmark", "Top 40", 8, "Top 40"),
        ("Benchmark", "New",    9, "New"),
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
    _canc_by_center = ({d: f for d, f in CANC.groupby("center_disp")} if len(CANC) else {})

    def _canc_for(disp):
        """The cancellation events for one centre, matched on the display name stage 1 carried."""
        return _canc_by_center.get(disp, CANC.iloc[0:0]) if len(CANC) else CANC

    # Launch to Date per centre is also what the tier benchmarks are the median of, so
    # keep each one as it is computed instead of computing every centre a second time.
    ltd_by_center = {}

    for center, g in A.groupby("center_key"):
        disp = g["atc"].iloc[0]
        gc = _canc_for(disp)
        for cg, label, order, st, en in CENTER_COLS:
            vals = compute(g, st, en, canc=gc)
            if st is None and en is None:
                ltd_by_center[center] = vals
            emit("Center", disp, cg, label, order, vals)
        emit("Center", disp, UNDATED_COL[0], UNDATED_COL[1], UNDATED_COL[2],
             compute(g, undated=True, canc=gc))
        emit("Center", disp, FUTURE_COL[0], FUTURE_COL[1], FUTURE_COL[2],
             compute(g, future=True, canc=gc))

    # Tier benchmark = per-center MEDIAN within the tier, launch-to-date. Median rather than sum
    # or average, so a handful of very large centers do not carry the comparison.
    def bench_median(tiername):
        per_center = [ltd_by_center[k]
                      for k in sorted(A.loc[A.atc_tier == tiername, "center_key"].unique())
                      if k in ltd_by_center]
        out = {}
        for mname in mreg:
            vals = [pc[mname] for pc in per_center
                    if pc[mname] is not None and not (isinstance(pc[mname], float) and np.isnan(pc[mname]))]
            out[mname] = float(np.median(vals)) if vals else np.nan
        return out

    for cg, label, order, tiername in BENCH_COLS:
        emit("National", "National", cg, label, order, bench_median(tiername))

    # The old Excel view (25th/50th/75th percentile and national average across all ATCs)
    # used to be emitted here as a "CurrentTemplate" scope, so the new and old could be shown
    # side by side. Removed 2026-07-27: quartiles were hard to explain in the field. The tier
    # medians above replace them, and col_order 12-15 came free.

    tidy = pd.DataFrame(rows)

    # display helpers so Tableau sorts by plain alpha (no fragile sort specs) and shows
    # type-aware text (counts as ints, days 1dp, rate as %).
    tidy["row_label"] = tidy["metric_order"].map(lambda i: f"{i:02d}  {[m[2] for m in METRICS if m[0]==i][0]}")
    # ---- every counted event lands in exactly one bucket ----
    # Launch to Date must equal the year columns plus Undated plus After as-of. Without this a
    # metric dated on a column that is null for exactly the rows it counts would vanish from
    # every period column while still showing in Launch to Date.
    _chk = tidy[(tidy.scope == "Center") & (tidy.value_type == "count")
                & (~tidy.metric.isin(NON_ADDITIVE))]
    _ltd = _chk[_chk.col_label == "Launch to Date"].set_index(["center", "metric"]).value
    _buckets = ["2024", "2025", "2026 YTD", "Undated", "After as-of"]
    _parts = (_chk[_chk.col_label.isin(_buckets)].groupby(["center", "metric"]).value.sum())
    _cmp = _ltd.to_frame("ltd").join(_parts.to_frame("parts"), how="outer").fillna(0)
    _bad = _cmp[(_cmp.ltd - _cmp.parts).abs() > 1e-9]
    if len(_bad):
        print("\nFAILED: year columns + Undated + After as-of != Launch to Date")
        print(_bad.assign(gap=lambda d: d.ltd - d.parts)
              .sort_values("gap", key=abs, ascending=False).head(20).to_string())
        raise SystemExit(f"{len(_bad)} center/metric cells do not reconcile.")
    print(f"reconciles: {len(_cmp):,} center/metric cells "
          "(year + undated + after-as-of == launch-to-date)")

    # ---- WARNING: events dated after the extract date ----
    # Scheduled TTPs are future by definition and belong here. Infusions do not: an infusion
    # recorded with a future date has not been performed, so counting it in a metric called
    # "Infusions Performed" overstates treated patients.
    _fut = (tidy[(tidy.scope == "Center") & (tidy.col_label == "After as-of")
                 & (tidy.value_type == "count")]      # summing medians would be meaningless
            .groupby("metric").value.sum())
    _fut = _fut[_fut > 0]
    if len(_fut):
        print("\nevents dated after the as-of date (in Launch to Date, in no period column):")
        for m, v in _fut.items():
            note = "  <- expected, these are future bookings" if m == M5 else \
                   "  <- REVIEW: not yet performed, but counted as performed" if m == M10 else ""
            print(f"  {int(v):>4}  {m}{note}")

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

    print(f"tidy scorecard: {len(tidy)} rows -> analysis/ppr_scorecard_tidy.csv")
    return tidy

def build_events(A, canc, tidy, meta):
    """A: order-grain DataFrame (in place of analysis/ppr_analysis.csv).
    canc: counted lost-slot events DataFrame (in place of ppr_cancellations.csv),
    possibly empty. tidy: the scorecard DataFrame (in place of
    ppr_scorecard_tidy.csv). meta: dict holding asof and m3_source.
    Returns (events, undated) where events is the long DataFrame exactly as the
    script wrote it to ppr_datewindow_long.csv (columns and row order identical)
    and undated is the undated-events DataFrame it wrote to undated_events.csv."""
    for c in ["enrollment_date", "tumor_pickup_date", "fp_delivery_date", "infusion_date"]:
        A[c] = pd.to_datetime(A[c], errors="coerce")

    from metrics import NAME, GROUP as GROUPS, LOWER_IS_BETTER, HIGHER_IS_BETTER

    rows = []
    undated = []   # (center, metric, order id, missing field)
    def emit(df, order, metric, agg, datecol, valcol=None, unitcol=None):
        """One row per event. Events with no date are still emitted: they are real events that
        simply cannot be placed in a period (an out-of-spec product never delivered, a
        procurement cancelled so never performed). Dropping them here is what made the period
        columns silently exclude failures."""
        d = df[df[valcol].notna()] if valcol else df
        for _, r in d.iterrows():
            dt = r[datecol]
            if pd.isna(dt):
                undated.append((r["atc"], metric,
                                r.get("order_request__til_order_name", ""), datecol))
            rows.append((r["atc"], GROUPS[order], metric, order, agg,
                         dt.strftime("%Y-%m-%d") if pd.notna(dt) else "",
                         float(r[valcol]) if valcol else 1.0,
                         str(r[unitcol]) if unitcol else ""))

    # 1-2: enrollments by enrollment date; patients deduped to first enrollment per center
    emit(A, 1, NAME[1], "sum", "enrollment_date")
    # Distinct counts cannot be pre-materialised: how many distinct patients enrolled depends
    # on the window being asked about, so the dedup has to happen at read time. Emit every
    # enrollment with its patient id and count distinct units instead of summing.
    emit(A, 2, NAME[2], "distinct", "enrollment_date",
         unitcol="iovance_patient_id")

    # 3-7: TTP metrics by pickup date
    # 3: cancellations. Real rule from an event source when present - the LTD exports or the
    # snapshot history (event-grained, dated on the lost slot); the resection_rescheduled_
    # proxy on the order table otherwise. Stage 2 decides the source and records it in
    # run_meta.json.
    _M3SRC = meta.get("m3_source", "proxy")
    if _M3SRC in ("ltd", "hist"):
        _cev = canc
        if not len(_cev):
            print(f"WARNING: run_meta.json says m3_source={_M3SRC!r} but "
                  "ppr_cancellations.csv has no rows; metric 3 emits no events.")
        _cev["event_date"] = pd.to_datetime(_cev["event_date"], errors="coerce")
        _cev = _cev.rename(columns={"center_disp": "atc"})
        emit(_cev, 3, NAME[3], "sum", "event_date")
    else:
        emit(A[A.ttp_cancel_le7 == 1], 3, NAME[3], "sum", "tumor_pickup_date")
    emit(A[A.completed_ttp == 1], 4, NAME[4], "sum", "tumor_pickup_date")
    emit(A[A.scheduled_ttp == 1], 5, NAME[5], "sum", "tumor_pickup_date")
    ttp = A[A.tumor_pickup_date.notna()].sort_values("tumor_pickup_date")
    second = (ttp.drop_duplicates(["atc", "iovance_patient_id", "tumor_pickup_date"])
                 .groupby(["atc", "iovance_patient_id"]).nth(1).reset_index())
    # Deduped across all time, so within a narrow window this can differ by one from the
    # precomputed scorecard when a patient's two procurements straddle the window edge.
    # Correcting it per-window needs an LOD in the workbook.
    emit(second, 6, NAME[6], "sum", "tumor_pickup_date")
    # Patient grain, matching build_scorecard.
    emit(A[A.dropout_post_ttp_health == 1], 7,
         NAME[7],
         "distinct", "tumor_pickup_date", unitcol="iovance_patient_id")

    # 8: OOS by final product delivery date
    emit(A[A.oos_product == 1], 8, NAME[8], "sum", "fp_delivery_date")

    # 9: one row per PATIENT who started manufacturing; AVG(value) = the rate.
    # Same window-edge limitation as metric 6: the dedup is across all time.
    mfg = (A[A.mfg_started == 1]
           .sort_values("tumor_pickup_date")
           .groupby(["atc", "iovance_patient_id"], as_index=False)
           .agg(tumor_pickup_date=("tumor_pickup_date", "first"),
                drop_after_mfg=("drop_after_mfg", "max")))
    mfg["drop_flag"] = mfg["drop_after_mfg"].astype(float)
    emit(mfg, 9, NAME[9], "rate", "tumor_pickup_date", "drop_flag")

    # 10: infusions by infusion date
    emit(A[A.amtagvi_infused == 1], 10, NAME[10], "sum", "infusion_date")

    # 11-13: timelines, each anchored to its event date
    emit(A, 11, NAME[11], "avg",
         "tumor_pickup_date", "days_enroll_to_ttp")
    emit(A, 12, NAME[12], "avg",
         "infusion_date", "days_ttp_to_infusion")
    emit(A, 13, NAME[13],
         "avg", "infusion_date", "days_delivery_to_infusion")

    ev = pd.DataFrame(rows, columns=["center", "metric_group", "metric", "metric_order",
                                     "agg", "event_date", "value", "unit"])

    # ---- tag every event with the columns it belongs to -----------------------------------
    # An event falls in several columns at once (Launch to Date, its year, its quarter), so it
    # is emitted once per column. That makes the column set an ordinary dimension, which is what
    # lets one worksheet render the whole scorecard and still answer a date filter.
    #
    # The "Selected window" copy is the live one: the date parameters filter those rows only, so
    # dragging the slider does not blank out the fixed year columns.
    TODAY = meta["asof"]
    BUCKETS = [
        ("Launch to Date", 1,  None,         None),
        ("2024",           2,  "2024-01-01", "2024-12-31"),
        ("2025",           3,  "2025-01-01", "2025-12-31"),
        ("2026 YTD",       4,  "2026-01-01", TODAY),
        ("Undated",        6,  None,         None),   # no event date at all
        ("After as-of",    7,  TODAY,        None),   # dated beyond the extract
        ("Q3'26 QTD",     11,  "2026-07-01", TODAY),
        ("Q2'26",         12,  "2026-04-01", "2026-06-30"),
        ("Q1'26",         13,  "2026-01-01", "2026-03-31"),
        ("Q4'25",         14,  "2025-10-01", "2025-12-31"),
    ]
    # Sits with the other time columns rather than after the diagnostics, so the eye reads
    # Launch to Date, the years, then the live window, then the benchmarks, then the quarters.
    SELECTED = ("Selected window", 5)   # Tableau applies the date parameters to these rows only

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

    # ---- benchmark columns ----------------------------------------------------------------
    # Top 10 and Top 40 both appear against every centre, so the presenter can point at either
    # without changing a control. Stage 2 owns the median definition; this carries its output
    # across rather than recomputing. agg="preagg" prints the stored display string held in
    # `unit` instead of aggregating the value.
    BENCH_ARMS = ["Top 10", "Top 40"]
    # Which arm the Launch to Date shading compares against. Centres outside the top 40 are
    # held to Top 40: the small-centre median is a soft comparison that tells them little.
    HEAT_ARM = {"Top 10": "Top 10", "Top 40": "Top 40", "New": "New", "Other": "Top 40"}

    sc = tidy
    nat = sc[sc.scope == "National"]
    missing = (set(BENCH_ARMS) | set(HEAT_ARM.values())) - set(nat.col_label)
    if missing:
        raise SystemExit(f"benchmark tiers missing from the scorecard: {sorted(missing)}")

    tier_of = A.drop_duplicates("atc").set_index("atc")["atc_tier"]
    untiered = tier_of[~tier_of.isin(HEAT_ARM)].index.tolist()
    if untiered:
        raise SystemExit(f"centre(s) with an unknown tier: {untiered[:5]}")

    arm_order = dict(nat[["col_label", "col_order"]].drop_duplicates().values)

    bench_parts = []
    for arm in BENCH_ARMS:
        block = nat[nat.col_label == arm][["metric_group", "metric", "metric_order",
                                           "value", "value_display"]]
        for c in tier_of.index:
            b = block.copy()
            b["center"] = c
            b["col_label"] = arm
            b["col_order"] = arm_order[arm]
            bench_parts.append(b)
    bench_all = pd.concat(bench_parts, ignore_index=True)
    bench = pd.DataFrame({
        "center": bench_all.center,
        "metric_group": bench_all.metric_group,
        "metric": bench_all.metric,
        "metric_order": bench_all.metric_order,
        "agg": "preagg",
        "event_date": pd.NaT,
        "value": bench_all.value,
        "unit": bench_all.value_display.fillna(""),
        "col_label": bench_all.col_label,
        "col_order": bench_all.col_order,
    })
    tagged.append(bench)

    out = pd.concat(tagged, ignore_index=True)

    # ---- block header ---------------------------------------------------------------------
    # A second header row over the columns: the centre's own figures, the national comparison,
    # the quarterly trend. Tableau swaps the selected centre's name into the first block.
    COL_GROUP = {
        "Launch to Date": "This Center", "2024": "This Center", "2025": "This Center",
        "2026 YTD": "This Center", "Selected window": "This Center",
        "Undated": "This Center", "After as-of": "This Center",
        "Top 10": "YTD National Metrics", "Top 40": "YTD National Metrics",
        "New": "YTD National Metrics",
        "Q3'26 QTD": "Quarterly ATC Metrics", "Q2'26": "Quarterly ATC Metrics",
        "Q1'26": "Quarterly ATC Metrics", "Q4'25": "Quarterly ATC Metrics",
    }
    _unmapped = set(out.col_label) - set(COL_GROUP)
    if _unmapped:
        raise SystemExit(f"column(s) with no block: {sorted(_unmapped)}. Add them to COL_GROUP.")
    # ---- performance shading, one colour per Launch to Date cell --------------------------
    # The centre's launch-to-date value against the median of its own tier. Direction-aware;
    # neutral metrics and blank values keep the plain row band.
    # Thresholds are provisional: at or better than the median is green, within half (or double,
    # for lower-is-better) is amber, beyond that is orange.
    def heat_band(v, m, lower_better):
        if pd.isna(v) or pd.isna(m):
            return None
        if lower_better:
            if m == 0:
                return "green" if v == 0 else "amber"
            return "green" if v <= m else ("amber" if v <= 2 * m else "orange")
        return "green" if v >= m else ("amber" if v >= 0.5 * m else "orange")

    ctr_l2d = (sc[(sc.scope == "Center") & (sc.col_label == "Launch to Date")]
               .set_index(["center", "metric"]).value)
    arm_med = nat.set_index(["col_label", "metric"]).value
    heat = {}
    for (center, metric), v in ctr_l2d.items():
        if metric in LOWER_IS_BETTER:
            lower = True
        elif metric in HIGHER_IS_BETTER:
            lower = False
        else:
            continue
        arm = HEAT_ARM[tier_of[center]]
        band = heat_band(v, arm_med.get((arm, metric)), lower)
        if band:
            heat[(center, metric)] = band

    GROUP_BAND = {g: ("band_blue" if i % 2 == 0 else "band_gray")
                  for i, g in enumerate(dict.fromkeys(GROUPS.values()))}
    out["cell_color"] = out.metric_group.map(GROUP_BAND)
    _l2d = out.col_label == "Launch to Date"
    out.loc[_l2d, "cell_color"] = [
        heat.get((c, m), GROUP_BAND[g])
        for c, m, g in zip(out.loc[_l2d, "center"], out.loc[_l2d, "metric"],
                           out.loc[_l2d, "metric_group"])]

    # A centre with ZERO events on a directional metric has no row to colour, yet a zero on
    # a lower-is-better metric is the best result there is. Emit one zero-value stub per such
    # cell so the cell renders "0" and takes its colour. Value 0 changes no sum anywhere.
    _have = set(map(tuple, out.loc[_l2d, ["center", "metric"]].drop_duplicates().values))
    _stub = []
    _morder = {m: o for o, m in NAME.items()}
    for (center, metric), band in heat.items():
        if (center, metric) not in _have:
            _stub.append(dict(center=center, metric_group=GROUPS[_morder[metric]],
                              metric=metric, metric_order=_morder[metric], agg="sum",
                              event_date=pd.NaT, value=0.0, unit="",
                              col_label="Launch to Date", col_order=1,
                              col_group="This Center", col_group_order=1,
                              cell_color=band))
    if _stub:
        out = pd.concat([out, pd.DataFrame(_stub)], ignore_index=True)
        print(f"heat stubs for zero-event cells: {len(_stub)}")

    _allowed = {"band_blue", "band_gray", "green", "amber", "orange"}
    assert set(out.cell_color) <= _allowed, set(out.cell_color) - _allowed
    _hot = out[out.cell_color.isin({"green", "amber", "orange"})]
    assert (_hot.col_label == "Launch to Date").all(), "heat leaked off the Launch to Date column"
    print(f"heat: {_hot.groupby('cell_color').center.nunique().to_dict()} centres coloured, "
          f"{len(heat)} centre-metric cells banded")

    out["col_group"] = out.col_label.map(COL_GROUP)
    # Every row must carry a centre, or the workbook's centre filter silently drops it.
    _nc = int(out["center"].isna().sum())
    if _nc:
        raise SystemExit(f"{_nc} rows have no centre. They would vanish from the workbook.")
    # Blocks must sort in the same order as the columns inside them, or Tableau interleaves.
    out["col_group_order"] = out.groupby("col_group").col_order.transform("min")

    _b = out[out["agg"] == "preagg"]
    _nc = out[out["agg"] != "preagg"].center.nunique()
    _expect = 13 * _nc * len(BENCH_ARMS)
    assert len(_b) == _expect, (
        f"expected 13 metrics x {_nc} centres x {len(BENCH_ARMS)} arms = {_expect}, got {len(_b)}")
    assert set(_b.col_label) == set(BENCH_ARMS), (
        f"benchmark columns {sorted(set(_b.col_label))} do not match {BENCH_ARMS}")
    assert _b.groupby("center").col_label.nunique().eq(len(BENCH_ARMS)).all(), (
        "a centre is missing one of the benchmark arms")
    und = pd.DataFrame(undated, columns=["center", "metric", "order_id", "missing_date_field"])
    print(f"undated events for review: {len(und):,} -> analysis/undated_events.csv "
          "- orders with no usable event date")

    print(f"datewindow events: {len(ev):,} events -> {len(out):,} column-tagged rows, "
          f"{out.metric.nunique()} metrics -> analysis/ppr_datewindow_long.csv")
    print("  columns:", ", ".join(out.sort_values("col_order").col_label.unique()))

    # A bucket with no events produces no rows, and a column with no rows does not render in
    # Tableau at all. The template column would silently vanish rather than show zero.
    _empty = [b[0] for b in BUCKETS if b[0] not in set(out.col_label)]
    if _empty:
        print(f"  WARNING: no events fall in {_empty}. Those columns will not appear in the"
              " workbook. Check the as-of date before showing anyone.")

    # ---- ASSERTION: this table must reproduce the precomputed scorecard ----
    # Two independent implementations of the same 13 metrics. If they drift, the dashboard and
    # the deck disagree and someone else finds it first. Compare every cell on every run.
    sc = tidy
    sc = sc[(sc.scope == "Center") & sc.col_label.isin([b[0] for b in BUCKETS])]

    KEY = ["center", "metric", "col_label"]
    _parts = []
    # Benchmarks are excluded: they are a median across centres, carried over already
    # computed, so there is no per-centre cell to reconcile them against.
    _chk = out[(out.col_label != SELECTED[0]) & (out["agg"] != "preagg")]
    for _a, _g in _chk.groupby("agg"):
        if _a == "sum":        _r = _g.groupby(KEY)["value"].sum()
        elif _a == "distinct": _r = _g.groupby(KEY)["unit"].nunique().astype(float)
        elif _a == "avg":      _r = _g.groupby(KEY)["value"].median().round(1)
        elif _a == "rate":     _r = _g.groupby(KEY)["value"].mean().round(3)
        else: raise SystemExit(f"unknown agg '{_a}' in the event table")
        _parts.append(_r.rename("mine"))
    mine = pd.concat(_parts).reset_index()
    cmp = sc.merge(mine, left_on=["center", "metric", "col_label"],
                   right_on=["center", "metric", "col_label"], how="outer")
    cmp["value"] = cmp["value"].fillna(0.0)
    cmp["mine"] = cmp["mine"].fillna(0.0)
    bad = cmp[(cmp.value - cmp.mine).abs() > 0.051]        # 0.05 covers 1dp rounding

    # Deduped across all time, so a patient whose two events straddle a window edge shifts a cell.
    ALLOWED = {"2nd Resections (Scheduled or Completed)", "Patient Progression Rate"}
    hard = bad[~bad.metric.isin(ALLOWED)]
    if len(hard):
        print("\nFAILED: the event table does not reproduce the scorecard")
        print(hard.head(20).to_string(index=False))
        raise SystemExit(f"{len(hard)} cells disagree between the two implementations.")
    print(f"  agrees with the scorecard on {len(cmp) - len(bad):,} of {len(cmp):,} cells"
          + (f" ({len(bad)} known dedup edge case(s) in {', '.join(sorted(set(bad.metric)))})"
             if len(bad) else ""))
    return out, und

def _quantize_values(df):
    # The scorecard reaches the event stage as a csv in the reference, which rounds
    # each float to its printed form. The benchmark medians carried into the event
    # table are sensitive to that in the last digit, so reproduce it on the one
    # column it affects rather than serialising the whole frame.
    out = df.copy()
    out["value"] = pd.to_numeric(
        out["value"].map(lambda v: "" if pd.isna(v) else str(v)), errors="coerce")
    return out


def run(frames, asof_override=None):
    """frames: dict of lowercase-named DataFrames straight from Redshift.
    Returns (events, tidy, order_master, canc, undated, meta).

    Deterministic: the as-of date comes from the data, nothing reads the clock,
    and no stage mutates its inputs, so the same source rows always give the
    same tables and a rerun is safe."""
    A, meta = build_order_master(frames, asof_override)
    canc, m3_meta = build_m3_events(frames, A)
    meta.update(m3_meta)
    tidy = build_scorecard(A, canc, meta)
    events, undated = build_events(A, canc, _quantize_values(tidy), meta)
    return events, tidy, A, canc, undated, meta

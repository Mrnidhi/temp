# 03 - Processing Rules and Open Questions

All file paths are relative to `git/PPR/July 27/` unless stated. Labels:
Confirmed / Inferred / TBD / Needs TWBX verification.

## Confirmed Processing Rules

| Order | Rule type | Input | Exact rule | Output | Evidence |
| ----- | --------- | ----- | ---------- | ------ | -------- |
| 1 | Date logic | orders export | As-of date = `PPR_ASOF` env var if set, else `max(order_request__created_date)`. Recorded in `run_meta.json`; no stage reads the clock. | run_meta.json `asof` | `pipeline/build_analysis_table.py:36-41,151-164`. Confirmed |
| 2 | Filter | input folder | When resolving non-history filenames, exclude any file whose name contains `hist` (the snapshot history has several rows per order and would multiply every count). | correct source files | `build_analysis_table.py:111-115`. Confirmed |
| 3 | Date logic | orders export | `enrollment_date` = `order_request__created_date`; `tumor_pickup_date` = `tumor_tissue_pick_up_date`; `fp_delivery_date` = `final_product_delivery_date`; all parsed with coerce-to-null. | 3 working dates | `build_analysis_table.py:167-170`. Confirmed |
| 4 | Null handling | patient_zip_code | `patient_zip_clean` = numeric zip kept only where 1001 <= zip <= 99950, else null (source column carries junk placeholders). | patient_zip_clean | `build_analysis_table.py:171-173`. Confirmed |
| 5 | Aggregation | tumor documentation | `tpf_count` = count of tumor rows per `til_order_name`, 0 when absent; `has_tumor` = tpf_count > 0. | per-order counts | `build_analysis_table.py:177-180`. Confirmed |
| 6 | Join | infusion export | Infusion fields mapped one-to-one on `til_order_name`; `amtagvi_infused` = order has an infusion row AND `lifileucel_infused_` = "Yes" AND `infusion_date` is not null. | infusion flags | `build_analysis_table.py:188-194`. Confirmed |
| 7 | Deduplication + Join | Veeva mapping | Mapping deduplicated on `center_key` (keep first), then orders LEFT JOIN mapping on `center_key` = normalized center name (lowercase, legal suffixes and punctuation stripped, whitespace collapsed). Unmatched orders keep null region/segment. | region, territory, atc_segment | `build_analysis_table.py:197-202`; `pipeline/cancellations.py:44-52`. Confirmed |
| 8 | Calculation | tumor_pickup_date | `completed_ttp` = pickup date not null AND <= as-of; `scheduled_ttp` = pickup date > as-of. Asserted mutually exclusive. (The manager's 2026-07-31 ruling: Scheduled means still upcoming.) | M4, M5 flags | `build_analysis_table.py:204-223`; `PPR Automation/VALIDATION LOG - dashboard.md`. Confirmed |
| 9 | Calculation | oos_status | `oos_product` = (oos_status = "Confirmed OOS"). | M8 flag | `build_analysis_table.py:210`. Confirmed |
| 10 | Category mapping | til_order_cancellation_reason | Every reason maps to a category (health, choice, favourable, operational, physician, access, quality, other). Health list: Patient health progressed, Decline in Performance Status, Disease Progression, Brain Mets, Patient death, Transition to Hospice. Patient-related = health + Patient Choice. NED/MRD deliberately excluded (patient responded). Unmapped values print a WARNING but do not stop the run. | reason categories | `build_analysis_table.py:48-99,227-243`. Confirmed |
| 11 | Calculation | fp_status | `mfg_started` = fp_status in {MFG Start, MFG End, REP Initiation, REP Scale Out, Released for Shipment by QA, Shipment Ready, Courier Picked-Up FP, Courier Delivered FP, FP CAH}. The five starting-material states are excluded (including them inflates the metric-9 denominator by roughly a third). | M9 denominator flag | `build_analysis_table.py:91-99,211`; `SOURCE TO TARGET MAPPING.md` Part D. Confirmed |
| 12 | Calculation | flags | `dropout_post_ttp_health` = has_tumor AND reason in health list; `drop_after_mfg` = mfg_started AND reason in (health + Patient Choice). | M7, M9 numerator flags | `build_analysis_table.py:213-216`. Confirmed |
| 13 | Calculation | working dates | `days_enroll_to_ttp` = pickup - enrollment; `days_ttp_to_infusion` = infusion - pickup; `days_delivery_to_infusion` = infusion - delivery; negative values set to null (out-of-order dates). | M11-M13 inputs | `build_analysis_table.py:245-249`. Confirmed |
| 14 | Category mapping | orders per center | Centers ranked by distinct orders. `New` = first enrollment year >= 2025 (proxy; no onboarding source exists); if NO center qualifies, the 12 lowest-enrollment centers are labeled New instead. Otherwise rank <= 10 is "Top 10", rank 11-40 is "Top 40", else "Other". Re-ranked every run. | atc_tier | `build_analysis_table.py:255-279` (fallback at 266-267). Confirmed |
| 15 | Filter | LTD_Reschedules + LTD_Cancellations | Metric-3 event counts iff 0 <= days_notice <= 7, where days_notice = lost slot date - recorded date. Both directions (Postponed, Moved Up) count; grain = events (an order losing two slots counts twice); event dated on the LOST slot. Dropped with counted reasons: never-booked, negative notice (administrative cleanup), more than 7 days notice, direction not in the counted set (currently a zero bucket since both directions count). Drop funnel must reconcile to rows in. | ppr_cancellations.csv | `pipeline/cancellations.py:32-41,118-162`; `pipeline/build_cancellations.py:48-56`. Confirmed |
| 16 | Join | LTD events | LTD files carry no center; events join to the analysis table on ORDER_ID = order_request__til_order_name. Unmatched events are warned and EXCLUDED from metric 3. Stage 2's source chain is LTD files, else snapshot history walk, else `resection_rescheduled_` proxy, recorded as `m3_source` in run_meta.json. Both consuming stages accept either event source (`m3_source in ("ltd", "hist")`) and print a loud WARNING if an event source is claimed but the event table is empty. (A defect where the consumers tested only for "hist" - so LTD files silently fell back to the proxy - was fixed 2026-08-03; verified by a baseline no-change run on the proxy path plus a stub-LTD run where the scorecard computed metric 3 from the 4 stub events.) | events with centers | `build_cancellations.py:58-91`; `build_scorecard.py:29-37,98`; `build_datewindow.py:60-65`. Confirmed (measured) |
| 17 | Date logic | all metrics | Every metric is windowed on its own event date: M1/M2 on enrollment_date; M3(proxy)/M4/M5/M6/M7/M9/M11 on tumor_pickup_date; M8 on fp_delivery_date; M10/M12/M13 on infusion_date. Undated events sit in Launch to Date and the Undated column only; events after as-of sit in After as-of. | per-column values | `pipeline/metrics.py:54-60`; `pipeline/build_scorecard.py:36-68`. Confirmed |
| 18 | Calculation | ppr_analysis | M1 = distinct order names; M2 = distinct patient ids; M4/M5/M8/M10 = sums of their flags; M6 = distinct patients with 2 or more distinct pickup dates; M7 = distinct patients with dropout_post_ttp_health. | metric values | `build_scorecard.py:107-121`. Confirmed |
| 19 | Calculation | ppr_analysis | M9 Patient Progression Rate = distinct patients with drop_after_mfg / distinct patients with mfg_started (patient-distinct because one patient can hold several orders); null when the denominator is 0. | M9 | `build_scorecard.py:74-79,116`. Confirmed |
| 20 | Calculation | day-diff columns | M11/M12/M13 = MEDIAN of the day-diffs (blanks ignored, never substituted), 1 decimal. Median vs average is still an open business question (see below). | M11-M13 | `build_scorecard.py:84-86,118-120`. Confirmed |
| 21 | Aggregation | per-tier scorecards | Benchmark columns Top 10 / Top 40 / New = the MEDIAN across tier-member centers of each center's launch-to-date value (median so a few very large centers do not carry the comparison). The old 25th/50th/75th percentile "CurrentTemplate" rows were removed 2026-07-27. | benchmark rows | `build_scorecard.py:176-194`. Confirmed |
| 22 | Aggregation | events | Final Events table: each event emitted once per column bucket it falls in, plus one copy tagged "Selected window" (the only copy the date parameters filter); benchmark values carried over (not recomputed) as pre-aggregated rows replicated per center; zero-value stubs added so directional cells render 0. | ppr_datewindow_long.csv | `pipeline/build_datewindow.py:118-199,259-273`. Confirmed |
| 23 | Validation gate | scorecard | Build stops unless, per center per metric, Launch to Date = 2024 + 2025 + 2026 YTD + Undated + After as-of for additive count metrics. M2/M6/M7 are exempt: they count distinct patients and do not sum across periods (this "looks wrong" behavior is by design and must survive any port). | pass/fail | `build_scorecard.py:201-218`; `SOURCE TO TARGET MAPPING.md` lines 186-188. Confirmed |
| 24 | Validation gate | event table vs scorecard | Stage 4 re-aggregates its own event table and compares every cell to the scorecard (tolerance 0.051); the build stops on disagreement EXCEPT for two exempt metrics: "2nd Resections (Scheduled or Completed)" (documented window-edge dedup case, 1 cell in 3,309 on the test sample) and "Patient Progression Rate" (exempt in code, acknowledged only in a code comment - disagreements of any size on these two never stop the build). | pass/fail | `build_datewindow.py:342-343` (ALLOWED set); `ONE DASHBOARD - Tableau build.md`. Confirmed |

## Final Tableau Output

| Item | Current understanding |
| -------------------- | --------------------- |
| Dataset name | `tableau/ppr_datewindow.hyper`, table `Events` (built from `analysis/ppr_datewindow_long.csv`). Confirmed. Target: the same rows land in Redshift as `ppr.ppr_events` and Tableau connects there (agreed 2026-08-03; see `glue/`) |
| Dataset grain | One row per metric event per column bucket, plus a "Selected window" copy per event, plus pre-aggregated benchmark rows and zero stubs. Confirmed |
| Unique key | None by design; same-day events emit identical rows. Confirmed |
| Required fields | center, metric_group, metric, metric_order, agg, event_date, value, unit, col_label, col_order, cell_color, col_group, col_group_order (header order verbatim). Confirmed (CSV header measured) |
| Important dimensions | center, metric_group, metric, col_label (with col_order for sorting), agg | 
| Important measures | value (SUM / MEDIAN / AVG depending on `agg`); unit (COUNTD target for the patient-distinct metrics) |
| Date field | event_date (each event dated on its own metric event; see rule 17) |
| Incremental field | None; every run is a full rebuild from the current exports. Confirmed |
| Historical range | Launch to Date = all history in the extract (orders from 2024; LTD events from Aug 2024). Exact earliest order date: TBD. Real-data as-of at last run: 2026-07-31 |

The `agg` column is the aggregation contract Tableau must follow per row:
`sum` = SUM(value); `distinct` = COUNTD(unit); `avg` = MEDIAN(value); `rate` =
AVG(value) shown as a percent; `preagg` = display the string carried in `unit`.
Confirmed: `build_datewindow.py` docstring; `ONE DASHBOARD - Tableau build.md`.

## Needs TWBX Verification

The build doc (`ONE DASHBOARD - Tableau build.md`) specifies the workbook, and
the production workbook was partially checked on 2026-08-03, but full
verification of the .twbx is still pending. Verify:

- [ ] The three calculated fields match the build doc verbatim, especially
      `Result`: the doc's `"avg"` branch is `MEDIAN([value])`; a superseded
      spec used `AVG` and must not have leaked in. Doc formulas: `Keep Center`
      = `[center] = [pCenter]`; `Keep Row` = date test applied only where
      `col_label = "Selected window"`; `Result` = the four-branch `agg` switch.
- [ ] Parameters: `pCenter` (String), `pStart` / `pEnd` (Date). Whether
      pCenter's list was created as "Add values from field" (a static snapshot
      list will NOT pick up new centers on refresh).
- [ ] Which sources are connected (Events only, or also the other two hypers)
      and live-vs-extract per source, plus any extract filters.
- [ ] Tableau-only filters beyond `Keep Center` / `Keep Row` = True
      (e.g. whether the Undated column is filtered out of the display).
- [ ] Any LOD expressions or table calculations (the known 2nd-resections
      per-window dedup gap would need an LOD; the doc says none exists).
- [ ] Sets, groups, actions, row-level security: expected none; confirm.
- [ ] Custom SQL: expected none (file-based sources); confirm.
- [ ] Refresh configuration (expected: manual Desktop extract refresh; no
      server schedule).
- [ ] Hidden fields used by calculations; field renames/aliases on top of the
      extract columns.

## Decided so far (2026-08-03)

- Architecture: raw Infinity data lands in Redshift, a daily Glue job runs the
  preparation unchanged, the final Events table lands back in Redshift as
  `ppr.ppr_events`, and Tableau connects directly to that table. Tableau never
  connects to Infinity. Job files: `glue/`.
- Tableau refresh trigger: only after the Glue job succeeds; on failure the
  previous table stays in place.

## Questions for the Data Engineering Team

1. How does the raw Infinity data land in Redshift, and on what schedule
   (the loader is owned by data engineering; the job assumes the tables are
   current when it runs)?
2. Full rebuild is the current model and it is cheap (thousands of rows).
   Any reason to go incremental?
3. What time should the daily job run, given when the raw loads finish and
   when reviewers need the dashboard?
4. What is the expected dashboard-ready time after data lands?
5. How should late-arriving and undated events be handled upstream? The
   pipeline currently quarantines them in Undated / After as-of columns
   rather than dropping them.
6. How should source deletions be handled? A full rebuild silently forgets
   orders that vanish from the raw tables; is that acceptable or should we diff?
7. The pipeline already has two hard validation gates (rules 23-24) plus a
   golden-baseline diff tool (`pipeline/baseline.py`). They run inside the Glue
   job automatically; should any extra checks gate the Redshift load?
8. Who owns job monitoring and failure alerts?
9. Which environment should development and testing use? A seeded sample-data
   generator exists (`PPR Automation/synthetic_data/generate_synthetic.py`)
   that matches the real schema, null rates, and join coverage.

## Questions for Me to Confirm

- Metric 3 direction: do "Moved Up" reschedules count as lost slots? Both
  directions count today; on the real LTD data the split is roughly half and
  half (380 Postponed vs 335 Moved Up). Open with the manager.
- Metric 3 grain: an order losing two slots counts twice today. Confirm
  events vs orders.
- Metrics 11-13: median (current) vs average (template wording); the two
  reference decks disagree with each other. Open.
- "New" benchmark tier: no onboarding-date source exists anywhere; today it
  is proxied by first-enrollment year. A supplied list or the column drops.
- Undated events (233 on the last counted real-data run): leave quarantined in
  the Undated column, or handle differently? Note the OOS case: a confirmed-OOS
  product often never ships, so its delivery date is null and the missingness
  correlates with the outcome.
- Free-text drop-out reasons: when the reason is "Other", the real reason sits
  in the `_other` text column and is uncounted today. No ruling yet.
- Enrollments definition: orders (current) vs distinct patients; and the
  enrollment date = order creation date. Listed as open in the older README;
  confirm it is settled.
- Expected totals for a known window exist for validation (a reviewer deck
  with per-metric numbers as of 11 May 2026); the next validation run should
  use them.

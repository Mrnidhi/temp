# PPR data dictionary — every dataset and column

Three layers on this Mac (synthetic data, real Infinity schema):
1. **7 source exports** (`synthetic_data/out/*.xlsx`) — raw Infinity/Veeva files, header on row 3.
2. **Analysis table** (`analysis/ppr_analysis.csv`) — one row per TIL order, 2,250 rows x 62 cols. THE working dataset.
3. **Scorecard tidy** (`analysis/ppr_scorecard_tidy.csv`) — long/pivoted metric output for Tableau.

Extract as-of date: 2026-07-21. Real refresh = drop the real 7 files into `synthetic_data/out/`, rerun the pipeline.

---

## Layer 2: Analysis table — `ppr_analysis.csv` (62 cols, one row per order)

### Identity / order
- `order_request__til_order_name` — TIL order id (the order grain; primary key)
- `iovance_patient_id` — patient id (a patient can have multiple orders)
- `coi_number`, `lot_number` — certificate-of-injection and manufacturing lot
- `center_key` — normalized ATC name (lowercased) used for joins
- `atc` — ATC center display name
- `treating_physician`, `tumor_procurement_surgeon`, `referring_physician`

### Statuses
- `patient_status`, `order_status`, `fp_status` (final product), `infusion_release_status`
- `oos_status` (out-of-spec), `manufacturing_plant`, `prior_authorization`, `person_account__age`
- `resection_rescheduled_`

### Raw dates (the ones the date filter uses)
- `order_request__created_date`, `til_order_submission_date`
- `enrollment_date` (= created date), `tumor_tissue_pick_up_date` / `tumor_pickup_date`
- `final_product_shipping_date`, `final_product_delivery_date` / `fp_delivery_date`
- `suggested_infusion_date`, `infusion_date`

### Cancellation reasons
- `til_order_cancellation_reason` (+ `_other`), `pick_up_cancellation_reason` (+ `_other_desc`),
  `fp_delivery_cancellation_reason` (+ `_other_desc`)

### Geography / segment (from Veeva Komodo mapping)
- `patient_zip_code`, `patient_zip_clean`, `veeva_name`, `region`, `territory`,
  `atc_segment`, `atc_tier` (Top 10 / Top 40 / New / Other), `center_matched`

### Derived flags (computed by the pipeline — the metric building blocks)
- `has_tumor`, `has_slot`, `has_infusion`, `tpf_count`, `second_resection`
- `completed_ttp`, `scheduled_ttp`, `ttp_cancel_le7` (PROXY, see notes)
- `oos_product`, `mfg_started`, `amtagvi_infused`, `lifileucel_infused`
- `dropout_post_ttp_health`, `patient_related_dropout`, `drop_after_mfg`

### Derived timing (days)
- `days_enroll_to_ttp`, `days_ttp_to_infusion`, `days_delivery_to_infusion`
- `enroll_year`, `enroll_q`

---

## Layer 1: The 7 source exports

**BAI - List of Orders** (2,251 rows, 30 cols) — the spine. order name, created date, patient id,
submission date, atc, physicians, patient/order/fp status, pickup date, resection rescheduled,
fp shipping/delivery dates, suggested infusion date, infusion release status, mfg plant, oos status,
3 cancellation-reason pairs, prior auth, age, lot, coi, referring physician, patient zip.

**BAI TTP Data** (2,584 rows, 11 cols) — mfg plant account, slot name, slot date, cm slot visible,
slot status, booking status, til order name, lost capacity, booked-by, site account, unavailable reason.

**BAI Slot Data** (2,584 rows, 11 cols) — same 11 columns as TTP Data (slot/booking grain).

**BAI Tumor Documentation** (1,127 rows, 15 cols) — coi, til order name, tumor procurement form name,
name, tpf_status, location, lesion type, location_other, orientation, lesion_type_other,
method_of_surgery (+ other), additional notes, created by, tumor tissue pickup date.

**BAI Infusion** (1,003 rows, 13 cols) — til order name, coc closure, IL-2 regimen received,
HD IL-2 doses omitted, NMA-LD regimen received, NMA-LD start/end date, cyclophosphamide doses,
fludarabine doses, lifileucel infused, infusion date, reason not infused, last modified by.

**Veeva Komodo ATC Mapping** (85 rows, 11 cols) — veeva_name, city, state, zip, county, territory,
region, pps_status, ic_ttp_baseline, atc_segment, start_segment. (Center master for geo/segment/tier.)

**Veeva Call Activity** (70,534 rows, 15 cols) — date, npi, name, key opinion leader, interaction type,
interaction name, primary parent name, territory, community_top_50, community_top_25, atc_target,
community_target, pulse_alert, status, location. (Rep call data; not used by the 13 metrics yet —
this is the source that could feed the "Closest Community Treaters" provider tables in Kolin's decks.)

---

## Layer 3: Scorecard tidy — `ppr_scorecard_tidy.csv` (8,931 rows, 13 cols)
`scope` (Center/National/CurrentTemplate), `center`, `col_group`, `col_label`, `col_order`,
`metric_group`, `metric`, `metric_order`, `value_type` (count/rate/days), `value`,
`row_label`, `col_final`, `value_display` (pre-formatted string). One row per center x column x metric.

---

## Known proxies / gaps (carry into any build)
- `ttp_cancel_le7` (metric 3) is a PROXY. The true rule is cancel/reschedule within 7 days of the
  scheduled slot; that needs Infinity's snapshot history (Jonathan's feed), not in these exports.
- `atc_tier` "New" needs each center's onboarding year; approximated from the mapping today.
- "Closest Community Treaters" needs provider-level claims/Veeva data — separate from the 13 metrics.

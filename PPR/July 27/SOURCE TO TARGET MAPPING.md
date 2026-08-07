# P&PR scorecard - source to target mapping

Field-level specification for the pipeline behind the Tableau dashboard. Written so the logic
can be reimplemented without reading the Python.

Read with `DATA LINEAGE - for data engineering.md`, which gives the stage-level flow. This file
gives the column-level detail.

Conventions used below: **grain** is what one row represents, **event date** is the date column
a metric is counted on, and **exclusions** are rows deliberately not counted. Every exclusion
is a decision on the record, not an oversight.

---

## Part A. Source columns consumed

Everything the pipeline reads. Columns not listed are ignored.

### bai_list_of_orders — the hub, one row per TIL order

| Source column | Used for |
|---|---|
| `order_request__til_order_name` | primary key, join key to every child table |
| `iovance_patient_id` | patient grain for metrics 2, 6, 7, 9 |
| `order_request__created_date` | enrolment event date, and the as-of date |
| `tumor_tissue_pick_up_date` | TTP event date, completed/scheduled split |
| `final_product_delivery_date` | out-of-spec event date, delivery-to-infusion interval |
| `atc` | centre name, joined to the mapping and used for tiering |
| `oos_status` | out-of-spec flag |
| `fp_status` | manufacturing-started flag |
| `til_order_cancellation_reason` | drop-out classification for metrics 7 and 9 |
| `resection_rescheduled_` | retained for reference only; never used for metric 3 |
| `patient_zip_code` | cleaned but drives no metric |

### bai_tumor_documentation

| Source column | Used for |
|---|---|
| `til_order_name` | counted per order to give `tpf_count`, which gives `has_tumor` |

### bai_infusion

| Source column | Used for |
|---|---|
| `til_order_name` | join key |
| `infusion_date` | infusion event date |
| `lifileucel_infused_` | infusion confirmation, must equal `Yes` |

### veeva_komodo_atc_mapping

| Source column | Used for |
|---|---|
| `veeva_name` | matched to `atc` on a normalised key |
| `region`, `territory`, `atc_segment` | carried through, drive no metric |

### LTD_Reschedules

| Source column | Used for |
|---|---|
| `ORDER_ID` | join key back to the order table for the centre |
| `TTP_DATE_PREV` | the slot that was given up, and the event date |
| `SNAPSHOT_DATE_TIME_CURR` | when the change was first seen, cast to a date |
| `RESCHEDULED_CATEGORY` | `Postponed` or `Moved Up`, controls whether it counts |

### LTD_Cancellations

| Source column | Used for |
|---|---|
| `ORDER_ID` | join key back to the order table for the centre |
| `TTP_DATE` | the slot that was lost, and the event date |
| `SNAPSHOT_DATE_TIME_CURR` | when the change was first seen, cast to a date |
| `CANCELLATION_REASON` | carried through, does not currently filter |

`TTP_DATE_CURR`, `SNAPSHOT_DATE_TIME_PREV` and `RESCHEDULE_ORDER` arrive in the LTD files and
are not consumed.

---

## Part B. Derived fields, order grain

Target table: one row per TIL order. All of these live on that row.

| Target field | Type | Derived from | Rule |
|---|---|---|---|
| `enrollment_date` | date | `order_request__created_date` | direct rename |
| `tumor_pickup_date` | date | `tumor_tissue_pick_up_date` | direct rename |
| `fp_delivery_date` | date | `final_product_delivery_date` | direct rename |
| `infusion_date` | date | `bai_infusion.infusion_date` | joined on order name |
| `center_key` | text | `atc` | lowercased, legal suffixes and punctuation stripped, whitespace collapsed |
| `tpf_count` | int | `bai_tumor_documentation` | count of rows per order, 0 when absent |
| `has_tumor` | bool | `tpf_count` | `tpf_count > 0` |
| `completed_ttp` | bool | `tumor_pickup_date` | pickup is not null **and** on or before the as-of date |
| `scheduled_ttp` | bool | `tumor_pickup_date` | pickup is not null **and** after the as-of date |
| `oos_product` | bool | `oos_status` | equals `Confirmed OOS` |
| `mfg_started` | bool | `fp_status` | in the manufacturing status set, see Part D |
| `dropout_post_ttp_health` | bool | `has_tumor`, `til_order_cancellation_reason` | had a procurement **and** the reason is a health reason |
| `patient_related_dropout` | bool | `til_order_cancellation_reason` | reason is health or patient choice |
| `drop_after_mfg` | bool | `mfg_started`, `patient_related_dropout` | both true |
| `amtagvi_infused` | bool | infusion join | has an infusion row **and** `lifileucel_infused_ = 'Yes'` **and** infusion date is not null |
| `days_enroll_to_ttp` | int | two dates | `tumor_pickup_date - enrollment_date` |
| `days_ttp_to_infusion` | int | two dates | `infusion_date - tumor_pickup_date` |
| `days_delivery_to_infusion` | int | two dates | `infusion_date - fp_delivery_date` |
| `atc_tier` | text | enrolment counts | centres ranked by distinct orders; top 10, then top 40, else other |

**`completed_ttp` and `scheduled_ttp` are mutually exclusive by construction.** Scheduled means
still to come. Adding the two gives total procurements; they must never overlap.

---

## Part C. Lost slots, event grain

Target table: one row per lost slot. Separate from the order table because one order can lose
several slots, and each loss belongs to its own date.

| Target field | Type | Derived from | Rule |
|---|---|---|---|
| `order` | text | `ORDER_ID` | as supplied |
| `event_date` | date | `TTP_DATE_PREV` or `TTP_DATE` | the slot that was lost, not the day the change was entered |
| `recorded_on` | date | `SNAPSHOT_DATE_TIME_CURR` | cast to a date |
| `days_notice` | int | the two above | `event_date - recorded_on` |
| `kind` | text | which source table | `rescheduled` or `cancelled` |
| `direction` | text | `RESCHEDULED_CATEGORY` | `Postponed`, `Moved Up`, or empty for a cancellation |
| `reason` | text | `CANCELLATION_REASON` | empty for a reschedule |
| `center` | text | order table | joined on order id, since neither LTD table carries a centre |

**Inclusion rule.** A row counts when `days_notice` is between 0 and 7 inclusive.

**Exclusions, each reported with a count on every run:**

| Excluded | Why |
|---|---|
| no slot was ever booked | nothing was lost |
| `days_notice` negative | recorded after the date passed, so administrative cleanup |
| `days_notice` above 7 | enough notice to refill the slot |
| direction not in the counted set | currently both directions count, see open questions |

---

## Part D. Controlled vocabularies

These strings drive metric values. An unrecognised value must stop the run or be reported, never
fall silently into no bucket.

**Health reasons** — drive metric 7:
`Patient health progressed`, `Decline in Performance Status`, `Disease Progression`,
`Brain Mets`, `Patient death`, `Transition to Hospice`

**Patient-related reasons** — drive the metric 9 numerator: the health list above plus
`Patient Choice`.

`NED/MRD` is deliberately excluded. No evidence of disease means the patient responded, so
counting it as progression would report a good outcome as a failure.

**Manufacturing started** — drives the metric 9 denominator:
`MFG Start`, `MFG End`, `REP Initiation`, `REP Scale Out`, `Released for Shipment by QA`,
`Shipment Ready`, `Courier Picked-Up FP`, `Courier Delivered FP`, `FP CAH`

The five starting-material states are the courier leg **before** manufacturing and are excluded:
`SM Pick-up Scheduled`, `Courier Picked-Up SM`, `Warehouse Received SM`, `MFG QA Released SM`,
`MFG Received SM`. Including them inflates the denominator by roughly a third and understates
the rate.

---

## Part E. The 13 metrics

Every metric filters to rows whose **own** event date falls in the column's window, then
aggregates. There is no single cohort date across the board.

| # | Metric | Grain | Event date | Rule |
|---|---|---|---|---|
| 1 | Enrollments in IovanceCares | order | `enrollment_date` | distinct order names |
| 2 | Patients Enrolled in IovanceCares | patient | `enrollment_date` | distinct patient ids |
| 3 | TTPs Cancelled or Rescheduled within 7 Days | event | lost slot date | count of rows in the lost-slot table |
| 4 | Completed TTPs | order | `tumor_pickup_date` | sum of `completed_ttp` |
| 5 | Scheduled TTPs | order | `tumor_pickup_date` | sum of `scheduled_ttp` |
| 6 | 2nd Resections | patient | `tumor_pickup_date` | patients holding 2 or more distinct pickup dates |
| 7 | Patient Related Drop-outs following TTP | patient | `tumor_pickup_date` | distinct patients where `dropout_post_ttp_health` |
| 8 | OOS Products | order | `fp_delivery_date` | sum of `oos_product` |
| 9 | Patient Progression Rate | patient | `tumor_pickup_date` | distinct patients with `drop_after_mfg` divided by distinct patients with `mfg_started` |
| 10 | AMTAGVI Infusions Performed | order | `infusion_date` | sum of `amtagvi_infused` |
| 11 | Median Time From Enrollment Date to TTP | order | `tumor_pickup_date` | median of `days_enroll_to_ttp` |
| 12 | Median Time From TTP to AMTAGVI Infusion | order | `infusion_date` | median of `days_ttp_to_infusion` |
| 13 | Median Time From Final Product Delivery to Infusion | order | `infusion_date` | median of `days_delivery_to_infusion` |

**Metrics 2, 6 and 7 are non-additive.** They count patients, so year columns can sum to more
than the launch-to-date figure. A patient enrolled in two years is one patient overall and
appears in both years. This is correct and must survive any port.

**Metrics 11 to 13 are medians, not averages.** Confirmed against the rendering layer.

---

## Part F. Output columns

The table the dashboard reads. One row per event, per column it belongs to.

| Column | Type | Meaning |
|---|---|---|
| `center` | text | centre display name |
| `metric` | text | metric name, from the single definition file |
| `metric_group` | text | one of four row groups |
| `metric_order` | int | display order 1 to 13 |
| `agg` | text | how to aggregate: `sum`, `distinct`, `avg` meaning median, `rate`, `preagg` |
| `event_date` | date | the date this event is counted on, empty when undated |
| `value` | numeric | 1 for a count event, the day count for a timing, 0 or 1 for the rate |
| `unit` | text | the patient id for distinct counts, the display string for benchmarks |
| `col_label` | text | which column this row belongs to |
| `col_order` | int | display order of the column |
| `cell_color` | text | row band or performance shading |

An event is emitted once per column it belongs to, so one infusion in August 2026 appears under
Launch to Date, 2026 year to date, and the third quarter. This is what lets a single worksheet
answer any date filter.

---

## Part G. Data quality expectations

These gate the build. They are not tests run separately; a failure stops the run before any
output is written.

| Check | Expectation |
|---|---|
| Column reconciliation | period columns plus undated plus after-as-of equals launch to date, per centre per metric |
| Cross-implementation | the event table matches the precomputed scorecard cell by cell |
| Vocabulary | every cancellation reason maps to a known category, or is named in the output |
| Disjointness | no order is both completed and scheduled |
| Funnel | counted lost slots plus every excluded category equals rows in |
| Benchmark shape | benchmark rows equal 13 metrics times centres times arms |

**Determinism.** The as-of date is the newest order creation date in the extract, never the
system clock. The same inputs produce the same outputs on any day, and the as-of date is
recorded in every output file.

---

## Part H. Open decisions

Three rules are not settled. Each is a named constant in one place, so changing one is a
one-line edit and not a rewrite.

1. **Reschedule direction.** A TTP moved earlier still frees the original slot but does not
   delay the patient. Both currently count. Roughly half the reschedules are `Moved Up`.
2. **Lost-slot grain.** One order losing two slots currently counts twice. The alternative is
   counting affected orders once.
3. **The New ATCs benchmark.** No table records when a centre was authorised or onboarded, so
   the tier cannot be derived. It needs a supplied list or the column is dropped.

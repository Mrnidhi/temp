# Infinity schema profile (transcribed from office-laptop profiler)

Source: office-laptop Claude profiled the 7 real Infinity `.xlsx` files (schema only,
no row values). This is the blueprint the synthetic generator matches.

PHI note: files are de-identified at patient level (`iovance_patient_id` is a SHA-256
hash, ages are age-banded), but they DO carry physician/staff names, `npi`, and
`patient_zip_code`. Real headers are NOT on row 1 — there is a title/banner row;
the true header row is at row index 2 (spreadsheet row 3) for every file.

---

## 1. `veeva_komodo_atc_mapping.xlsx` — 84 rows · PK `veeva_name` · center `veeva_name`
| Column | dtype | %null | min | max | mean | median | distinct / values |
|---|---|---|---|---|---|---|---|
| **veeva_name** (PK, center) | string | 0.0 | | | | | 84 · `XXXXXXXXXX XX XXXX...`, `XXXXXX-XXXXXX...` |
| city | string | 0.0 | | | | | 65 |
| state | string | 0.0 | | | | | 35 |
| zip | int | 0.0 | 2114 | 98109 | 47173 | 43658 | |
| county | string | 1.2 | | | | | 58 |
| territory | string | 0.0 | | | | | 24: AR/MO/Tulsa, CT/NYC, Carolinas, Desert Plains, Great South, IN/KY/Cincy, Illinois, Los Angeles, MN/WI, Mid-Atlantic, Midwest, New England, North FL/GA, North TX/OK, Northern Cal, Northern NJ & NYC, OH/MI, Pacific Northwest, Philly, Pittsburgh/Cleveland, Rocky Mountains, San Diego/OC, South FL, South TX/LA |
| region | string | 0.0 | | | | | 5: Central, Great Lakes, Northeast, South, West |
| pps_status | string | 88.1 | | | | | 1: Exempt |
| ic_ttp_baseline | float | 0.0 | 0.0 | 3.6 | 0.7 | 0.5 | |
| atc_segment | string | 0.0 | | | | | 3: High Potential, Other, Top Account |
| start_segment | string | 25.0 | | | | | 4: Declined, Exempt, High OOS, New Low Volume |

## 2. `bai_ttp_data.xlsx` — 2,583 rows · PK `slot_name` · date `slot_date`
| Column | dtype | %null | min | max | mean | median | distinct / values |
|---|---|---|---|---|---|---|---|
| manufacturing_plant__account_name | string | 0.0 | | | | | 2: Advanced Therapies, ICTC |
| **slot_name** (PK) | string | 0.0 | | | | | 2583 · `XX-####` |
| slot_date | date | 0.0 | 2024-02-16 | 2026-09-16 | 2025-06-17 | 2025-06-19 | |
| cm_slot_visible | bool | 0.0 | | | | | False, True |
| slot_status | string | 0.0 | | | | | 3: Available, Claimed, Unavailable |
| booking_status | string | 0.0 | | | | | 3: Available, Reserved, Unavailable |
| til_order_name (join) | string | 36.4 | | | | | 1643 · `XXX-XXX####` |
| lost_capacity | bool | 0.0 | | | | | False, True |
| slot_booked_by__full_name | string | 36.4 | | | | | 228 |
| site__account_name (center) | string | 36.4 | | | | | 77 |
| unavailable_reason | string | 87.5 | | | | | 5: Clinical, Converted, Manufacturer, Reserved, Slot Reallocated |

## 3. `bai_slot_data.xlsx` — 2,583 rows · PK `slot_name` · date `slot_date`
Schema **identical** to `bai_ttp_data.xlsx` (same columns, dtypes, distincts, ranges,
and same `til_order_name` set). Two views of the same slot table.

## 4. `bai_tumor_documentation.xlsx` — 1,126 rows · PK `name` · date `tumor_tissue_pick_up_date`
| Column | dtype | %null | min | max | mean | median | distinct / values |
|---|---|---|---|---|---|---|---|
| coi (join) | string | 0.0 | | | | | 869 · `#########X` |
| til_order_name (join) | string | 0.0 | | | | | 869 · `XXX-XXX####` |
| tumor_procurement_form_name | string | 0.0 | | | | | 869 · `XXX-####` |
| **name** (PK) | string | 0.0 | | | | | 1126 · `XXX-#####` |
| tpf_status | string | 0.0 | | | | | 3: Canceled, Complete, Ready |
| location | string | 0.0 | | | | | 41 |
| lesion_type | string | 0.1 | | | | | 21: Adrenal, Axillary, Central Nervous System, Cervical, Cutaneous/Subcutaneous, Deep Pelvic, Inguinal, Lymph Node, Mucosal, Osseous, Other, Peritoneum/Omentum, Skin/Cutaneous, Soft Tissue, Subcutaneous, Visceral, Visceral - Adrenal, Visceral - Intestines (Small), Visceral - Liver, Visceral - Lung, Visceral Organ - Thyroid/Parathyroid |
| location_other | string | 92.4 | | | | | 71 |
| orientation | string | 11.9 | | | | | 4: Center, Left Side, Other, Right Side |
| lesion_type_other | string | 89.2 | | | | | 79 |
| method_of_surgery | string | 0.0 | | | | | 6: Endoscopic, Laparoscopic, Open Surgery, Other, Robotic, Thoracoscopic |
| method_of_surgery_other | string | 97.6 | | | | | 14 |
| additional_notes | string | 78.8 | | | | | 223 |
| created_by_full_name | string | 0.0 | | | | | 269 |
| tumor_tissue_pick_up_date | date | 0.1 | 2025-05-27 | 2026-07-17 | 2026-01-03 | 2026-01-16 | |

Note: `name` unique (1126) but `til_order_name`/`coi`/`tpf` each 869 distinct → ~257 rows are repeat orders (multiple TPFs per order).

## 5. `veeva_call_activity.xlsx` — 70,533 rows · PK `interaction_name` · date `date`
Does NOT join to BAI order data. Keys on `npi`/`name` (HCP) and `primary_parent_name`
(account, 4,410 distinct). Only bridge to the rest is account name →
`veeva_komodo_atc_mapping.veeva_name`. Join at center level, not patient/order level.
| Column | dtype | %null | min | max | mean | median | distinct / values |
|---|---|---|---|---|---|---|---|
| date | date | 0.0 | 2022-01-04 | 2026-11-10 | 2025-05-01 | 2025-07-22 | |
| npi | int | 30.2 | 12507813 | 2020032641 | 1.48e9 | 1477531580 | |
| name | string | 0.0 | | | | | 14537 |
| key_opinion_leader | string | 87.2 | | | | | 8: Cell Therapy, Cervical, Gyn/Onc, Head & Neck, Melanoma, NSCLC, Other, Surgical Oncology |
| interaction_type | string | 30.3 | | | | | 4: Email, In-Person Meeting, Phone, Remote Meeting |
| **interaction_name** (PK) | string | 0.0 | | | | | 70533 · `X########` |
| primary_parent_name | string | 5.4 | | | | | 4410 |
| territory | string | 0.0 | | | | | 139 |
| community_top_50 | bool | 0.0 | | | | | False, True |
| community_top_25 | bool | 0.0 | | | | | False, True |
| atc_target | bool | 0.0 | | | | | False, True |
| community_target | bool | 0.0 | | | | | False, True |
| pulse_alert | bool | 0.0 | | | | | False, True |
| status | string | 0.0 | | | | | 3: Planned, Saved, Submitted |
| location | string | 84.9 | | | | | 4: ATC - main site, ATC - satellite, Community, LCP site |

## 6. `bai_list_of_orders.xlsx` — 2,250 rows · PK `order_request__til_order_name` (also `coi_number`) · Patient ID `iovance_patient_id` · center `atc`
| Column | dtype | %null | min | max | mean | median | distinct / values |
|---|---|---|---|---|---|---|---|
| **order_request__til_order_name** (PK, join) | string | 0.0 | | | | | 2250 · `XXX-XXX####` |
| order_request__created_date | date | 0.0 | 2024-02-16 | 2026-07-16 | 2025-06-22 | 2025-07-08 | |
| iovance_patient_id | string | 0.0 | | | | | 2096 (SHA-256 hash; ~154 dup patients across orders) |
| til_order_submission_date | datetime | 7.5 | 2024-02-16 16:21 | 2026-07-17 05:47 | 2025-07-09 | 2025-07-25 15:55 | |
| atc (center) | string | 0.0 | | | | | 85 |
| treating_physician | string | 0.3 | | | | | 199 |
| tumor_procurement_surgeon | string | 6.3 | | | | | 399 |
| patient_status | string | 0.0 | | | | | 3: Consented, Inactive, Registered |
| order_status | string | 0.0 | | | | | 8: Canceled, Completed, Draft, Lot Received, Lot Requested, Manufacturing, TOR Confirmed, TOR Submitted |
| fp_status | string | 0.0 | | | | | 11: Courier Delivered FP, Courier Picked-Up FP, MFG End, MFG Start, Not Started, REP Initiation, REP Scale Out, RM Received, Released for Shipment by QA, SM Pick-up Scheduled, Shipment Ready |
| tumor_tissue_pick_up_date | date | 27.0 | 2024-02-20 | 2026-09-15 | 2025-07-22 | 2025-08-07 | |
| resection_rescheduled_ | bool | 0.0 | | | | | False, True |
| final_product_shipping_date | date | 43.8 | 2024-03-28 | 2026-10-19 | 2025-09-09 | 2025-09-24 | |
| final_product_delivery_date | date | 44.2 | 2024-03-29 | 2026-10-20 | 2025-09-13 | 2025-09-29 | |
| suggested_infusion_date | date | 27.0 | 2024-03-19 | 2026-10-13 | 2025-08-19 | 2025-09-04 | |
| infusion_release_status | string | 40.7 | | | | | 2: Do Not Infuse, Released for Infusion |
| manufacturing_plant | string | 27.0 | | | | | 2: Advanced Therapies, ICTC |
| oos_status | string | 82.4 | | | | | 3: Confirmed OOS, In Spec, Potential OOS |
| til_order_cancellation_reason | string | 58.2 | | | | | 17: 2nd Resection, Alternate Therapy, Brain Mets, Clinical Trial/IST/Collaboration, Decline in Performance Status, Disease Progression, Duplicate Patient, Financial Clearance, NED/MRD, Other, Patient Choice, Patient death, Patient health progressed, Physician decision, Quality Status: Do Not Proceed, Transition to Hospice |
| til_order_cancellation_reason_other | string | 84.9 | | | | | 309 (free text) |
| pick_up_cancellation_reason | string | 80.8 | | | | | 19 |
| pick_up_cancellation_reason_other_desc | string | 89.6 | | | | | 230 (free text) |
| fp_delivery_cancellation_reason | string | 63.1 | | | | | 24 |
| fp_delivery_cancellation_reason_other_desc | string | 83.2 | | | | | 323 (free text) |
| prior_authorization | bool | 0.0 | | | | | False, True |
| person_account__age | string | 0.0 | | | | | 70 (age-banded, `## XXXXX`) |
| lot_number | string | 25.6 | | | | | 1673 |
| coi_number (PK alt, join) | string | 0.0 | | | | | 2250 · `########X` |
| referring_physician | string | 34.8 | | | | | 950 (free text) |
| patient_zip_code | int | 0.0 | 0 | 9072523323 | 4.17e6 | 44601 | DIRTY: max out-of-range, min 0 → junk/placeholder values |

## 7. `bai_infusion.xlsx` — 1,002 rows · PK `til_order_name` (also `coc_closure`) · date `infusion_date`
| Column | dtype | %null | min | max | mean | median | distinct / values |
|---|---|---|---|---|---|---|---|
| **til_order_name** (PK, join) | string | 0.0 | | | | | 1002 · `XXX-XXX####` |
| coc_closure (PK alt) | string | 0.0 | | | | | 1002 · `XXX XXXXXXX - ####` |
| did_patient_receive_plan_il_2_regimen_ | bool | 53.8 | | | | | No, Yes |
| how_many_hd_il_2_doses_were_omitted_ | int | 71.3 | 1 | 6 | 2.8 | 3 | |
| did_patient_receive_plan_nma_ld_regimen_ | bool | 52.5 | | | | | No, Yes |
| nma_lymphodepletion__nma_ld___start_date | date | 52.3 | 2024-03-30 | 2026-07-06 | 2025-06-17 | 2025-06-23 | |
| nma_lymphodepletion__nma_ld___end_date | date | 52.9 | 2024-04-03 | 2026-07-12 | 2025-06-24 | 2025-07-04 | |
| cyclophosphamide_doses | int | 92.1 | 0 | 2 | 1.13 | 2 | |
| fludarabine_doses | int | 92.3 | 0 | 5 | 2.68 | 2 | |
| lifileucel_infused_ | bool | 6.3 | | | | | No, Yes |
| infusion_date | date | 10.0 | 2024-04-04 | 2026-07-15 | 2025-08-01 | 2025-08-25 | |
| reason_not_infused | string | 97.9 | | | | | 5: Other, Patient death, Patient health progressed, Quality Status: Do Not Proceed, Transition to Hospice |
| last_modified_by__full_name | string | 0.0 | | | | | 133 |

---

## Join map (the funnel)
Master = `bai_list_of_orders` (2,250 orders). Hub key = `til_order_name`
(= `order_request__til_order_name` in orders). Every other BAI file is a subset.

| Edge | Overlap | Coverage |
|---|---|---|
| infusion → orders | 1,002 | 100% of infusion; 45% of orders |
| tumor → orders | 869 orders (1,126 rows) | 100% of tumor; 39% of orders |
| slot → orders | 1,643 | 100% of slot; 73% of orders |
| ttp → orders | 1,643 | 100% of ttp; 73% of orders |
| infusion ∩ tumor | 537 | 54% of infusion / 62% of tumor |

Funnel: order → slot booked → tumor procured → infused (not every order reaches
every stage). `bai_slot_data` and `bai_ttp_data` share an identical order-key set.
Secondary join key `coi`/`coi_number`: `tumor.coi` 100% covered by `orders.coi_number`.

Center join (free-text account name, fuzzy, not an ID):
| Edge | Overlap | Coverage |
|---|---|---|
| orders.atc → atc_map.veeva_name | 79 | 94% of names; ~6 unmatched |
| slot.site → atc_map.veeva_name | 73 | 87% of names |
| orders.atc → slot.site | 77 | 100% of slot sites |

Needs a normalization/fuzzy-match pass before relying on center joins.

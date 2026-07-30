# Infinity queries to run

Open questions only. Anything already answered has been removed. Run in the Infinity SQL
explorer (`Iovance_BAI`).

Results are grouped counts, never patient rows. Paste results into chat, not into this file.

---

## 1. What segments does Iovance already use? (highest value)

The benchmark arm each centre sees depends on its tier, and "New" is currently *inferred*
from a centre's first enrolment year. That mislabels any centre that enrolled once before the
cutoff, which is why a centre described as new in the 07/28 review lands in the wrong arm.

The mapping table carries `ATC_SEGMENT` and `START_SEGMENT` — Iovance's own segmentation. If
those cleanly identify new and low-volume centres, the tier becomes a fact instead of a guess.

```sql
SELECT atc_segment, start_segment, COUNT(*) AS centres
FROM veeva_komodo_atc_mapping
GROUP BY atc_segment, start_segment
ORDER BY centres DESC;
```

**What it changes:** if the vocabulary is clean, the pipeline reads the tier from this field
instead of guessing, and the comparison arm is correct by construction.

---

## 2. Does every ordering centre have a segment?

Only worth acting on #1 if the mapping covers the centres that actually place orders. Any row
below with a null segment is a centre the tier rule could not classify.

```sql
SELECT o.atc,
       m.atc_segment,
       m.start_segment,
       COUNT(*) AS orders
FROM bai_list_of_orders o
LEFT JOIN veeva_komodo_atc_mapping m
       ON m.veeva_name = o.atc
GROUP BY o.atc, m.atc_segment, m.start_segment
ORDER BY orders DESC;
```

**What it changes:** decides whether the segment field can drive the tier for every centre, or
only most of them. If names do not join cleanly, the fix is a name-normalising join, not a
different field.

---

## 3. The real data-quality edge cases

The 07/28 review asked to see orders with no pickup date so the source data could be checked.
A plain null check overstates it: an order cancelled before a procurement was ever scheduled
correctly has no date. The suspicious ones are orders that moved *past* procurement without
one — those should not exist.

```sql
SELECT atc, COUNT(*) AS orders_missing_pickup_date
FROM bai_list_of_orders
WHERE tumor_tissue_pick_up_date IS NULL
  AND order_status IN ('Completed', 'Manufacturing', 'Lot Received')
GROUP BY atc
ORDER BY 2 DESC;
```

**What it changes:** turns a long list that is mostly expected into a short list that is
genuinely wrong, which is the version worth handing over.

---

## 4. Independent check of one centre, for validation

The dashboard has never been checked against a scorecard built by hand. This computes the
core counts straight from source, so one centre can be compared three ways: source SQL,
dashboard, and the existing hand-built deck. Three agreeing numbers is proof; two is a
coincidence.

Replace the centre name, and set the date to the as-of date in `analysis/run_meta.json` so
the completed/scheduled split matches what the pipeline used.

```sql
SELECT
  COUNT(DISTINCT order_request__til_order_name)                      AS enrollments,
  COUNT(DISTINCT iovance_patient_id)                                 AS patients,
  SUM(CASE WHEN tumor_tissue_pick_up_date IS NOT NULL
            AND tumor_tissue_pick_up_date <= DATE '<AS_OF>'
           THEN 1 ELSE 0 END)                                        AS completed_ttps,
  SUM(CASE WHEN tumor_tissue_pick_up_date >  DATE '<AS_OF>'
           THEN 1 ELSE 0 END)                                        AS scheduled_ttps,
  SUM(CASE WHEN oos_status = 'Confirmed OOS' THEN 1 ELSE 0 END)      AS oos_products
FROM bai_list_of_orders
WHERE atc = '<CENTRE NAME>';
```

Infusions live in a separate table:

```sql
SELECT COUNT(*) AS amtagvi_infusions
FROM bai_infusion i
JOIN bai_list_of_orders o
  ON o.order_request__til_order_name = i.til_order_name
WHERE o.atc = '<CENTRE NAME>'
  AND i.lifileucel_infused_ = 'Yes'
  AND i.infusion_date IS NOT NULL;
```

**What it changes:** this is the evidence the numbers can be trusted. Every difference found
here is one fewer surprise in front of a centre.

---

## Not a query: for the data owner

The snapshot history feed stops well before the current period and covers only part of the
order base. Metric 3 is measured rather than estimated now, but it can only see the period the
history covers. Ask whether that feed stopped, moved, or is filtered.

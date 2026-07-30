# Infinity queries to run

Open questions the pipeline cannot answer on its own. Each one below is a single query, the
reason it matters, and what its answer changes. Run them in the Infinity SQL explorer
(`Iovance_BAI`), which now has direct access to the same tables the seven exports come from.

**Sending results back:** aggregate counts only. Every query here returns grouped totals or
schema, never patient rows. Do not paste raw result rows into this file or into chat.

Dialect note: `load_datetime` is stored as a string like `YYYYMMDDThhmmss`. If your engine
types it as a timestamp instead, swap `SUBSTR(load_datetime, 1, 4)` for `YEAR(load_datetime)`.

---

## P0 - blocking, run these first

### 1. Does the snapshot history cover the current year?

Metric 3 counts a cancellation on **the date of the slot that was lost**, and that date only
exists in the history table. If history stops part-way through, recent-period columns are
legitimately empty and that is a fact about the data feed, not a bug in the pipeline. Right
now the dashboard shows nothing for the current year, and this settles why.

```sql
SELECT MIN(load_datetime) AS first_snapshot,
       MAX(load_datetime) AS last_snapshot,
       COUNT(*)           AS snapshot_rows,
       COUNT(DISTINCT order_request__til_order_name) AS orders
FROM bai_list_of_orders_hist;
```

And the shape of it year by year:

```sql
SELECT SUBSTR(load_datetime, 1, 4) AS snapshot_year,
       COUNT(*) AS snapshot_rows,
       COUNT(DISTINCT order_request__til_order_name) AS orders
FROM bai_list_of_orders_hist
GROUP BY 1
ORDER BY 1;
```

**If the last snapshot predates the current year:** the history feed itself has stopped. That
is a question for the data owner, and something to say out loud in the review rather than let
someone find an empty column.
**If it runs to the present:** the downloaded export was truncated. Re-pull it.

### 2. How many orders are actually cancelled?

A diagnostic keyed off a cancellation-reason column reported every order as cancelled, which
cannot be true. `order_status` carries clean `Completed` / `Canceled` values and is the right
field. This confirms the real proportion and fixes the diagnostic.

```sql
SELECT order_status, COUNT(*) AS orders
FROM bai_list_of_orders
GROUP BY order_status
ORDER BY orders DESC;
```

---

## P1 - this week

### 3. Is there a direct signal for a cancelled pickup?

The pipeline infers a cancellation by watching the booked pickup date change between
snapshots. `pick_up_cancellation_reason` is an explicit field for the same event. It carries
no timing, so it cannot replace the 7-day rule, but it can separate a genuine cancellation
from a data correction. Today both are counted.

```sql
SELECT pick_up_cancellation_reason, COUNT(*) AS orders
FROM bai_list_of_orders
GROUP BY pick_up_cancellation_reason
ORDER BY orders DESC;
```

### 4. The complete cancellation-reason picklists

The pipeline stops the build when it meets a reason it has no category for, so every possible
value needs a decision once. There are several reason columns, and two values are currently
uncategorised and therefore excluded from the drop-out and progression metrics.

```sql
SELECT 'til_order' AS source_column, til_order_cancellation_reason AS reason, COUNT(*) AS n
FROM bai_list_of_orders GROUP BY 1, 2
UNION ALL
SELECT 'pick_up', pick_up_cancellation_reason, COUNT(*)
FROM bai_list_of_orders GROUP BY 1, 2
UNION ALL
SELECT 'fp_delivery', fp_delivery_cancellation_reason, COUNT(*)
FROM bai_list_of_orders GROUP BY 1, 2
ORDER BY 1, 3 DESC;
```

Each value needs one of: patient health, patient choice, favourable outcome, operational,
physician, access, quality, other. That mapping lives in one place in `build_analysis_table.py`.

### 5. When was each centre authorised?

The "New" benchmark tier is currently inferred from a centre's first enrolment year, which
mislabels any centre that enrolled once before the cutoff. In the 07/28 review a centre
described as new was landing in a different tier for exactly this reason. If any table carries
an authorisation or onboarding date, the tier becomes a fact instead of a guess, and the
comparison arm each centre sees becomes correct by construction.

```sql
SELECT * FROM veeva_komodo_atc_mapping LIMIT 5;
```

Look for an activation, onboarding, or authorisation date column. If none exists here, the
same question applies to any ATC roster table available in this workspace.

---

## P2 - worth knowing, not blocking

### 6. Scheduled pickup date versus actual

"Completed TTPs" is currently counted on `tumor_tissue_pick_up_date`, the booked date. There
is also an `actual_tumor_pickup_date`. If the actual column is well populated and often
differs, the metric is counting the day the procurement was planned rather than the day it
happened.

```sql
SELECT COUNT(*)                            AS orders,
       COUNT(tumor_tissue_pick_up_date)    AS has_scheduled,
       COUNT(actual_tumor_pickup_date)     AS has_actual,
       SUM(CASE WHEN tumor_tissue_pick_up_date IS NOT NULL
                 AND actual_tumor_pickup_date IS NOT NULL
                 AND tumor_tissue_pick_up_date <> actual_tumor_pickup_date
                THEN 1 ELSE 0 END)         AS dates_differ
FROM bai_list_of_orders;
```

### 7. Orders with no pickup date, by centre

The 07/28 review asked to see these edge cases so the back-end data feeding them could be
checked. The pipeline already writes the same list to `analysis/undated_events.csv`; this is
the source-side view of it.

```sql
SELECT atc, COUNT(*) AS orders_with_no_pickup_date
FROM bai_list_of_orders
WHERE tumor_tissue_pick_up_date IS NULL
GROUP BY atc
ORDER BY 2 DESC;
```

### 8. Does the history agree with the current table?

The history carries an `islatest` flag. If the latest snapshot per order reproduces the orders
table, the two sources are consistent and the history can be trusted for anything the orders
table cannot answer.

```sql
SELECT islatest, COUNT(*) AS rows,
       COUNT(DISTINCT order_request__til_order_name) AS orders
FROM bai_list_of_orders_hist
GROUP BY islatest;
```

The `islatest = true` order count should match the order count in `bai_list_of_orders`.

---

## Why this list exists

Direct SQL access removes the guesswork that the seven file exports forced. Four of the
questions above were previously going to be asked of another team; all four are answerable
here in seconds. It is also the first step toward the dashboard reading from the database
instead of from manual downloads.

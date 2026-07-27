/* METRIC 3: TTPs Cancelled or Rescheduled within 7 Days Prior to Slot Reservation
   Infinity Explorer, database Iovance_BAI. ONE query at a time - paste a single block,
   run it, then move to the next. Each block is self-contained.

   WHY: the pipeline currently uses resection_rescheduled_ as a stand-in. On real data that
   flag is True on 347 of 1,295 orders (26.8%), while Kolin's UK Chandler deck reports 0.
   A proxy firing on a quarter of all orders is not approximating something that reads zero.

   THE METHOD, in Kolin's words (Meet 6): "They had a TTP date of August 14th 2024, and they
   cancelled it on August 9th. So it's checking the days between the snapshot, August 9th,
   and when it was cancelled, August 14th, and it's 5. So this would flag as a last-minute
   cancellation." Also: "I think it might use 3 today, but I think we want to use 7."

   So: walk each order's snapshots in order. When the planned pickup date changes or clears,
   measure from that snapshot's load date back to the date that had been booked. 7 days or
   fewer means the slot could not realistically be refilled, so it counts.

   GRAIN: bai_list_of_orders_hist is SCD Type-2, one row per order per snapshot,
   record_number 1..N per order. Do NOT filter islatest - the history IS the data.
   ============================================================================ */


/* ============================================================================
   QUERY 1 - START HERE. Does the date parsing work at all?
   Run this first. If load_dt or planned_ttp come back null, nothing else will work
   and it is a parsing problem, not a data problem.
   ============================================================================ */
SELECT
    til_order_name,
    record_number,
    load_datetime,
    CAST(SUBSTR(load_datetime, 1, 4) || '-' || SUBSTR(load_datetime, 5, 2) || '-'
         || SUBSTR(load_datetime, 7, 2) AS DATE)        AS load_dt,
    tumor_tissue_pick_up_date,
    CAST(NULLIF(tumor_tissue_pick_up_date, '') AS DATE) AS planned_ttp
FROM bai_list_of_orders_hist
ORDER BY til_order_name, record_number
LIMIT 30;


/* ============================================================================
   QUERY 2 - THE METRIC, per centre. This is the number the scorecard needs.
   ============================================================================ */
WITH snap AS (
    SELECT til_order_name, record_number, atc,
           CAST(SUBSTR(load_datetime, 1, 4) || '-' || SUBSTR(load_datetime, 5, 2) || '-'
                || SUBSTR(load_datetime, 7, 2) AS DATE)        AS snapshot_date,
           CAST(NULLIF(tumor_tissue_pick_up_date, '') AS DATE) AS planned_ttp
    FROM bai_list_of_orders_hist
),
changes AS (
    SELECT til_order_name, atc, snapshot_date, planned_ttp,
           LAG(planned_ttp) OVER (PARTITION BY til_order_name
                                  ORDER BY record_number) AS prev_ttp
    FROM snap
)
SELECT atc, COUNT(*) AS ttps_cancelled_or_resched_le7
FROM changes
WHERE prev_ttp IS NOT NULL
  AND (planned_ttp IS NULL OR planned_ttp <> prev_ttp)
  AND DATEDIFF('day', snapshot_date, prev_ttp) BETWEEN 0 AND 7
GROUP BY atc
ORDER BY ttps_cancelled_or_resched_le7 DESC;


/* ============================================================================
   QUERY 3 - SANITY CHECK. Read this before trusting query 2.
   Expect a national total FAR below 347. If it comes back near 347, the logic is
   wrong, not the data.
   ============================================================================ */
WITH snap AS (
    SELECT til_order_name, record_number,
           CAST(SUBSTR(load_datetime, 1, 4) || '-' || SUBSTR(load_datetime, 5, 2) || '-'
                || SUBSTR(load_datetime, 7, 2) AS DATE)        AS snapshot_date,
           CAST(NULLIF(tumor_tissue_pick_up_date, '') AS DATE) AS planned_ttp
    FROM bai_list_of_orders_hist
),
changes AS (
    SELECT til_order_name, snapshot_date, planned_ttp,
           LAG(planned_ttp) OVER (PARTITION BY til_order_name
                                  ORDER BY record_number) AS prev_ttp
    FROM snap
)
SELECT COUNT(*)                        AS late_changes,
       COUNT(DISTINCT til_order_name)  AS orders_affected
FROM changes
WHERE prev_ttp IS NOT NULL
  AND (planned_ttp IS NULL OR planned_ttp <> prev_ttp)
  AND DATEDIFF('day', snapshot_date, prev_ttp) BETWEEN 0 AND 7;


/* ============================================================================
   QUERY 4 - AUDIT TRAIL. The individual changes, so any number can be defended.
   Also how you confirm the logic reproduces Kolin's worked example.
   ============================================================================ */
WITH snap AS (
    SELECT til_order_name, record_number, atc,
           CAST(SUBSTR(load_datetime, 1, 4) || '-' || SUBSTR(load_datetime, 5, 2) || '-'
                || SUBSTR(load_datetime, 7, 2) AS DATE)        AS snapshot_date,
           CAST(NULLIF(tumor_tissue_pick_up_date, '') AS DATE) AS planned_ttp
    FROM bai_list_of_orders_hist
),
changes AS (
    SELECT til_order_name, atc, snapshot_date, planned_ttp,
           LAG(planned_ttp) OVER (PARTITION BY til_order_name
                                  ORDER BY record_number) AS prev_ttp
    FROM snap
)
SELECT atc, til_order_name,
       prev_ttp                                 AS was_booked_for,
       planned_ttp                              AS moved_to,
       snapshot_date                            AS change_seen_on,
       DATEDIFF('day', snapshot_date, prev_ttp) AS days_notice,
       CASE WHEN planned_ttp IS NULL THEN 'cancelled' ELSE 'rescheduled' END AS change_type
FROM changes
WHERE prev_ttp IS NOT NULL
  AND (planned_ttp IS NULL OR planned_ttp <> prev_ttp)
  AND DATEDIFF('day', snapshot_date, prev_ttp) BETWEEN 0 AND 7
ORDER BY atc, change_seen_on
LIMIT 100;


/* ============================================================================
   QUERY 5 - SENSITIVITY. Kolin thinks the old scorecard may use 3 days, and wants 7.
   This shows both, so moving the threshold is a defensible decision rather than a
   silent change.
   ============================================================================ */
WITH snap AS (
    SELECT til_order_name, record_number,
           CAST(SUBSTR(load_datetime, 1, 4) || '-' || SUBSTR(load_datetime, 5, 2) || '-'
                || SUBSTR(load_datetime, 7, 2) AS DATE)        AS snapshot_date,
           CAST(NULLIF(tumor_tissue_pick_up_date, '') AS DATE) AS planned_ttp
    FROM bai_list_of_orders_hist
),
changes AS (
    SELECT til_order_name, snapshot_date, planned_ttp,
           LAG(planned_ttp) OVER (PARTITION BY til_order_name
                                  ORDER BY record_number) AS prev_ttp
    FROM snap
),
moved AS (
    SELECT DATEDIFF('day', snapshot_date, prev_ttp) AS days_notice
    FROM changes
    WHERE prev_ttp IS NOT NULL
      AND (planned_ttp IS NULL OR planned_ttp <> prev_ttp)
      AND DATEDIFF('day', snapshot_date, prev_ttp) >= 0
)
SELECT SUM(CASE WHEN days_notice <= 3 THEN 1 ELSE 0 END) AS within_3_days,
       SUM(CASE WHEN days_notice <= 7 THEN 1 ELSE 0 END) AS within_7_days,
       COUNT(*)                                          AS all_forward_changes
FROM moved;


/* ============================================================================
   IF SYNTAX FAILS, two likely culprits:
     1. DATEDIFF - some engines want DATEDIFF(prev_ttp, snapshot_date) with the arguments
        reversed, or plain subtraction: (prev_ttp - snapshot_date).
     2. The load_datetime parse - if it is already a date or timestamp type, drop the
        SUBSTR wrapper and use the column directly.
   Query 1 tells you which. Paste the error back and it can be fixed in one pass.
   ============================================================================ */

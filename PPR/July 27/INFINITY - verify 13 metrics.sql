-- Verify the dashboard against Infinity, one centre at a time.
--
-- Computes all 13 metrics directly from the source tables using the same rules the
-- pipeline uses, so the output can be read straight against the Launch to Date column.
--
-- Set the two values in `params` and run. `centre` must match `atc` exactly:
--
--     select distinct atc from bai_list_of_orders where atc like '%Anderson%';
--
-- `asof` is the pipeline's as-of date, which is max(order_request__created_date) across
-- ALL centres, not just this one. Read it off analysis/run_meta.json or the dashboard,
-- do not guess it from this centre's rows.
--
-- These figures are Launch to Date. To check a period column instead, add a date filter
-- on that metric's OWN event date, listed in the `dated on` column of the output.
--
-- Written for Trino. On Redshift: date_diff('day', a, b) becomes datediff(day, a, b),
-- and approx_percentile(x, 0.5) becomes percentile_cont(0.5) within group (order by x).
-- Note that approx_percentile does not interpolate, so on an even number of rows it can
-- differ from the pipeline's median by up to half a day. percentile_cont matches exactly.
--
-- Metric 3 is not here. It needs the snapshot history and a window function; it is the
-- second query in this file.

WITH params AS (
    SELECT 'University Of Texas MD Anderson Cancer Center' AS centre,
           DATE '2026-07-31'                              AS asof
),

-- tumour procurement rows per order; tpf_count > 0 is `has_tumor`
tpf AS (
    SELECT til_order_name, count(*) AS tpf_count
    FROM bai_tumor_documentation
    GROUP BY til_order_name
),

o AS (
    SELECT l.order_request__til_order_name       AS order_name,
           l.iovance_patient_id                  AS patient_id,
           l.order_request__created_date         AS enrolled,
           l.tumor_tissue_pick_up_date           AS pickup,
           l.final_product_delivery_date         AS fp_delivered,
           l.oos_status,
           l.fp_status,
           l.til_order_cancellation_reason       AS reason,
           coalesce(t.tpf_count, 0)              AS tpf_count,
           i.infusion_date                       AS infused_on,
           i.lifileucel_infused_                 AS infused_flag,
           p.asof
    FROM bai_list_of_orders l
    CROSS JOIN params p
    LEFT JOIN tpf t ON t.til_order_name = l.order_request__til_order_name
    LEFT JOIN bai_infusion i ON i.til_order_name = l.order_request__til_order_name
    WHERE l.atc = p.centre
),

-- manufacturing actually started. The five SM states are the courier leg BEFORE
-- manufacturing and are deliberately excluded; including them inflates the metric 9
-- denominator and understates the rate.
flags AS (
    SELECT o.*,
           fp_status IN ('MFG Start', 'MFG End', 'REP Initiation', 'REP Scale Out',
                         'Released for Shipment by QA', 'Shipment Ready',
                         'Courier Picked-Up FP', 'Courier Delivered FP', 'FP CAH')
               AS mfg_started,
           reason IN ('Patient health progressed', 'Decline in Performance Status',
                      'Disease Progression', 'Brain Mets', 'Patient death',
                      'Transition to Hospice')
               AS health_reason,
           -- metric 9 adds Patient Choice. NED/MRD stays out: the patient responded,
           -- so counting it would report a good outcome as a failure.
           reason IN ('Patient health progressed', 'Decline in Performance Status',
                      'Disease Progression', 'Brain Mets', 'Patient death',
                      'Transition to Hospice', 'Patient Choice')
               AS patient_related
    FROM o
),

-- distinct patients with two or more different pickup dates
resect AS (
    SELECT count(*) AS n FROM (
        SELECT patient_id
        FROM flags
        WHERE pickup IS NOT NULL
        GROUP BY patient_id
        HAVING count(DISTINCT pickup) >= 2
    ) x
),

prog AS (
    SELECT count(DISTINCT CASE WHEN mfg_started THEN patient_id END)          AS denom,
           count(DISTINCT CASE WHEN mfg_started AND patient_related
                               THEN patient_id END)                          AS numer
    FROM flags
)

SELECT  1 AS m, 'Enrollments in IovanceCares'   AS metric, 'enrollment date' AS dated_on,
        cast(count(DISTINCT order_name) AS varchar) AS value FROM flags
UNION ALL
SELECT  2, 'Patients Enrolled in IovanceCares', 'enrollment date',
        cast(count(DISTINCT patient_id) AS varchar) FROM flags
UNION ALL
SELECT  4, 'Completed TTPs', 'TTP pickup date',
        cast(count(*) AS varchar) FROM flags
        WHERE pickup IS NOT NULL AND pickup <= asof
UNION ALL
SELECT  5, 'Scheduled TTPs', 'TTP pickup date',
        cast(count(*) AS varchar) FROM flags
        WHERE pickup IS NOT NULL AND pickup > asof
UNION ALL
SELECT  6, '2nd Resections (Scheduled or Completed)', 'TTP pickup date',
        cast(n AS varchar) FROM resect
UNION ALL
SELECT  7, 'Patient Related Drop-outs following TTP', 'TTP pickup date',
        cast(count(DISTINCT patient_id) AS varchar) FROM flags
        WHERE tpf_count > 0 AND health_reason
UNION ALL
SELECT  8, 'OOS Products', 'final product delivery date',
        cast(count(*) AS varchar) FROM flags
        WHERE oos_status = 'Confirmed OOS'
UNION ALL
SELECT  9, 'Patient Progression Rate', 'TTP pickup date',
        CASE WHEN denom = 0 THEN ''
             ELSE cast(round(100.0 * numer / denom, 1) AS varchar) || '%' END
        FROM prog
UNION ALL
SELECT 10, 'AMTAGVI Infusions Performed', 'infusion date',
        cast(count(*) AS varchar) FROM flags
        WHERE infused_on IS NOT NULL AND infused_flag = 'Yes'
UNION ALL
SELECT 11, 'Median Time From Enrollment Date to TTP', 'TTP pickup date',
        cast(round(approx_percentile(date_diff('day', enrolled, pickup), 0.5), 1) AS varchar)
        FROM flags WHERE pickup IS NOT NULL AND enrolled IS NOT NULL
UNION ALL
SELECT 12, 'Median Time From TTP to AMTAGVI Infusion', 'infusion date',
        cast(round(approx_percentile(date_diff('day', pickup, infused_on), 0.5), 1) AS varchar)
        FROM flags WHERE infused_on IS NOT NULL AND pickup IS NOT NULL
UNION ALL
SELECT 13, 'Median Time From Final Product Delivery to Infusion', 'infusion date',
        cast(round(approx_percentile(date_diff('day', fp_delivered, infused_on), 0.5), 1) AS varchar)
        FROM flags WHERE infused_on IS NOT NULL AND fp_delivered IS NOT NULL
ORDER BY m;


-- ---------------------------------------------------------------------------------------
-- Metric 3, separately, because it walks the snapshot history rather than the order table.
--
-- Sort each order's snapshots by record_number. When the booked pickup date moves or is
-- cleared, measure from that snapshot's load date back to the date that HAD been booked.
-- Zero to seven days of notice counts: the slot could not realistically be refilled.
-- The event is dated on the LOST slot, not on the day the change was entered.
--
-- Returns one row per event. The dashboard counts events, not distinct orders, so the row
-- count is the figure to compare. Change to count(distinct order_name) to see the other.

WITH params AS (
    SELECT 'University Of Texas MD Anderson Cancer Center' AS centre
),
snaps AS (
    SELECT h.atc,
           h.order_request__til_order_name AS order_name,
           h.record_number,
           -- load_datetime is a string like 20241007T024217; the date is the first 8 chars
           date_parse(substr(replace(cast(h.load_datetime AS varchar), '-', ''), 1, 8),
                      '%Y%m%d')                             AS snapshot_on,
           h.tumor_tissue_pick_up_date                       AS pickup,
           lag(h.tumor_tissue_pick_up_date) OVER (
               PARTITION BY h.order_request__til_order_name
               ORDER BY h.record_number)                     AS prev_pickup
    FROM bai_list_of_orders_hist h
    CROSS JOIN params p
    WHERE h.atc = p.centre
)
SELECT order_name,
       prev_pickup                                     AS lost_slot_date,
       snapshot_on                                     AS change_seen_on,
       date_diff('day', snapshot_on, prev_pickup)      AS days_notice,
       CASE WHEN pickup IS NULL THEN 'cancelled' ELSE 'rescheduled' END AS kind
FROM snaps
WHERE prev_pickup IS NOT NULL
  AND (pickup IS NULL OR pickup <> prev_pickup)
  AND date_diff('day', snapshot_on, prev_pickup) BETWEEN 0 AND 7
ORDER BY lost_slot_date;

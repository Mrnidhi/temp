-- Cancellation-source audit: LTD_Cancellations (Redshift) vs bai_list_of_orders_hist (AWS).
--
-- Infinity Explorer accepts one statement at a time. Do NOT run this file as a batch:
-- choose the required server stream, then copy only one numbered SELECT into Explorer.
--
-- Purpose:
--   1. Prove each source's coverage window independently.
--   2. Count the 65-day LTD-only period: 2024-08-03 through 2024-10-06.
--   3. Export the raw rows needed for an event-level comparison outside Infinity.
--
-- The two source extracts must be compared locally. This file intentionally contains
-- no cross-server join, CTE, UNION, or window function.


-- =====================================================================================
-- REDSHIFT STREAM
-- =====================================================================================

-- R1. LTD_Cancellations coverage and the 65-day count.
-- This is one statement. A cancellation is counted as short notice only when
-- TTP_DATE - recorded date is 0 to 7 days.
select min(cast(SNAPSHOT_DATE_TIME_CURR as date)) as first_recorded,
       max(cast(SNAPSHOT_DATE_TIME_CURR as date)) as last_recorded,
       min(TTP_DATE)                              as first_lost_slot,
       max(TTP_DATE)                              as last_lost_slot,
       count(*)                                   as cancellation_rows,
       count(distinct ORDER_ID)                   as cancellation_orders,
       sum(case
             when cast(SNAPSHOT_DATE_TIME_CURR as date) >= date '2024-08-03'
              and cast(SNAPSHOT_DATE_TIME_CURR as date) <  date '2024-10-07'
             then 1 else 0
           end)                                   as rows_in_65_day_window,
       sum(case
             when date_diff(TTP_DATE, cast(SNAPSHOT_DATE_TIME_CURR as date), day)
                  between 0 and 7
             then 1 else 0
           end)                                   as short_notice_rows
from LTD_Cancellations;


-- R2. Distinct LTD orders recorded in the 65-day window.
-- Run this separately if R1 confirms the window has rows.
select count(distinct ORDER_ID) as orders_in_65_day_window
from LTD_Cancellations
where cast(SNAPSHOT_DATE_TIME_CURR as date) >= date '2024-08-03'
  and cast(SNAPSHOT_DATE_TIME_CURR as date) <  date '2024-10-07';


-- R3. Raw LTD cancellation export for local event-level comparison.
-- Export this result as redshift_data.csv. Do not filter to 0-7 days: the local
-- audit must account for every row and every exclusion.
select ORDER_ID                              as order_id,
       TTP_DATE                              as lost_slot_date,
       SNAPSHOT_DATE_TIME_CURR               as recorded_at,
       date_diff(TTP_DATE,
                 cast(SNAPSHOT_DATE_TIME_CURR as date),
                 day)                        as days_notice,
       CANCELLATION_REASON                   as cancellation_reason
from LTD_Cancellations
order by ORDER_ID, SNAPSHOT_DATE_TIME_CURR, TTP_DATE;


-- =====================================================================================
-- AWS / S3 STREAM
-- =====================================================================================

-- A1. bai_list_of_orders_hist snapshot coverage.
-- The history table records snapshots, not explicit cancellation events.
select min(load_datetime)                             as first_load,
       max(load_datetime)                             as last_load,
       count(*)                                       as snapshot_rows,
       count(distinct order_request__til_order_name)  as orders
from bai_list_of_orders_hist
where order_request__til_order_name is not null;


-- A2. History rows that could exist in the 65-day window.
-- A result of zero is expected if the first history load is 2024-10-07.
select count(*)                                      as snapshot_rows_in_65_day_window,
       count(distinct order_request__til_order_name) as orders_in_65_day_window
from bai_list_of_orders_hist
where order_request__til_order_name is not null
  and substring(load_datetime, 1, 8) >= '20240803'
  and substring(load_datetime, 1, 8) <  '20241007';


-- A3. Raw snapshot export for local non-null-to-null / date-change detection.
-- Export this result as s3_data.csv. The full history is required: filtering this
-- extract by the 65-day dates would hide the prior snapshot needed to detect a change.
select order_request__til_order_name as order_id,
       record_number,
       load_datetime,
       tumor_tissue_pick_up_date     as ttp_date
from bai_list_of_orders_hist
where order_request__til_order_name is not null
order by order_request__til_order_name, cast(record_number as integer);

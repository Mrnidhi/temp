-- Cancellation window inside bai_list_of_orders_hist.
-- Two different dates matter here: load_datetime is when the cancellation was
-- recorded, tumor_tissue_pick_up_date is the slot it cleared. Metric 3 dates
-- events on the slot, so both are below.
-- Run one query at a time, the explorer takes a single statement.

-- Q1. The window
select min(load_datetime)                             as first_recorded,
       max(load_datetime)                             as last_recorded,
       min(tumor_tissue_pick_up_date)                 as first_lost_slot,
       max(tumor_tissue_pick_up_date)                 as last_lost_slot,
       count(*)                                       as rows_with_reason,
       count(distinct order_request__til_order_name)  as orders
from bai_list_of_orders_hist
where til_order_cancellation_reason is not null;


-- Q2. Where it thins out, by month recorded
select substr(load_datetime, 1, 6)                    as year_month,
       count(*)                                       as rows_with_reason,
       count(distinct order_request__til_order_name)  as orders
from bai_list_of_orders_hist
where til_order_cancellation_reason is not null
group by 1
order by 1;


-- Q3. The whole table for comparison, so the cancellation window can be read
-- against the snapshot window it sits inside
select min(load_datetime)                             as first_load,
       max(load_datetime)                             as last_load,
       count(*)                                       as total_rows,
       count(distinct order_request__til_order_name)  as orders
from bai_list_of_orders_hist;

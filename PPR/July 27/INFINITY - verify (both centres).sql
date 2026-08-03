-- Ready-to-run copy of git/PPR/July 27/INFINITY - verify 13 metrics.sql with the two
-- centres filled in. LOCAL FILE ONLY - real centre names, so it never goes under git/.
--
-- As-of is 2026-07-31: that value already reproduced the dashboard's Completed 88 and
-- Scheduled 6 for MD Anderson, so it matches the current extract. If you re-pull the data,
-- re-read it from analysis/run_meta.json.
--
-- Record every result in VALIDATION LOG - dashboard.md with the date.


-- Q1. Metrics 1, 2, 4, 5, 8 for both centres in one pass.
select atc,
       count(distinct order_request__til_order_name)                   as m1_enrollments,
       count(distinct iovance_patient_id)                              as m2_patients,
       sum(case when tumor_tissue_pick_up_date is not null
                 and tumor_tissue_pick_up_date <= date '2026-07-31'
                then 1 else 0 end)                                     as m4_completed_ttps,
       sum(case when tumor_tissue_pick_up_date >  date '2026-07-31'
                then 1 else 0 end)                                     as m5_scheduled_ttps,
       sum(case when oos_status = 'Confirmed OOS' then 1 else 0 end)   as m8_oos_products
from bai_list_of_orders
where atc in ('University Of Texas MD Anderson Cancer Center',
              'University Of Oklahoma Medical Center')
group by atc;

-- Expect against the dashboard: MD Anderson 139 / 138 / 88 / 6 / 15, Oklahoma 11 / 10 / 8 / 0 / 2.


-- Q2. Metric 6, 2nd Resections. Count the rows per centre.
select atc,
       iovance_patient_id,
       count(distinct tumor_tissue_pick_up_date) as distinct_pickups
from bai_list_of_orders
where atc in ('University Of Texas MD Anderson Cancer Center',
              'University Of Oklahoma Medical Center')
  and tumor_tissue_pick_up_date is not null
group by atc, iovance_patient_id
having count(distinct tumor_tissue_pick_up_date) >= 2;

-- Expect: zero MD Anderson rows (blank cell), one Oklahoma row.


-- Q3. Metric 7, health drop-outs following TTP.
select atc, count(distinct iovance_patient_id) as m7_dropouts
from bai_list_of_orders
where atc in ('University Of Texas MD Anderson Cancer Center',
              'University Of Oklahoma Medical Center')
  and til_order_cancellation_reason in (
        'Patient health progressed', 'Decline in Performance Status',
        'Disease Progression', 'Brain Mets', 'Patient death', 'Transition to Hospice')
  and order_request__til_order_name in (select til_order_name from bai_tumor_documentation)
group by atc;

-- Expect: MD Anderson 3 (already matched once), Oklahoma no row, meaning 0.


-- Q4. Metric 9, progression rate. Divide drops by starts yourself.
select atc,
       count(distinct case when fp_status in (
               'MFG Start', 'MFG End', 'REP Initiation', 'REP Scale Out',
               'Released for Shipment by QA', 'Shipment Ready',
               'Courier Picked-Up FP', 'Courier Delivered FP', 'FP CAH')
           then iovance_patient_id end)                                as mfg_starts,
       count(distinct case when fp_status in (
               'MFG Start', 'MFG End', 'REP Initiation', 'REP Scale Out',
               'Released for Shipment by QA', 'Shipment Ready',
               'Courier Picked-Up FP', 'Courier Delivered FP', 'FP CAH')
             and til_order_cancellation_reason in (
               'Patient health progressed', 'Decline in Performance Status',
               'Disease Progression', 'Brain Mets', 'Patient death',
               'Transition to Hospice', 'Patient Choice')
           then iovance_patient_id end)                                as drops_after_mfg
from bai_list_of_orders
where atc in ('University Of Texas MD Anderson Cancer Center',
              'University Of Oklahoma Medical Center')
group by atc;

-- Expect: MD Anderson 88 and 4 (4.5%, already matched once), Oklahoma drops 0 (0.0%).


-- Q5. Metric 10, infusions. One centre per run, the explorer choked on bigger subqueries.
select count(*) as m10_infusions
from bai_infusion
where lifileucel_infused_ = 'Yes'
  and infusion_date is not null
  and til_order_name in (
        select order_request__til_order_name from bai_list_of_orders
        where atc = 'University Of Texas MD Anderson Cancer Center');

-- Expect 60 (already matched once). Then swap the centre name:

select count(*) as m10_infusions
from bai_infusion
where lifileucel_infused_ = 'Yes'
  and infusion_date is not null
  and til_order_name in (
        select order_request__til_order_name from bai_list_of_orders
        where atc = 'University Of Oklahoma Medical Center');

-- Expect 4.


-- Q6 + Q7. The three medians. Download both, match on order name in Excel, MEDIAN each
-- day column ignoring blanks. Excel's MEDIAN matches the pipeline exactly.
--   m11 = pickup - created        expect MD Anderson 34.5, Oklahoma 23.0
--   m12 = infusion - pickup       expect MD Anderson 47.0, Oklahoma 65.5
--   m13 = infusion - fp delivery  expect MD Anderson 10.0, Oklahoma 13.5
select order_request__til_order_name,
       order_request__created_date,
       tumor_tissue_pick_up_date,
       final_product_delivery_date
from bai_list_of_orders
where atc in ('University Of Texas MD Anderson Cancer Center',
              'University Of Oklahoma Medical Center');

select til_order_name, infusion_date, lifileucel_infused_
from bai_infusion
where til_order_name in (
        select order_request__til_order_name from bai_list_of_orders
        where atc in ('University Of Texas MD Anderson Cancer Center',
                      'University Of Oklahoma Medical Center'));


-- Metric 3 per centre, from the LTD tables. Both directions counted, matching the pipeline.
select o.ATC,
       count(*)                   as reschedules_within_7
from LTD_Reschedules r
join file_IovanceCares_Orders o
  on o.Order_Request__TIL_Order_Name = r.ORDER_ID
where date_diff(r.TTP_DATE_PREV, cast(r.SNAPSHOT_DATE_TIME_CURR as date), day)
      between 0 and 7
  and o.ATC in ('University Of Texas MD Anderson Cancer Center',
                'University Of Oklahoma Medical Center')
group by o.ATC;

select o.ATC,
       count(*)                   as cancellations_within_7
from LTD_Cancellations c
join file_IovanceCares_Orders o
  on o.Order_Request__TIL_Order_Name = c.ORDER_ID
where date_diff(c.TTP_DATE, cast(c.SNAPSHOT_DATE_TIME_CURR as date), day)
      between 0 and 7
  and o.ATC in ('University Of Texas MD Anderson Cancer Center',
                'University Of Oklahoma Medical Center')
group by o.ATC;

-- The two counts per centre ADD. Expect MD Anderson 27 total, Oklahoma 4 total.
-- If the join is rejected, run each without the join and match ORDER_IDs to centres offline.

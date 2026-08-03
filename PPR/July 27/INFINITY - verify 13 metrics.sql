-- Verify the dashboard against Infinity, one centre at a time.
--
-- Replace <CENTRE> everywhere below with the exact `atc` value. Find it with:
--     select distinct atc from bai_list_of_orders where atc like '%<part of name>%';
--
-- Replace <ASOF> with the pipeline's as-of date, which is max(order_request__created_date)
-- across ALL centres, not just this one. Read it from analysis/run_meta.json. Do not infer it
-- from a single centre's rows. It is the only value here that moves a number if it is wrong,
-- and it moves Completed and Scheduled TTPs in opposite directions.
--
-- Explorer dialect: plain SELECT only. CTEs and window functions both fail there.
-- All figures are Launch to Date. For a period column, add a date filter on that metric's own
-- event date, noted against each query.
--
-- Record every result in the validation log rather than here. This file holds the method;
-- the numbers are internal and stay off a public repo.


-- =======================================================================================
-- Q1. Five metrics in one pass: 1, 2, 4, 5, 8.
-- Runs for several centres at once, so use it to check a whole set in one go.
-- Dated on: enrollment date (1, 2), pickup date (4, 5), FP delivery date (8).
-- =======================================================================================
select atc,
       count(distinct order_request__til_order_name)                   as m1_enrollments,
       count(distinct iovance_patient_id)                              as m2_patients,
       sum(case when tumor_tissue_pick_up_date is not null
                 and tumor_tissue_pick_up_date <= date '<ASOF>'
                then 1 else 0 end)                                     as m4_completed_ttps,
       sum(case when tumor_tissue_pick_up_date >  date '<ASOF>'
                then 1 else 0 end)                                     as m5_scheduled_ttps,
       sum(case when oos_status = 'Confirmed OOS' then 1 else 0 end)   as m8_oos_products
from bai_list_of_orders
where atc in ('<CENTRE>', '<CENTRE 2>')
group by atc;


-- =======================================================================================
-- Q2. Metric 6, 2nd Resections. Count the ROWS returned, per centre.
-- Distinct patients holding two or more different pickup dates.
-- =======================================================================================
select atc,
       iovance_patient_id,
       count(distinct tumor_tissue_pick_up_date) as distinct_pickups
from bai_list_of_orders
where atc in ('<CENTRE>', '<CENTRE 2>')
  and tumor_tissue_pick_up_date is not null
group by atc, iovance_patient_id
having count(distinct tumor_tissue_pick_up_date) >= 2;


-- =======================================================================================
-- Q3. Metric 7, drop-outs following TTP due to patient health.
-- Distinct patients, and only orders that actually had a tumour procurement.
-- =======================================================================================
select atc, count(distinct iovance_patient_id) as m7_dropouts
from bai_list_of_orders
where atc in ('<CENTRE>', '<CENTRE 2>')
  and til_order_cancellation_reason in (
        'Patient health progressed', 'Decline in Performance Status',
        'Disease Progression', 'Brain Mets', 'Patient death', 'Transition to Hospice')
  and order_request__til_order_name in (select til_order_name from bai_tumor_documentation)
group by atc;


-- =======================================================================================
-- Q4. Metric 9, Patient Progression Rate. Divide drops by starts yourself.
-- Patient grain, not order grain. The five starting-material states are the courier leg
-- BEFORE manufacturing and are deliberately excluded from the denominator.
-- Patient Choice is in the numerator; NED/MRD is not, because the patient responded.
-- =======================================================================================
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
where atc in ('<CENTRE>', '<CENTRE 2>')
group by atc;


-- =======================================================================================
-- Q5. Metric 10, AMTAGVI Infusions Performed. Dated on infusion date.
-- =======================================================================================
select count(*) as m10_infusions
from bai_infusion
where lifileucel_infused_ = 'Yes'
  and infusion_date is not null
  and til_order_name in (
        select order_request__til_order_name from bai_list_of_orders
        where atc = '<CENTRE>');


-- =======================================================================================
-- Q6 and Q7. Metrics 11, 12, 13 — the medians.
--
-- The explorer has no percentile function, so download both and take the median of each day
-- column in Excel. Excel's MEDIAN matches the pipeline exactly: both average the two middle
-- values on an even count.
--
--   m11 = median of (tumor_tissue_pick_up_date - order_request__created_date)
--   m12 = median of (infusion_date - tumor_tissue_pick_up_date)
--   m13 = median of (infusion_date - final_product_delivery_date)
--
-- Match Q7 onto Q6 by order name. Ignore blanks; do not substitute anything for them.
-- =======================================================================================
select order_request__til_order_name,
       order_request__created_date,
       tumor_tissue_pick_up_date,
       final_product_delivery_date
from bai_list_of_orders
where atc = '<CENTRE>';

select til_order_name, infusion_date, lifileucel_infused_
from bai_infusion
where til_order_name in (
        select order_request__til_order_name from bai_list_of_orders
        where atc = '<CENTRE>');


-- =======================================================================================
-- Metric 3 cannot be verified here. The 7-day rule compares each snapshot against the one
-- before it, which needs a window function the explorer will not run. It is checked instead
-- against Infinity's own LTD reschedule and cancellation tables — see the uploaded-files
-- layer checks file.
-- =======================================================================================

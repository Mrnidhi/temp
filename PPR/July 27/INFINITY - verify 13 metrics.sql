-- Verify the dashboard against Infinity, one centre at a time.
--
-- Seven standalone queries. Run them one at a time and read the result against the
-- Launch to Date column. No CTEs, no unions, no window functions.
--
-- Replace the centre name in every query. It must match `atc` exactly:
--     select distinct atc from bai_list_of_orders where atc like '%Anderson%';
--
-- The as-of date below is the pipeline's as-of, which is max(order_request__created_date)
-- across ALL centres, not just this one. Read it off analysis/run_meta.json. Getting it
-- wrong moves Completed and Scheduled TTPs and nothing else.
--
-- All figures are Launch to Date. For a period column, add a date filter on that metric's
-- own event date, noted against each query.


-- =======================================================================================
-- Q1. Five metrics in one pass: 1, 2, 4, 5, 8
-- Dated on: enrollment date (1, 2), pickup date (4, 5), FP delivery date (8)
-- =======================================================================================
select
    count(distinct order_request__til_order_name)                       as m1_enrollments,
    count(distinct iovance_patient_id)                                  as m2_patients,
    sum(case when tumor_tissue_pick_up_date is not null
              and tumor_tissue_pick_up_date <= date '2026-07-31'
             then 1 else 0 end)                                         as m4_completed_ttps,
    sum(case when tumor_tissue_pick_up_date >  date '2026-07-31'
             then 1 else 0 end)                                         as m5_scheduled_ttps,
    sum(case when oos_status = 'Confirmed OOS' then 1 else 0 end)       as m8_oos_products
from bai_list_of_orders
where atc = 'University Of Texas MD Anderson Cancer Center';


-- =======================================================================================
-- Q2. Metric 6, 2nd Resections. Count the ROWS this returns.
-- Distinct patients with two or more different pickup dates.
-- =======================================================================================
select iovance_patient_id,
       count(distinct tumor_tissue_pick_up_date) as distinct_pickups
from bai_list_of_orders
where atc = 'University Of Texas MD Anderson Cancer Center'
  and tumor_tissue_pick_up_date is not null
group by iovance_patient_id
having count(distinct tumor_tissue_pick_up_date) >= 2;


-- =======================================================================================
-- Q3. Metric 7, patient related drop-outs following TTP due to patient health.
-- Distinct patients, and only orders that actually had a tumour procurement.
-- =======================================================================================
select count(distinct iovance_patient_id) as m7_dropouts
from bai_list_of_orders
where atc = 'University Of Texas MD Anderson Cancer Center'
  and til_order_cancellation_reason in (
        'Patient health progressed', 'Decline in Performance Status',
        'Disease Progression', 'Brain Mets', 'Patient death', 'Transition to Hospice')
  and order_request__til_order_name in (select til_order_name from bai_tumor_documentation);


-- =======================================================================================
-- Q4. Metric 9, Patient Progression Rate. Divide drops by starts yourself.
-- Patient grain, not order grain. The five SM states are the courier leg BEFORE
-- manufacturing and are deliberately excluded from the denominator.
-- Patient Choice is in the numerator; NED/MRD is not, because the patient responded.
-- =======================================================================================
select
    count(distinct case when fp_status in (
            'MFG Start', 'MFG End', 'REP Initiation', 'REP Scale Out',
            'Released for Shipment by QA', 'Shipment Ready',
            'Courier Picked-Up FP', 'Courier Delivered FP', 'FP CAH')
        then iovance_patient_id end)                                    as mfg_starts,
    count(distinct case when fp_status in (
            'MFG Start', 'MFG End', 'REP Initiation', 'REP Scale Out',
            'Released for Shipment by QA', 'Shipment Ready',
            'Courier Picked-Up FP', 'Courier Delivered FP', 'FP CAH')
          and til_order_cancellation_reason in (
            'Patient health progressed', 'Decline in Performance Status',
            'Disease Progression', 'Brain Mets', 'Patient death',
            'Transition to Hospice', 'Patient Choice')
        then iovance_patient_id end)                                    as drops_after_mfg
from bai_list_of_orders
where atc = 'University Of Texas MD Anderson Cancer Center';


-- =======================================================================================
-- Q5. Metric 10, AMTAGVI Infusions Performed. Dated on infusion date.
-- =======================================================================================
select count(*) as m10_infusions
from bai_infusion
where lifileucel_infused_ = 'Yes'
  and infusion_date is not null
  and til_order_name in (
        select order_request__til_order_name from bai_list_of_orders
        where atc = 'University Of Texas MD Anderson Cancer Center');


-- =======================================================================================
-- Q6. Metrics 11, 12, 13. The medians.
-- Download this and take the median of each day column in Excel, since the explorer has
-- no percentile function. Excel's MEDIAN matches the pipeline exactly; both average the
-- two middle values on an even count.
--
--   m11 = median of days_enroll_to_ttp      ignore blanks
--   m12 = median of days_ttp_to_infusion    ignore blanks
--   m13 = median of days_delivery_to_infusion
--
-- Infusion dates are in bai_infusion, so download Q7 as well and match on order name.
-- =======================================================================================
select order_request__til_order_name,
       order_request__created_date,
       tumor_tissue_pick_up_date,
       final_product_delivery_date
from bai_list_of_orders
where atc = 'University Of Texas MD Anderson Cancer Center';


-- =======================================================================================
-- Q7. Infusion dates for the same centre, to pair with Q6 for metrics 12 and 13.
-- =======================================================================================
select til_order_name, infusion_date, lifileucel_infused_
from bai_infusion
where til_order_name in (
        select order_request__til_order_name from bai_list_of_orders
        where atc = 'University Of Texas MD Anderson Cancer Center');


-- =======================================================================================
-- Metric 3 is not verifiable here. The 7-day rule needs consecutive snapshots compared
-- against each other, which the explorer cannot express without a window function.
-- Compare it instead against the cancellation and reschedule view already in Infinity,
-- once edit access lands and its calculated-field logic can be read.
-- =======================================================================================

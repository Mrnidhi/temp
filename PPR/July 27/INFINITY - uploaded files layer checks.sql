-- Infinity uploaded-files layer: the queries still open.
--
-- Results live in the local notes (table results + validation log), NOT in this file.
-- Check there before running anything; most tables in this layer have already been opened
-- and recorded. Do not paste counts or centre names back into this file.
--
-- Settled, do not repeat:
--   LTD_Reschedules / LTD_Cancellations   exist, current to the present, drive metric 3
--   RESCHEDULED_CATEGORY                  two values: Postponed, Moved Up
--   hist_Manufacturing_Slots              history stale; file_Manufacturing_Slots is current
--                                         and already carries a LOST_CAPACITY flag
--   file_Patient_Characteristics          referral date, referring physician, community flag
--   file_QBR_Metrics_FTE                  corporate OKR tracking, unrelated to the P&PR
--   file_Pre_Reserved_Slots               empty
--   ATC mapping files (all variants)      staffing/territory only, no onboarding date, so
--                                         the New tier has no source anywhere in this layer
--
-- Explorer dialect. Plain SELECT only; CTEs and window functions both fail there.
--
-- TYPE NOTE, this cost a failed run: TTP dates are DATE and snapshot stamps are TIMESTAMP,
-- and DATE_DIFF refuses to mix them. Always cast the snapshot:
--     date_diff(TTP_DATE_PREV, cast(SNAPSHOT_DATE_TIME_CURR as date), day)


-- =======================================================================================
-- Q1. Per-centre metric 3 from the LTD tables.
--
-- Neither LTD table carries a centre; ORDER_ID is the only key, so join the orders file.
-- Run for the centre being validated and read the two counts against the dashboard's
-- launch-to-date cancellation cell (their sum, when both directions count).
-- =======================================================================================
select o.ATC,
       count(*)                   as reschedules_within_7,
       count(distinct r.ORDER_ID) as orders
from LTD_Reschedules r
join file_IovanceCares_Orders o
  on o.Order_Request__TIL_Order_Name = r.ORDER_ID
where date_diff(r.TTP_DATE_PREV, cast(r.SNAPSHOT_DATE_TIME_CURR as date), day)
      between 0 and 7
group by o.ATC
order by reschedules_within_7 desc;

select o.ATC,
       count(*)                   as cancellations_within_7,
       count(distinct c.ORDER_ID) as orders
from LTD_Cancellations c
join file_IovanceCares_Orders o
  on o.Order_Request__TIL_Order_Name = c.ORDER_ID
where date_diff(c.TTP_DATE, cast(c.SNAPSHOT_DATE_TIME_CURR as date), day)
      between 0 and 7
group by o.ATC
order by cancellations_within_7 desc;


-- =======================================================================================
-- Q2. The name-mapping list, for the centres that match nothing in the Veeva mapping.
-- Download and diff against the analysis table's centre list offline. The list contains a
-- literal "TBD" value; treat it as unmapped, not as a centre.
-- =======================================================================================
select distinct F__ATC_NAME__IOVANCECARES_ as atc_name
from file_IC_ATC_Name_to_Veeva_Name_Mapping
order by atc_name;


-- =======================================================================================
-- Q3. Current slot coverage, before building anything on lost capacity.
-- The flag is already on the row; this just establishes the window it covers.
-- =======================================================================================
select min(SLOT_DATE) as first_slot,
       max(SLOT_DATE) as last_slot,
       sum(case when LOST_CAPACITY = 1 then 1 else 0 end) as lost_capacity_slots,
       count(*)       as all_slots
from file_Manufacturing_Slots;

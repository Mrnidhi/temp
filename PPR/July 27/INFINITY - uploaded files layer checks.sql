-- Checks against the uploaded-files layer (the file_* / hist_* tables the Infinity
-- dashboards are built on), to see whether the reschedule logic can be reproduced there
-- and whether its history runs further than the bai_ copies.
--
-- Run these in the chart builder's Advanced Editor, not the bai_ explorer. The saved
-- LTD Reschedules view runs there with this dialect: DATE_DIFF(a, b, DAY),
-- CAST(x AS DATE), CURRENT_DATE(), backticked table names.
--
-- One query at a time, in order. Each has a note on how to read the result.
-- Column names on the file_ tables are read off the saved view's SQL; the hist orders
-- table has not been seen yet, so Q2 settles its name and columns before Q6 runs.


-- ---------------------------------------------------------------------------------------
-- Q1. Does the precomputed reschedules table exist in this layer?
-- The saved view reads FROM LTD_Reschedules. If this errors with unknown table, use the
-- catalog search box for "LTD" and "Reschedule" instead of guessing further names.
-- ---------------------------------------------------------------------------------------
select * from LTD_Reschedules limit 5;


-- ---------------------------------------------------------------------------------------
-- Q2. Is there an orders history in this layer?
-- Name is a guess. If it errors, search the catalog for "hist" and note every hit.
-- From the result, note the exact upload-stamp column and the TTP date column for Q6.
-- ---------------------------------------------------------------------------------------
select * from hist_IovanceCares_Orders limit 5;


-- ---------------------------------------------------------------------------------------
-- Q3. How far does the slot history run, and what does `period` hold?
-- If max upload date is recent, this layer is current and the bai_ September cutoff is a
-- copy problem, not a source problem. Also confirms the HOURLY filter the view applies.
-- ---------------------------------------------------------------------------------------
select period,
       min(subscription_upload_date) as first_load,
       max(subscription_upload_date) as last_load,
       count(*)                      as row_count
from hist_Manufacturing_Slots
group by period;


-- ---------------------------------------------------------------------------------------
-- Q4. Same coverage question for the orders history found in Q2.
-- Replace the table and column names with what Q2 returned.
-- ---------------------------------------------------------------------------------------
select min(subscription_upload_date) as first_load,
       max(subscription_upload_date) as last_load,
       count(*)                      as row_count
from `<hist_orders_table>`;


-- ---------------------------------------------------------------------------------------
-- Q5. The official centre-name crosswalk. Small file, pull it whole and download it.
-- This replaces the fuzzy name matching in the pipeline and should account for the six
-- centres that currently come through with no region or segment.
-- ---------------------------------------------------------------------------------------
select * from file_IC_ATC_Name_to_Veeva_Name_Mapping;


-- ---------------------------------------------------------------------------------------
-- Q6. Reproduce the day-notice rule directly on the orders history.
-- Only runs if the editor accepts window functions; the saved view itself reads a
-- precomputed table, so this is untested there. Fix table and column names from Q2.
-- Read: reschedules should match the row count on the LTD Reschedules view footer,
-- cancels the LTD Cancellations footer, and within_7 is our metric 3 population.
-- ---------------------------------------------------------------------------------------
with h as (
  select Order_Request__TIL_Order_Name                                  as ord,
         cast(subscription_upload_date as date)                         as snap,
         cast(Tumor_Tissue_Pick_Up_Date as date)                        as ttp,
         lag(cast(Tumor_Tissue_Pick_Up_Date as date)) over (
             partition by Order_Request__TIL_Order_Name
             order by subscription_upload_date)                         as prev_ttp
  from `<hist_orders_table>`
)
select count(*)                                                as all_changes,
       countif(ttp is null)                                    as cancels,
       countif(ttp is not null)                                as reschedules,
       countif(date_diff(prev_ttp, snap, day) between 0 and 7) as within_7
from h
where prev_ttp is not null
  and (ttp is null or ttp != prev_ttp);


-- ---------------------------------------------------------------------------------------
-- Q7. Roster and START data: looking for anything resembling an authorization or
-- onboarding date, which would give the New ATCs tier a real source.
-- ---------------------------------------------------------------------------------------
select * from file_ATC_Ops_Roster limit 20;

select * from file_ATC_Ops_START_Data limit 20;


-- ---------------------------------------------------------------------------------------
-- Q8. Slot fate, traced by hand for ONE event before any of it is coded.
-- Take one order and its previous snapshot date from the LTD Reschedules view, then:
--   a) the slot it held at that snapshot
--   b) who holds that slot now
-- Read: a current holder means Filled by that site; no holder and the slot date has
-- passed means Lost Capacity; no holder and the date is still ahead means At Risk.
-- ---------------------------------------------------------------------------------------
select Slot_Name, Slot_Date, Site__Account_Name, Booking_Status, Unavailable_Reason
from hist_Manufacturing_Slots
where TIL_Order_Name = '<order id>'
  and subscription_upload_date = '<previous snapshot date>';

select Slot_Name, Slot_Date, TIL_Order_Name, Site__Account_Name, Booking_Status
from file_Manufacturing_Slots
where Slot_Name = '<slot name from the query above>';

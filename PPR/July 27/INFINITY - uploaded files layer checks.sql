-- Infinity uploaded-files layer: the queries still unanswered.
--
-- Results for everything already run are in
--   PPR Automation/INFINITY - table results (do not re-query).md
-- Read that first. Do not re-run a table that already has a section there.
--
-- Settled, do not repeat:
--   LTD_Reschedules      exists, runs 02 Aug 2024 to 30 Jul 2026, 715 rows / 537 orders
--   LTD_Cancellations    exists, rows into late Jul 2026, carries CANCELLATION_REASON
--   RESCHEDULED_CATEGORY two values, Postponed 380 and Moved Up 335
--   hist_Manufacturing_Slots  exists, history stops 20 May 2025
--   hist_IovanceCares_Orders  does not exist under that name
--   file_ATC_Ops_Roster       five-person field team roster, no onboarding date
--   file_ATC_Ops_START_Data   37 rows, 26 centres, ends Apr 2025, too small to use
--   file_IC_ATC_Name_to_Veeva_Name_Mapping  exists, one centre to many Veeva accounts
--
-- Explorer dialect. Plain SELECT only; CTEs and window functions both failed there.
--
-- TYPE NOTE, this cost a failed run: TTP dates are DATE and snapshot stamps are TIMESTAMP,
-- and DATE_DIFF refuses to mix them. Always cast the snapshot:
--     date_diff(TTP_DATE_PREV, cast(SNAPSHOT_DATE_TIME_CURR as date), day)


-- =======================================================================================
-- Q1. The 7-day population, reschedules. Re-run of the query that failed on the type cast.
--
-- days_notice is the old TTP minus the snapshot the change was seen on, which is how the
-- saved chart view computes Days_from_Old_TTP.
-- Read: the rows where days_notice is 0 through 7 are metric 3's reschedule half.
-- Compare against the 83 events our pipeline reports. Expect theirs higher, since this feed
-- is hourly, starts two months earlier, and runs eleven months later.
-- =======================================================================================
select date_diff(TTP_DATE_PREV, cast(SNAPSHOT_DATE_TIME_CURR as date), day) as days_notice,
       count(*)                 as events,
       count(distinct ORDER_ID) as orders
from LTD_Reschedules
group by date_diff(TTP_DATE_PREV, cast(SNAPSHOT_DATE_TIME_CURR as date), day)
order by days_notice;


-- =======================================================================================
-- Q2. Same split for cancellations.
--
-- This table has one TTP_DATE rather than a curr and prev pair, because a cancellation
-- clears the date instead of moving it. So the lost slot is TTP_DATE itself.
-- Read: 0 through 7 is the cancellation half of metric 3. Add it to Q1's.
-- =======================================================================================
select date_diff(TTP_DATE, cast(SNAPSHOT_DATE_TIME_CURR as date), day) as days_notice,
       count(*)                 as events,
       count(distinct ORDER_ID) as orders
from LTD_Cancellations
group by date_diff(TTP_DATE, cast(SNAPSHOT_DATE_TIME_CURR as date), day)
order by days_notice;


-- =======================================================================================
-- Q3. Coverage on the cancellations table, to match what we know about reschedules.
-- =======================================================================================
select min(SNAPSHOT_DATE_TIME_CURR) as first_snapshot,
       max(SNAPSHOT_DATE_TIME_CURR) as last_snapshot,
       count(*)                     as all_cancellations,
       count(distinct ORDER_ID)     as distinct_orders
from LTD_Cancellations;


-- =======================================================================================
-- Q4. Every cancellation reason and how often it fires.
--
-- The sample showed "ATC Switching Patients" and "Acute Event", neither of which the
-- pipeline categorises today. Each value returned here needs a category before this table
-- drives a metric, same rule as the order-level reasons.
-- =======================================================================================
select CANCELLATION_REASON, count(*) as rows_
from LTD_Cancellations
group by CANCELLATION_REASON
order by rows_ desc;


-- =======================================================================================
-- Q5. Find the orders history in this layer, to join a centre onto both LTD tables.
--
-- Neither LTD table carries an ATC column; ORDER_ID is the only key. hist_IovanceCares_Orders
-- already failed. Try these, then use the catalog search box for "hist" and note every hit.
-- =======================================================================================
select * from hist_Iovance_Cares_Orders limit 5;

select * from hist_Orders limit 5;

select * from hist_IovanceCares_Order limit 5;


-- =======================================================================================
-- Q6. Failing that, join a centre from the current orders file.
--
-- Loses centre history if an order ever moved between centres, but for a first
-- reconciliation against the dashboard it is enough.
-- Read: events per centre, to compare against the metric 3 row per centre.
-- Adjust the orders table name if file_IovanceCares_Orders is spelled differently.
-- =======================================================================================
select o.ATC                    as centre,
       count(*)                 as reschedules_within_7,
       count(distinct r.ORDER_ID) as orders
from LTD_Reschedules r
join file_IovanceCares_Orders o
  on o.Order_Request__TIL_Order_Name = r.ORDER_ID
where date_diff(r.TTP_DATE_PREV, cast(r.SNAPSHOT_DATE_TIME_CURR as date), day) between 0 and 7
group by o.ATC
order by reschedules_within_7 desc;


-- =======================================================================================
-- Q7. Do the six unmatched centres appear in the name mapping?
--
-- Pull the distinct list, download it, and diff against the 85 centres in the analysis
-- table offline. Note the list contains a literal "TBD" value.
-- =======================================================================================
select distinct F__ATC_NAME__IOVANCECARES_ as atc_name
from file_IC_ATC_Name_to_Veeva_Name_Mapping
order by atc_name;


-- =======================================================================================
-- NOT worth running: the slot-fate join, and anything on file_ATC_Ops_START_Data.
--
-- Slot fate needs hist_Manufacturing_Slots, whose history stops 20 May 2025.
-- START_Data is 37 rows across 26 centres and ends Apr 2025. Both are too thin to report on.
-- =======================================================================================

-- Infinity uploaded-files layer: the queries still unanswered.
--
-- Anything already run and answered has been removed. Results are recorded in
--   PPR Automation/INFINITY - table results (do not re-query).md
-- Read that first. Do not re-run a table that already has a section there.
--
-- Already settled, do not repeat:
--   LTD_Reschedules exists, columns known
--   hist_Manufacturing_Slots exists, history stops 20 May 2025
--   hist_IovanceCares_Orders does not exist under that name
--   file_IC_ATC_Name_to_Veeva_Name_Mapping exists, one centre to many Veeva accounts
--   file_ATC_Ops_Roster is a five-person field team roster, no onboarding date
--   file_ATC_Ops_START_Data exists, one row per TTP, surgical process log
--
-- Explorer dialect. Plain SELECT only, no CTEs and no window functions; both failed there.
-- Run one at a time, top to bottom, and write each result into the notebook above.


-- =======================================================================================
-- Q1. THE ONE THAT MATTERS. How recent is the reschedules table?
--
-- Metric 3 is empty for every 2026 column because our snapshot export stops 15 Sep 2025.
-- If this table runs past that, the gap closes and metric 3 comes off its caveat.
-- Read: last_snapshot is the answer. Anything in 2026 is a win.
-- =======================================================================================
select min(SNAPSHOT_DATE_TIME_CURR) as first_snapshot,
       max(SNAPSHOT_DATE_TIME_CURR) as last_snapshot,
       count(*)                     as all_reschedules,
       count(distinct ORDER_ID)     as distinct_orders
from LTD_Reschedules;


-- =======================================================================================
-- Q2. Is there a cancellations table beside it?
--
-- The Infinity dashboard showed a cancellations panel next to the reschedules one, so a
-- sibling table probably exists. Try each name; the first that returns rows wins. If all
-- three fail, use the catalog search box for "cancel".
-- A reschedule moves the date, a cancellation clears it. Metric 3 counts both.
-- =======================================================================================
select * from LTD_Cancellations limit 5;

select * from LTD_Cancels limit 5;

select * from LTD_Cancellation limit 5;


-- =======================================================================================
-- Q3. What does RESCHEDULED_CATEGORY actually contain?
--
-- Every sampled row read "Postponed". There is presumably a pulled-forward value and maybe
-- a cancelled one. Whatever comes back here needs a category in the pipeline before the
-- column is used, same rule as cancellation reasons.
-- =======================================================================================
select RESCHEDULED_CATEGORY, count(*) as rows_
from LTD_Reschedules
group by RESCHEDULED_CATEGORY;


-- =======================================================================================
-- Q4. The 7-day population, straight from their table.
--
-- days_notice is old TTP minus the snapshot the change was seen on, which is how the saved
-- chart view computes Days_from_Old_TTP. Verified against one row on that view.
-- Read: the count for days_notice 0 through 7 is the metric 3 population on this source.
-- Compare it to the 83 events our pipeline reports from the daily-snapshot export.
-- Expect theirs to be higher: their feed is hourly and starts two months earlier.
-- =======================================================================================
select date_diff(TTP_DATE_PREV, SNAPSHOT_DATE_TIME_CURR, day) as days_notice,
       count(*)                                               as events,
       count(distinct ORDER_ID)                               as orders
from LTD_Reschedules
group by date_diff(TTP_DATE_PREV, SNAPSHOT_DATE_TIME_CURR, day)
order by days_notice;


-- =======================================================================================
-- Q5. Does the reschedules table carry a centre, or does it need a join?
--
-- The saved chart view lists ATC as a dimension, but that may be added by its join rather
-- than held on the base table. If ORDER_ID is the only key, metric 3 has to be joined back
-- to the orders file to get a centre, which is what our pipeline already does.
-- Read: whether an ATC-like column appears in the output at all.
-- =======================================================================================
select * from LTD_Reschedules limit 1;


-- =======================================================================================
-- Q6. Find the orders history in this layer.
--
-- hist_IovanceCares_Orders failed. Try these, then fall back to the catalog search box for
-- "hist" and note every table it returns.
-- =======================================================================================
select * from hist_Iovance_Cares_Orders limit 5;

select * from hist_IovanceCares_Order limit 5;

select * from hist_Orders limit 5;


-- =======================================================================================
-- Q7. Do the six unmatched centres appear in the name mapping?
--
-- Our pipeline fuzzy-matches centre names and six centres come through with no region or
-- segment. The mapping is one centre to many Veeva accounts, so it is not a direct
-- crosswalk, but the left-hand column is the authoritative centre spelling.
-- Read: pull the distinct list, download it, and diff against the 85 centres in the
-- analysis table. Do the diff offline, not here.
-- =======================================================================================
select distinct F__ATC_NAME__IOVANCECARES_ as atc_name
from file_IC_ATC_Name_to_Veeva_Name_Mapping
order by atc_name;


-- =======================================================================================
-- Q8. How much OR-access data is in the START log, and for how many centres?
--
-- Not scorecard work. This is sizing a possible second sheet before raising it, so the ask
-- comes with a number attached rather than a hunch.
-- Read: if ttps is in the hundreds across most centres, it is worth proposing.
-- =======================================================================================
select count(*)                as ttps,
       count(distinct ATC_)    as centres,
       min(TTP_DATE)           as first_ttp,
       max(TTP_DATE)           as last_ttp
from file_ATC_Ops_START_Data;


-- =======================================================================================
-- NOT worth running yet: the slot-fate join.
--
-- It needs hist_Manufacturing_Slots, whose history stops 20 May 2025, four months before
-- even the orders export. Any Filled by / Lost Capacity / At Risk column built on it would
-- cover Jun 2024 to May 2025 and nothing since. Revisit only if that feed is refreshed.
-- =======================================================================================

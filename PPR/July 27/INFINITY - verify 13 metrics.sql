-- Is the pipeline's export older than the live table?
--
-- The dashboard reads 135 enrollments for this centre while a plain count returned 139, and
-- metric 9 lands on 4/88 in Infinity against roughly 4/83 in the dashboard. Same gap, same
-- direction, so either the 139 counted duplicate rows, or the export predates orders that
-- Infinity has since added.
--
-- If distinct_orders is 135, the extra rows were duplicates and enrollments are fine.
-- If it is 139 and newest_order is later than the as-of in analysis/run_meta.json, the
-- export is simply out of date and the pipeline is right about the data it was handed.

select count(*)                                        as rows_all,
       count(distinct order_request__til_order_name)   as distinct_orders,
       max(order_request__created_date)                as newest_order
from bai_list_of_orders
where atc = 'University Of Texas MD Anderson Cancer Center';

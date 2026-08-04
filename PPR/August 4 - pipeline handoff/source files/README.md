# The two files that are not in Redshift

**This folder is empty. Add the two exports before the folder goes anywhere.**

    LTD_Reschedules       one row per change to a booked procurement slot
    LTD_Cancellations     one row per cancelled procurement slot

Both come from the uploaded files layer, not from the BI tables that already
land in Redshift.

They feed one metric, the count of slots given up with seven days notice or
less. The columns the pipeline reads:

    LTD_Reschedules       ORDER_ID, TTP_DATE_PREV, SNAPSHOT_DATE_TIME_CURR,
                          RESCHEDULED_CATEGORY
    LTD_Cancellations     ORDER_ID, TTP_DATE, SNAPSHOT_DATE_TIME_CURR,
                          CANCELLATION_REASON

`ORDER_ID` matches `order_request__til_order_name` on the orders table. Neither
file carries a treatment centre, so events are joined back to orders to get one.

These are copies for landing in Redshift. To run the pipeline they go in
`pipeline/data/` alongside the other four.

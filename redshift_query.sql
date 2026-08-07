-- Query for Redshift Segment
-- We just pull the current cancellation records from LTD table

SELECT 
    ORDER_ID as order_id, 
    TTP_DATE as ttp_date, 
    SNAPSHOT_DATE_TIME_CURR as snapshot_date, 
    CANCELLATION_REASON as cancellation_reason
FROM LTD_Cancellations;

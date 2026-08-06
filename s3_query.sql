-- Query for S3 Infinity Segment
-- Note: Since CTEs and Window functions (like LAG) are not supported in Infinity,
-- we pull the raw history of TTP dates and will process the cancellation logic locally in Python.

SELECT 
    order_request__til_order_name AS order_id, 
    record_number, 
    load_datetime, 
    tumor_tissue_pick_up_date AS ttp_date
FROM bai_list_of_orders_hist
WHERE order_request__til_order_name IS NOT NULL
ORDER BY order_request__til_order_name, cast(record_number as integer);

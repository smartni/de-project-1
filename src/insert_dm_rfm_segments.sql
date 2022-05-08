INSERT INTO analysis.dm_rfm_segments (user_id, recency, frequency, monetary_value)
WITH orders_filter AS (
SELECT user_id
, order_id
, order_ts 
, payment
FROM analysis.orders
WHERE status = (SELECT id FROM analysis.orderstatuses WHERE "key" = 'Closed')
AND order_ts >= '2021-01-01 00:00:00'
)
, prepared_data AS (
SELECT u.id AS user_id
, count(o.order_id) AS orders_cnt
, sum(o.payment) AS payments_sum
, max(o.order_ts)  AS last_order_dt
FROM analysis.users AS u
LEFT JOIN orders_filter AS o ON o.user_id = u.id
GROUP BY 1
)
SELECT user_id
, NTILE(5) OVER (ORDER BY COALESCE(last_order_dt,to_timestamp(0))) as recency
, NTILE(5) OVER (ORDER BY orders_cnt) as frequency
, NTILE(5) OVER (ORDER BY COALESCE(payments_sum,0)) as monetary_value
FROM prepared_data;
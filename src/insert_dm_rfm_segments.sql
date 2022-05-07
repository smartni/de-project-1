INSERT INTO analysis.dm_rfm_segments (user_id, recency, frequency, monetary)
WITH orders_filter AS (
SELECT user_id
, order_id
, order_ts 
, payment
FROM analysis.orders
WHERE status = (SELECT id FROM analysis.orderstatuses WHERE "key" = 'Closed')
AND order_ts > '2021-01-01 00:00:00'
)
, prepared_data AS (
SELECT u.id AS user_id
, count(o.order_id) AS orders_cnt
, sum(o.payment) AS paymenrs_sum
, max(o.order_ts)  AS last_order_dt
FROM analysis.users AS u
LEFT JOIN orders_filter AS o ON o.user_id = u.id
GROUP BY 1
)
SELECT user_id
, NTILE(5) OVER (ORDER BY CASE WHEN last_order_dt IS NULL THEN '1961-04-12 06:07:00' ELSE last_order_dt end ) as recency
, NTILE(5) OVER (ORDER BY orders_cnt) as frequency
, NTILE(5) OVER (ORDER BY paymenrs_sum) as monetary
FROM prepared_data;
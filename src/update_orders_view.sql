CREATE VIEW analysis.orders AS
WITH last_status AS (
SELECT order_id
, status_id
, DENSE_RANK() OVER (PARTITION BY order_id ORDER BY dttm DESC) AS n
FROM production.orderstatuslog o 
)
SELECT o.order_id
, o.order_ts 
, o.user_id
, o.bonus_payment
, o.payment 
, o.cost
, o.bonus_grant
, s.status_id AS status
FROM production.orders AS o
LEFT JOIN (
SELECT order_id, status_id 
FROM last_status
WHERE n = 1
) AS s ON s.order_id = o.order_id;
# Проект 1
Опишите здесь поэтапно ход решения задачи. Вы можете ориентироваться на тот план выполнения проекта, который мы предлагаем в инструкции на платформе.
1. Узнать требования к задаче
	- Где должна находится витрина? В схеме `analysis`
	- Какие поля должна содержать витрина? 
		- `user_id`
		- `recency` (время с последнего успешно выполенного заказа, число от 1 до 5, 1 у самого давней даты или юзеров без заказов )
		- `frequency` (кол-во успешно выполенных заказов на юзера, число от 1 до 5, 1 у наименьшего кол-ва заказов)
		- `monetary_value` (сумма успешно выполенных заказов на юзера, 1 у наименьшей суммы) *нет данных о какой конкретно сумме идет речь, с учетом бонусов или нет, для текущей витрины берем payment, так как он не отличается от cost из-за 0 в bonus_payment*
	- Что такое успешно выполенный заказ? Заказ со статусом Closed
	- За какой период нужны данные? С начала 2021 года
	- Нужно ли обновлять витрину и с какой периодичностью? Обновления не нужны
	- Как назвать витрину? Называем `dm_rfm_segments`
2. Проверить исходные данные
	- Для построения витрины необходимы данные из таблиц:
		- `production.orders` - берём отсюда заказы и их сумму
		- `production.orderstatuses` - берём отсюда id необходимого нам статуса заказов Closed
		- `production.users` - берём отсюда всех юзеров сервиса, будем джойнить к ним данные о заказах
	- Решение
		- подготавливаем данные об успешно выполенных заказах из таблицы `production.orders`: берём нужный статус из `production.orderstatuses`) и добавляем условие по датам заказа
		- делаем джойн на всех юзеров и рассчитываем нужные метрики: дата последнего заказа, кол-во заказов, сумма заказов
		- с помощью оконной функции NTILE(5) присваем номер группы для каждой метрики
3. Проверить качество исходных данных
	- С данными проблем не заметил, но кажется странной практикой использовать идентификатор юзера с 0
	- Инструменты обеспечения качества данных:
		- Задаются PRIMARY KEY (для id юзеров и заказов, поля, которые должны быть уникальны)
		- Задаются FOREIGN KEY (для order_id и status_id в production.orderstatuslog). *Странно, что не задано для user_id в таблице orders*
		- Задается условие UNIQUE (для order_id и status_id в production.orderstatuslog)
		- Используются проверки, например, в `production.orders` проверка `cost = (payment + bonus_payment)` или `((price >= (0)::numeric))` в `production.orderitems`
		- Условия NOT NULL и дефолтные значения 
4. Подготовить витрину
	- Сделать представления исходных таблиц в схему analysis
		- ```
CREATE VIEW analysis.orderitems AS
SELECT *
FROM production.orderitems;
CREATE VIEW analysis.orders AS
SELECT *
FROM production.orders;
CREATE VIEW analysis.orderstatuses AS
SELECT *
FROM production.orderstatuses;
CREATE VIEW analysis.orderstatuslog AS
SELECT *
FROM production.orderstatuslog;
CREATE VIEW analysis.products AS
SELECT *
FROM production.products;
CREATE VIEW analysis.users AS
SELECT *
FROM production.users;```
	- Создать витрину `analysis.dm_rfm_segments`
		- ```
CREATE TABLE IF NOT EXISTS analysis.dm_rfm_segments (
user_id int4 NOT NULL,
recency int2 NOT NULL,
frequency int2 NOT NULL,
monetary int2 NOT NULL,
CONSTRAINT userid_pkey PRIMARY KEY (user_id)
);```
	- Заполнить витрину значениями
		- ```
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
FROM prepared_data;```
5. Обновить формирование представления analysis.orders
	```
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
```

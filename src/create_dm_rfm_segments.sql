CREATE TABLE IF NOT EXISTS analysis.dm_rfm_segments (
user_id int4,
recency int2 NOT NULL,
frequency int2 NOT NULL,
monetary_value int2 NOT NULL,
CONSTRAINT userid_pkey PRIMARY KEY (user_id)
);
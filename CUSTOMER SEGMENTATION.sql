-- CUSTOMER SEGMENTATION & ANALYTICAL DATA MODEL
-- STEP 1: BUILDING ANALYTICAL GRAIN (ORDER-LEVEL FEATURES)

-- Aggregate payments at order level
CREATE VIEW view_order_payments AS
SELECT
order_id,
SUM(payment_value) AS payment_value
FROM core_order_payments
GROUP BY order_id;

-- Aggregate review score at order level
CREATE VIEW view_order_reviews AS
SELECT
order_id,
AVG(review_score) AS review_score
FROM core_order_reviews
GROUP BY order_id;

-- Aggregate order items at order level
CREATE VIEW view_order_items AS
SELECT
order_id,
SUM(price) AS order_value,
COUNT(order_item_id) AS items_count,
SUM(freight_value) AS freight_value
FROM core_order_items
GROUP BY order_id;

-- STEP 2: BUILDING ORDER-LEVEL ANALYTICAL TABLE

-- Purpose: central analytical table joining all order-level signals

CREATE VIEW view_segmentation_table AS
SELECT
co.order_id,
co.customer_id,
ccu.customer_unique_id,

co.order_purchase_timestamp,
co.order_delivered_customer_date,
co.order_estimated_delivery_date,

voi.order_value,
vop.payment_value,
voi.items_count,
voi.freight_value,
vor.review_score,

-- Delivery performance metrics
co.order_delivered_customer_date - co.order_purchase_timestamp AS delivery_time_days,
co.order_delivered_customer_date - co.order_estimated_delivery_date AS delivery_delay_days,

-- Late delivery flag (business SLA indicator)
CASE 
    WHEN co.order_delivered_customer_date > co.order_estimated_delivery_date 
    THEN 1 ELSE 0 
END AS is_late_delivery

FROM core_orders co

LEFT JOIN core_customers ccu
ON co.customer_id = ccu.customer_id

LEFT JOIN view_order_items voi
ON co.order_id = voi.order_id

LEFT JOIN view_order_payments vop
ON co.order_id = vop.order_id

LEFT JOIN view_order_reviews vor
ON co.order_id = vor.order_id;

-- STEP 3: CUSTOMER-LEVEL FEATURE ENGINEERING

-- Purpose: transform order-level data into customer-level analytics dataset

CREATE VIEW view_customer_features AS
SELECT
customer_unique_id,

SUM(payment_value) AS total_spent,                      -- Monetary value (M)
AVG(order_value) AS avg_order_value,
COUNT(*) AS nb_of_orders,                               -- Frequency (F)

MIN(order_purchase_timestamp) AS first_purchase_date,
MAX(order_purchase_timestamp) AS last_purchase_date,

-- Recency (R): time since last purchase (reference date fixed to dataset end)
TIMESTAMP '2018-10-18 00:00:00' - MAX(order_purchase_timestamp) AS recency,

AVG(review_score) AS avg_review_score,
AVG(delivery_time_days) AS avg_delivery_time,
AVG(delivery_delay_days) AS avg_delivery_delay,

-- Share of late deliveries
(SUM(is_late_delivery) * 100.0 / COUNT(is_late_delivery)) AS pct_late_deliveries

FROM view_segmentation_table
GROUP BY customer_unique_id;

-- STEP 4: RFM SCORING PREPARATION

-- Recency distribution (used for scoring logic validation)
SELECT
percentile_cont(0.0) WITHIN GROUP (ORDER BY recency) AS p0,
percentile_cont(0.2) WITHIN GROUP (ORDER BY recency) AS p20,
percentile_cont(0.4) WITHIN GROUP (ORDER BY recency) AS p40,
percentile_cont(0.6) WITHIN GROUP (ORDER BY recency) AS p60,
percentile_cont(0.8) WITHIN GROUP (ORDER BY recency) AS p80,
percentile_cont(1.0) WITHIN GROUP (ORDER BY recency) AS p100
FROM view_customer_features;

-- Recency scoring (quintiles)
SELECT
customer_unique_id,
recency,
NTILE(5) OVER (ORDER BY recency) AS recency_score
FROM view_customer_features;

-- Frequency distribution (note: highly skewed dataset)
SELECT
percentile_cont(0.0) WITHIN GROUP (ORDER BY nb_of_orders) AS p0,
percentile_cont(0.2) WITHIN GROUP (ORDER BY nb_of_orders) AS p20,
percentile_cont(0.4) WITHIN GROUP (ORDER BY nb_of_orders) AS p40,
percentile_cont(0.6) WITHIN GROUP (ORDER BY nb_of_orders) AS p60,
percentile_cont(0.8) WITHIN GROUP (ORDER BY nb_of_orders) AS p80,
percentile_cont(1.0) WITHIN GROUP (ORDER BY nb_of_orders) AS p100
FROM view_customer_features;

-- Monetary distribution
SELECT
percentile_cont(0.0) WITHIN GROUP (ORDER BY total_spent) AS p0,
percentile_cont(0.2) WITHIN GROUP (ORDER BY total_spent) AS p20,
percentile_cont(0.4) WITHIN GROUP (ORDER BY total_spent) AS p40,
percentile_cont(0.6) WITHIN GROUP (ORDER BY total_spent) AS p60,
percentile_cont(0.8) WITHIN GROUP (ORDER BY total_spent) AS p80,
percentile_cont(1.0) WITHIN GROUP (ORDER BY total_spent) AS p100
FROM view_customer_features;

-- Monetary scoring (quintiles)
SELECT
customer_unique_id,
total_spent,
NTILE(5) OVER (ORDER BY total_spent) AS monetary_score
FROM view_customer_features;

-- STEP 5: RFM MODEL CONSTRUCTION

-- Purpose: define customer value based on recency, frequency, and monetary behavior

CREATE VIEW view_rfm AS
SELECT
customer_unique_id,

recency,
nb_of_orders AS frequency,
total_spent AS monetary,

-- Scoring logic
NTILE(5) OVER (ORDER BY recency DESC) AS recency_score,
CASE WHEN nb_of_orders = 1 THEN 1 ELSE 2 END AS frequency_score,
NTILE(5) OVER (ORDER BY total_spent) AS monetary_score

FROM view_customer_features
WHERE recency IS NOT NULL
AND nb_of_orders IS NOT NULL
AND total_spent IS NOT NULL;

-- STEP 6: CUSTOMER SEGMENTATION (RFM CLUSTERING)

CREATE VIEW view_rfm_segments AS
SELECT
customer_unique_id,

recency,
frequency,
monetary,

recency_score,
frequency_score,
monetary_score,

CASE

    -- VIP customers (high value + recent + repeated buyers)
    WHEN recency_score >= 4
     AND monetary_score >= 4
     AND frequency_score = 2
    THEN 'VIP'

    -- High value one-shot customers
    WHEN recency_score >= 4
     AND monetary_score >= 4
     AND frequency_score = 1
    THEN 'High value one-shot'

    -- New customers (recent but low history)
    WHEN recency_score >= 4
     AND frequency_score = 1
     AND monetary_score <= 3
    THEN 'New customers'

    -- At-risk customers (high value but inactive)
    WHEN recency_score <= 2
     AND monetary_score >= 3
    THEN 'At risk customers'

    -- Lost customers (inactive + low value)
    WHEN recency_score <= 2
     AND monetary_score <= 2
    THEN 'Lost customers'

    -- Default cluster
    ELSE 'Regular customers'

END AS segment

FROM view_rfm;

-- STEP 7: CHURN ANALYSIS (CUSTOMER LIFECYCLE)

CREATE VIEW view_churn_segments AS
SELECT
customer_unique_id,
recency_score,

CASE 
    WHEN recency_score >= 4 THEN 'Active'
    WHEN recency_score = 3 THEN 'Still engaged'
    WHEN recency_score = 2 THEN 'Weak engagement'
    ELSE 'Churned'
END AS customer_status

FROM view_rfm;

-- STEP 8: CUSTOMER SATISFACTION SEGMENTATION

-- Review-based satisfaction segmentation
CREATE VIEW view_review_segments AS
SELECT
customer_unique_id,
avg_review_score,

CASE 
    WHEN avg_review_score >= 4 THEN 'Satisfied'
    WHEN avg_review_score = 3 THEN 'Neutral'
    WHEN avg_review_score < 3 THEN 'Dissatisfied'
    ELSE 'No review'
END AS segment

FROM view_customer_features;

-- STEP 9: DELIVERY EXPERIENCE SEGMENTATION

-- Delivery performance perception based on delay thresholds
CREATE VIEW view_customer_delivery_segments AS
SELECT
customer_unique_id,
delivery_delay_days,

CASE 
    WHEN delivery_delay_days <= INTERVAL '0 days' THEN 'Early / On-time'
    WHEN delivery_delay_days < INTERVAL '3 days' THEN 'Slight delay'
    WHEN delivery_delay_days > INTERVAL '3 days' THEN 'Bad delay'
    ELSE 'Not mentioned'
END AS delivery_segment

FROM view_segmentation_table;

-- Distribution of delivery experience
SELECT
delivery_segment,
COUNT(*) AS nb_customers
FROM view_customer_delivery_segments
GROUP BY delivery_segment;
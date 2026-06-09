-- DATA MODELING & SECOND-LAYER CLEANING
-- CREATE CORE TABLES (CLEAN LAYER)

-- Purpose: create analytical-ready tables from validated staging layer

CREATE TABLE core_customers AS
SELECT * FROM staging_customers;

CREATE TABLE core_geolocation AS
SELECT * FROM staging_geolocation;

CREATE TABLE core_order_items AS
SELECT * FROM staging_order_items;

CREATE TABLE core_order_payments AS
SELECT * FROM staging_order_payments;

CREATE TABLE core_order_reviews AS
SELECT * FROM staging_order_reviews;

CREATE TABLE core_orders AS
SELECT * FROM staging_orders;

CREATE TABLE core_products AS
SELECT * FROM staging_products;

CREATE TABLE core_sellers AS
SELECT * FROM staging_sellers;

-- RELATIONSHIP VALIDATION (DATA MODEL INTEGRITY)

-- Goal: ensure referential integrity between core tables (no orphan records)

-- CUSTOMER ↔ ORDERS
SELECT *
FROM core_orders co
INNER JOIN core_customers cc
ON cc.customer_id = co.customer_id;

-- Orphan check (orders without valid customer)
SELECT COUNT(*) AS orphan_orders
FROM core_orders co
LEFT JOIN core_customers cc
ON cc.customer_id = co.customer_id
WHERE cc.customer_id IS NULL;

-- ORDERS ↔ PAYMENTS

-- Check payment aggregation per order
SELECT
co.order_id,
COUNT(cop.order_id) AS nb_payments
FROM core_orders co
LEFT JOIN core_order_payments cop
ON cop.order_id = co.order_id
GROUP BY co.order_id
ORDER BY nb_payments DESC;

-- Orphan payments check (payments without valid order)
SELECT COUNT(*) AS orphan_orders
FROM core_order_payments cop
LEFT JOIN core_orders co
ON cop.order_id = co.order_id
WHERE co.order_id IS NULL;

-- ORDERS ↔ REVIEWS

SELECT *
FROM core_order_reviews cor
INNER JOIN core_orders co
ON cor.order_id = co.order_id;

-- Orphan reviews check
SELECT COUNT(*) AS orphan_reviews
FROM core_order_reviews cor
LEFT JOIN core_orders co
ON co.order_id = cor.order_id
WHERE co.order_id IS NULL;

-- ORDERS ↔ ORDER ITEMS

SELECT *
FROM core_order_items coi
INNER JOIN core_orders co
ON coi.order_id = co.order_id;

-- Orphan order items check
SELECT COUNT(*) AS orphan_order_items
FROM core_order_items coi
LEFT JOIN core_orders co
ON coi.order_id = co.order_id
WHERE co.order_id IS NULL;

-- Business insight: number of items per order
SELECT
co.order_id,
COUNT(coi.order_id) AS nb_order_items
FROM core_orders co
LEFT JOIN core_order_items coi
ON co.order_id = coi.order_id
GROUP BY co.order_id
ORDER BY nb_order_items DESC;

-- ORDER ITEMS ↔ PRODUCTS

SELECT *
FROM core_order_items coi
INNER JOIN core_products cp
ON coi.product_id = cp.product_id;

-- Orphan products check
SELECT COUNT(*) AS orphan_products
FROM core_order_items coi
LEFT JOIN core_products cp
ON coi.product_id = cp.product_id
WHERE cp.product_id IS NULL;

-- ORDER ITEMS ↔ SELLERS

SELECT *
FROM core_order_items coi
INNER JOIN core_sellers cs
ON coi.seller_id = cs.seller_id;

-- Orphan sellers check
SELECT COUNT(*) AS orphan_sellers
FROM core_order_items coi
LEFT JOIN core_sellers cs
ON coi.seller_id = cs.seller_id
WHERE cs.seller_id IS NULL;

-- SECOND-LAYER DATA QUALITY CHECKS
-- PAYMENT CONSISTENCY VS ORDER VALUE

-- Aggregate payment values per order
CREATE VIEW order_payment_totals AS
SELECT
order_id,
SUM(payment_value) AS total_payment_value
FROM core_order_payments
GROUP BY order_id;

-- Compare payments vs actual order value (items + freight)
SELECT
opt.order_id,
opt.total_payment_value,
coi.total_price
FROM order_payment_totals opt
INNER JOIN (
SELECT
order_id,
SUM(price + freight_value) AS total_price
FROM core_order_items
GROUP BY order_id
) coi
ON opt.order_id = coi.order_id
WHERE opt.total_payment_value != coi.total_price;

-- Insight:
-- ~209 / 98,666 orders show minor mismatches
-- Likely causes:
-- - rounding differences
-- - installment payment structures
-- - payment adjustments or refunds

-- ORDER STATUS VS DELIVERY CONSISTENCY

-- Delivered orders missing delivery timestamp
SELECT *
FROM core_orders
WHERE order_status = 'delivered'
AND order_delivered_customer_date IS NULL;

-- Business note: already flagged in previous cleaning layer

-- Cancelled or unavailable orders with delivery date (data inconsistency check)
SELECT *
FROM core_orders
WHERE order_status IN ('canceled', 'unavailable')
AND order_delivered_customer_date IS NOT NULL;

-- Insight:
-- Possible cases:
-- - returns after cancellation
-- - data entry inconsistency
-- - late status update

-- SHIPPING SLA COMPLIANCE ANALYSIS

-- Identify orders missing item-level shipping constraints
SELECT order_status, COUNT(*)
FROM core_orders
WHERE order_id IN (
SELECT co.order_id
FROM core_orders co
LEFT JOIN core_order_items coi
ON co.order_id = coi.order_id
WHERE coi.order_id IS NULL
)
GROUP BY order_status;

-- Insight:
-- Majority of missing shipping records correspond to:
-- - canceled orders
-- - unavailable orders (767 / 785 cases)

-- LATE SHIPPING ANALYSIS (CARRIER SLA BREACH)

-- Number of orders delivered to carrier after shipping limit
SELECT COUNT() AS nb_late_orders,
(SELECT COUNT() FROM core_orders) AS total_orders
FROM core_orders co
INNER JOIN (
SELECT
order_id,
MAX(shipping_limit_date) AS shipping_limit_date
FROM core_order_items
GROUP BY order_id
) coi
ON co.order_id = coi.order_id
WHERE co.order_delivered_carrier_date > coi.shipping_limit_date;

-- Inspect SLA breaches
SELECT
co.order_id,
co.order_delivered_carrier_date,
coi.shipping_limit_date
FROM core_orders co
LEFT JOIN (
SELECT
order_id,
MAX(shipping_limit_date) AS shipping_limit_date
FROM core_order_items
GROUP BY order_id
) coi
ON co.order_id = coi.order_id
WHERE co.order_delivered_carrier_date > coi.shipping_limit_date;

-- Insight:
-- Captures operational delays where carrier handover exceeded contractual SLA
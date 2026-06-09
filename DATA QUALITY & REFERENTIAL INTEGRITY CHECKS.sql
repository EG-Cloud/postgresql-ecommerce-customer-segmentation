-- DATA QUALITY & REFERENTIAL INTEGRITY CHECKS
-- GLOBAL OBJECTIVE

-- Validate primary keys, foreign keys, and referential integrity
-- Ensure no orphan records exist across the data model
-- Confirm reliability of joins for analytical modeling

-- TABLE: CUSTOMERS

-- Validate primary key uniqueness
SELECT customer_id
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Validate null integrity on primary key
SELECT *
FROM customers
WHERE customer_id IS NULL;

-- Result:
-- customer_id is unique and fully populated
-- → Customers table is structurally reliable

-- TABLE: GEOLOCATION

-- Validate missing geographic keys
SELECT *
FROM geolocation
WHERE geolocation_zip_code_prefix IS NULL;

-- Result:
-- No missing zip codes detected
-- → Geolocation table is complete for spatial analysis

-- TABLE: ORDER ITEMS (CORE FACT VALIDATION)

-- Validate relationship: order_items → orders
SELECT *
FROM order_items oi
INNER JOIN orders o
ON oi.order_id = o.order_id;

-- Orphan check (order_items without valid order)
SELECT *
FROM order_items oi
LEFT JOIN orders o
ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Validate relationship: order_items → products
SELECT *
FROM order_items oi
INNER JOIN products p
ON oi.product_id = p.product_id;

-- Orphan products check
SELECT *
FROM order_items oi
LEFT JOIN products p
ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Validate relationship: order_items → sellers
SELECT *
FROM order_items oi
INNER JOIN sellers s
ON oi.seller_id = s.seller_id;

-- Orphan sellers check
SELECT *
FROM order_items oi
LEFT JOIN sellers s
ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Result:
-- All foreign key relationships are valid
-- → No orphan records detected in transactional layer

-- TABLE: ORDER PAYMENTS

-- Validate potential duplicates per order
SELECT order_id
FROM order_payments
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Business insight:
-- Multiple rows per order are expected
-- → customers can split payments (credit card + voucher, etc.)

-- Validate missing order_id values
SELECT *
FROM order_payments
WHERE order_id IS NULL;

-- Validate referential integrity with orders
SELECT *
FROM order_payments op
INNER JOIN orders o
ON op.order_id = o.order_id;

-- Orphan check
SELECT *
FROM order_payments op
LEFT JOIN orders o
ON op.order_id = o.order_id
WHERE o.order_id IS NULL;

-- TABLE: ORDER REVIEWS

-- Detect duplicate review_id
SELECT review_id
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;

-- Business insight:
-- Duplicates identified due to identical timestamps and scores
-- → likely data ingestion or system duplication issue

-- Remove duplicate records (keeping first occurrence)
DELETE FROM order_reviews a
USING order_reviews b
WHERE a.review_id = b.review_id
AND a.ctid > b.ctid;

-- Validate cleanup
SELECT review_id
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;

-- Validate relationship: reviews → orders
SELECT *
FROM order_reviews ors
INNER JOIN orders o
ON ors.order_id = o.order_id;

-- Orphan reviews check
SELECT *
FROM order_reviews ors
LEFT JOIN orders o
ON ors.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Result:
-- Referential integrity confirmed after deduplication

-- TABLE: ORDERS

-- Validate primary key uniqueness
SELECT order_id
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Validate null integrity
SELECT *
FROM orders
WHERE order_id IS NULL;

-- Validate relationship: orders → customers
SELECT *
FROM orders o
INNER JOIN customers c
ON o.customer_id = c.customer_id;

-- Orphan orders check (orders without valid customer)
SELECT *
FROM orders o
LEFT JOIN customers c
ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Result:
-- All orders are correctly linked to customers

-- TABLE: PRODUCTS

-- Validate primary key uniqueness
SELECT product_id
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Validate null integrity
SELECT *
FROM products
WHERE product_id IS NULL;

-- Result:
-- Product table is clean and fully keyed

-- TABLE: SELLERS

-- Validate primary key uniqueness
SELECT seller_id
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- Validate null integrity
SELECT *
FROM sellers
WHERE seller_id IS NULL;

-- Result:
-- Seller table is structurally consistent and ready for joins
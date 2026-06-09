-- DATA CLEANING & VALIDATION
-- TABLE: staging_customers

-- Preview data
SELECT *
FROM staging_customers;

-- Retrieve column structure
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'staging_customers';

-- Business check: ensure no critical fields contain NULL values
SELECT *
FROM staging_customers
WHERE customer_id IS NULL
OR customer_unique_id IS NULL
OR customer_zip_code_prefix IS NULL
OR customer_city IS NULL
OR customer_state IS NULL;

-- Result: No missing values → data is complete for key attributes

-- Check uniqueness of customer_id (technical primary key)
SELECT customer_id
FROM staging_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Check duplicates on customer_unique_id (business identifier)
SELECT customer_unique_id
FROM staging_customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

-- Insight:
-- customer_id is unique (PK)
-- customer_unique_id has duplicates → represents the real customer across multiple orders

-- Analyze city distribution (detect inconsistencies / misspellings)
SELECT customer_city, COUNT(*) AS nb
FROM staging_customers
GROUP BY customer_city
ORDER BY nb DESC;

-- Standardize city format (capitalize first letter)
UPDATE staging_customers
SET customer_city = INITCAP(customer_city);

-- Trim spaces from text fields
UPDATE staging_customers
SET customer_city = TRIM(customer_city);

UPDATE staging_customers
SET customer_state = TRIM(customer_state);

-- Validate zip code length (should not exceed 5 characters)
SELECT *
FROM staging_customers
WHERE LENGTH(customer_zip_code_prefix) > 5;

-- Result: No anomalies detected → zip codes are consistent

-- TABLE: staging_geolocation

-- Preview data
SELECT *
FROM staging_geolocation;

-- Retrieve column structure
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'staging_geolocation';

-- Business check: ensure no NULL values in key geographic fields
SELECT *
FROM staging_geolocation
WHERE geolocation_lat IS NULL
OR geolocation_lng IS NULL
OR geolocation_zip_code_prefix IS NULL
OR geolocation_city IS NULL
OR geolocation_state IS NULL;

-- Result: No missing values → dataset is complete

-- Analyze zip code distribution
SELECT geolocation_zip_code_prefix, COUNT(*) AS nb
FROM staging_geolocation
GROUP BY geolocation_zip_code_prefix
ORDER BY nb DESC;

-- Validate zip code length
SELECT *
FROM staging_geolocation
WHERE LENGTH(geolocation_zip_code_prefix) > 5;

-- Result: No invalid zip code formats detected

-- Analyze city distribution (identify inconsistencies)
SELECT geolocation_city, COUNT(*) AS nb
FROM staging_geolocation
GROUP BY geolocation_city
ORDER BY nb DESC;

-- Standardize city naming (remove encoding inconsistencies)
UPDATE staging_geolocation
SET geolocation_city = 'Sao Paulo'
WHERE geolocation_city = 'São Paulo';

-- Note: Ensures consistent grouping in downstream analysis

-- TABLE: staging_geolocation

-- Standardize text format (city: proper case, state: uppercase)
UPDATE staging_geolocation
SET geolocation_city = INITCAP(TRIM(geolocation_city));

UPDATE staging_geolocation
SET geolocation_state = UPPER(TRIM(geolocation_state));

-- Validate geographic coordinates (latitude must be between -90 and 90)
SELECT *
FROM staging_geolocation
WHERE geolocation_lat NOT BETWEEN -90 AND 90;

-- Result: No invalid latitude values detected → coordinates are consistent

-- TABLE: staging_order_items

-- Preview data
SELECT *
FROM staging_order_items;

-- Retrieve column structure
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'staging_order_items';

-- Data quality check: ensure no NULL values in key transactional fields
SELECT *
FROM staging_order_items
WHERE shipping_limit_date IS NULL
OR price IS NULL
OR freight_value IS NULL
OR order_id IS NULL
OR seller_id IS NULL
OR order_item_id IS NULL
OR product_id IS NULL;

-- Result: No missing values → dataset is complete

-- Check order granularity
SELECT order_id
FROM staging_order_items
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Insight: One order can contain multiple items (products/sellers) → expected behavior

-- Analyze product and seller distribution
SELECT product_id, COUNT(*) AS nb
FROM staging_order_items
GROUP BY product_id
ORDER BY nb DESC;

SELECT seller_id, COUNT(*) AS nb
FROM staging_order_items
GROUP BY seller_id
ORDER BY nb DESC;

-- Standardize identifiers (remove leading/trailing spaces)
UPDATE staging_order_items
SET order_id = TRIM(order_id);

UPDATE staging_order_items
SET product_id = TRIM(product_id);

UPDATE staging_order_items
SET seller_id = TRIM(seller_id);

-- Validate shipping date range
SELECT
MIN(shipping_limit_date) AS min_shipping_date,
MAX(shipping_limit_date) AS max_shipping_date
FROM staging_order_items;

-- Analyze shipping activity distribution
SELECT
DATE(shipping_limit_date) AS day,
COUNT(*) AS nb
FROM staging_order_items
GROUP BY day
ORDER BY nb DESC;

-- Result: Dates are consistent and follow expected distribution

-- Validate pricing consistency
SELECT *
FROM staging_order_items
WHERE price < 0;

SELECT
MIN(price) AS min_price,
MAX(price) AS max_price,
AVG(price) AS avg_price
FROM staging_order_items;

-- Validate freight cost consistency
SELECT *
FROM staging_order_items
WHERE freight_value < 0;

SELECT
MIN(freight_value) AS min_freight,
MAX(freight_value) AS max_freight,
AVG(freight_value) AS avg_freight
FROM staging_order_items;

-- Result: No negative or abnormal values detected → pricing data is reliable

-- TABLE: staging_order_payments

-- Preview data
SELECT *
FROM staging_order_payments;

-- Check for multiple payments per order
SELECT order_id
FROM staging_order_payments
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Insight: Multiple rows per order are expected
-- (split payments across methods such as card, voucher, etc.)

-- Analyze payment sequencing
SELECT payment_sequential
FROM staging_order_payments
GROUP BY payment_sequential
ORDER BY payment_sequential;

-- Analyze payment types
SELECT payment_type
FROM staging_order_payments
GROUP BY payment_type;

-- Result: Payment categories are valid

-- Analyze installment distribution
SELECT payment_installments
FROM staging_order_payments
GROUP BY payment_installments
ORDER BY payment_installments;

-- Identify anomalies (0 installments should not exist)
SELECT *
FROM staging_order_payments
WHERE payment_installments = '0';

-- Example validation on impacted orders
SELECT *
FROM staging_order_payments
WHERE order_id IN (
'744bade1fcf9ff3f31d860ace076d422',
'1a57108394169c0b47d8f876acc9ba2d'
);

-- Correct invalid installment records
UPDATE staging_order_payments
SET payment_sequential = '1',
payment_installments = '1'
WHERE payment_installments = '0';

-- Insight: Corrected based on consistent data found in related tables

-- Standardize identifiers
UPDATE staging_order_payments
SET order_id = TRIM(order_id);

-- Validate payment values
SELECT *
FROM staging_order_payments
WHERE payment_value < 0;

SELECT
MIN(payment_value) AS min_payment,
MAX(payment_value) AS max_payment,
AVG(payment_value) AS avg_payment
FROM staging_order_payments;

-- Result: Values are consistent
-- Note: Some zero values exist → should be validated with data source before removal

-- TABLE: staging_order_reviews

-- Preview data
SELECT *
FROM staging_order_reviews;

-- Retrieve column structure
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'staging_order_reviews';

-- Identify NULL values across review fields
SELECT *
FROM staging_order_reviews
WHERE review_score IS NULL
OR review_creation_date IS NULL
OR review_answer_timestamp IS NULL
OR review_comment_message IS NULL
OR review_comment_title IS NULL
OR order_id IS NULL
OR review_id IS NULL;

-- Quantify NULL distribution (% per column)
SELECT
COUNT() AS total_rows,
SUM(CASE WHEN review_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS review_id_null_pct,
SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS order_id_null_pct,
SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS review_score_null_pct,
SUM(CASE WHEN review_comment_title IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS review_title_null_pct,
SUM(CASE WHEN review_comment_message IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS review_comment_null_pct,
SUM(CASE WHEN review_creation_date IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS review_creation_date_null_pct,
SUM(CASE WHEN review_answer_timestamp IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS review_answer_timestamp_null_pct
FROM staging_order_reviews;

-- Replace missing textual reviews with default values
UPDATE staging_order_reviews
SET review_comment_title = 'No title'
WHERE review_comment_title IS NULL;

UPDATE staging_order_reviews
SET review_comment_message = 'No message'
WHERE review_comment_message IS NULL;

-- Insight: Missing values are mainly concentrated in optional text fields (title & comment)
-- → acceptable from a business perspective (customers may leave ratings without comments)

-- TABLE: staging_order_reviews (CONTINUED)

-- Check for duplicate review_id
SELECT review_id
FROM staging_order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;

-- Deep duplicate check (full row comparison)
SELECT
review_id,
order_id,
review_score,
review_comment_message,
review_creation_date,
COUNT() AS nb
FROM staging_order_reviews
GROUP BY
review_id,
order_id,
review_score,
review_comment_message,
review_creation_date
HAVING COUNT() > 1;

-- Result: No true duplicates detected
-- Insight: Multiple reviews can exist per order (different products reviewed at the same time)

-- Standardize identifiers
UPDATE staging_order_reviews
SET review_id = TRIM(review_id);

UPDATE staging_order_reviews
SET order_id = TRIM(order_id);

-- Check multiple reviews per order
SELECT order_id
FROM staging_order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Business insight: A single order can generate multiple reviews (multi-product orders)

-- Example validation
SELECT *
FROM staging_order_reviews
WHERE order_id = '565b0bdb5bfef65df5a23890967586f6';

-- Validate review score values
SELECT DISTINCT review_score
FROM staging_order_reviews;

-- Validate review date ranges
SELECT
MIN(review_creation_date) AS min_review_date,
MAX(review_creation_date) AS max_review_date
FROM staging_order_reviews;

SELECT
MIN(review_answer_timestamp) AS min_answer_date,
MAX(review_answer_timestamp) AS max_answer_date
FROM staging_order_reviews;

-- Check chronological consistency
SELECT *
FROM staging_order_reviews
WHERE review_creation_date > review_answer_timestamp;

-- Result: All dates are consistent (review created before answer)

-- TABLE: staging_orders

-- Preview data
SELECT *
FROM staging_orders;

-- Retrieve column structure
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'staging_orders';

-- Identify NULL values in key fields
SELECT *
FROM staging_orders
WHERE order_estimated_delivery_date IS NULL
OR order_approved_at IS NULL
OR order_delivered_carrier_date IS NULL
OR order_delivered_customer_date IS NULL
OR order_purchase_timestamp IS NULL
OR customer_id IS NULL
OR order_status IS NULL
OR order_id IS NULL;

-- Quantify NULL distribution
SELECT
COUNT() AS total_rows,
SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS est_delivery_null_pct,
SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS approved_null_pct,
SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS carrier_null_pct,
SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS delivered_null_pct,
SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS purchase_null_pct,
SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS customer_null_pct,
SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS status_null_pct,
SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS order_id_null_pct
FROM staging_orders;

-- Business explanation:
-- NULL values are expected for:
-- - canceled orders
-- - orders not yet delivered

-- Investigate missing timestamps
SELECT *
FROM staging_orders
WHERE order_approved_at IS NULL;

SELECT *
FROM staging_orders
WHERE order_delivered_carrier_date IS NULL;

SELECT *
FROM staging_orders
WHERE order_delivered_customer_date IS NULL;

-- Check uniqueness of order_id
SELECT order_id
FROM staging_orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Result: order_id is unique (primary key)

-- Standardize text fields
UPDATE staging_orders
SET order_id = TRIM(order_id);

UPDATE staging_orders
SET customer_id = TRIM(customer_id);

UPDATE staging_orders
SET order_status = TRIM(order_status);

-- Analyze order status values
SELECT order_status
FROM staging_orders
GROUP BY order_status;

-- Validate timeline consistency
SELECT
MIN(order_purchase_timestamp) AS min_purchase,
MAX(order_purchase_timestamp) AS max_purchase,
MIN(order_approved_at) AS min_approved,
MAX(order_approved_at) AS max_approved,
MIN(order_delivered_carrier_date) AS min_carrier,
MAX(order_delivered_carrier_date) AS max_carrier,
MIN(order_delivered_customer_date) AS min_customer,
MAX(order_delivered_customer_date) AS max_customer,
MIN(order_estimated_delivery_date) AS min_estimated,
MAX(order_estimated_delivery_date) AS max_estimated
FROM staging_orders;

-- Detect timeline inconsistencies
SELECT *
FROM staging_orders
WHERE order_purchase_timestamp > order_approved_at;

SELECT *
FROM staging_orders
WHERE order_approved_at > order_delivered_carrier_date;

SELECT *
FROM staging_orders
WHERE order_delivered_carrier_date > order_delivered_customer_date;

SELECT *
FROM staging_orders
WHERE order_delivered_customer_date > order_estimated_delivery_date;

-- Business interpretation:
-- - Some inconsistencies are data quality issues
-- - Late deliveries are expected (not an error)

-- Flag problematic records
ALTER TABLE staging_orders
ADD COLUMN is_any_date_issue INTEGER;

UPDATE staging_orders
SET is_any_date_issue =
CASE
WHEN order_approved_at > order_delivered_carrier_date
OR order_delivered_carrier_date > order_delivered_customer_date
THEN 1
ELSE 0
END;

-- Additional check: delivered orders without delivery date
SELECT *
FROM staging_orders
WHERE order_status = 'delivered'
AND order_delivered_customer_date IS NULL;

UPDATE staging_orders
SET is_any_date_issue = 1
WHERE order_status = 'delivered'
AND order_delivered_customer_date IS NULL;

-- Result: All inconsistent records are flagged for downstream analysis

-- TABLE: staging_products

-- Preview data
SELECT *
FROM staging_products;

-- Retrieve column structure
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'staging_products';

-- Identify NULL values
SELECT *
FROM staging_products
WHERE product_width_cm IS NULL
OR product_weight_g IS NULL
OR product_length_cm IS NULL
OR product_height_cm IS NULL
OR product_description_lenght IS NULL
OR product_photos_qty IS NULL
OR product_category_name IS NULL
OR product_name_lenght IS NULL
OR product_id IS NULL;

-- Quantify NULL distribution
SELECT
COUNT() AS nb_rows,
SUM(CASE WHEN product_width_cm IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS width_null_pct,
SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS weight_null_pct,
SUM(CASE WHEN product_length_cm IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS length_null_pct,
SUM(CASE WHEN product_height_cm IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS height_null_pct,
SUM(CASE WHEN product_description_lenght IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS description_null_pct,
SUM(CASE WHEN product_photos_qty IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS photos_null_pct,
SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS category_null_pct,
SUM(CASE WHEN product_name_lenght IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS name_null_pct,
SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT() AS id_null_pct
FROM staging_products;

-- Check product_id uniqueness
SELECT product_id
FROM staging_products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Result: product_id is unique (primary key)

-- Analyze product categories
SELECT product_category_name, COUNT(*) AS nb
FROM staging_products
GROUP BY product_category_name
ORDER BY nb DESC;

-- TABLE: staging_sellers

-- Preview data
SELECT *
FROM staging_sellers;

-- Retrieve column structure
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'staging_sellers';

-- Identify NULL values
SELECT *
FROM staging_sellers
WHERE seller_id IS NULL
OR seller_zip_code_prefix IS NULL
OR seller_city IS NULL
OR seller_state IS NULL;

-- Check uniqueness of seller_id
SELECT seller_id
FROM staging_sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- Validate zip code format
SELECT *
FROM staging_sellers
WHERE LENGTH(seller_zip_code_prefix) > 5;

-- Analyze city distribution
SELECT seller_city, COUNT(*) AS nb
FROM staging_sellers
GROUP BY seller_city
ORDER BY nb DESC;

-- Standardize text fields
UPDATE staging_sellers
SET seller_city = INITCAP(TRIM(seller_city));

UPDATE staging_sellers
SET seller_state = UPPER(TRIM(seller_state));

-- Result: Seller data is clean and standardized
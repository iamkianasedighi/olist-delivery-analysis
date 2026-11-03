\echo '01 / Row counts and key uniqueness'
SELECT 'orders' AS source, count(*) AS rows, count(DISTINCT order_id) AS unique_keys FROM raw.orders
UNION ALL SELECT 'customers', count(*), count(DISTINCT customer_id) FROM raw.customers
UNION ALL SELECT 'items', count(*), count(DISTINCT (order_id, order_item_id)) FROM raw.order_items
UNION ALL SELECT 'products', count(*), count(DISTINCT product_id) FROM raw.products
UNION ALL SELECT 'sellers', count(*), count(DISTINCT seller_id) FROM raw.sellers
UNION ALL SELECT 'reviews', count(*), count(DISTINCT review_id) FROM raw.reviews
UNION ALL SELECT 'translations', count(*), count(DISTINCT product_category_name) FROM raw.category_translation;

\echo '02 / Review grain: multiple reviews per order and repeated review IDs'
SELECT count(*) AS rows, count(DISTINCT order_id) AS reviewed_orders,
       count(DISTINCT review_id) AS distinct_review_ids
FROM raw.reviews;

\echo '03 / Foreign-key candidates without matching parents'
SELECT 'orders -> customers' AS relationship, count(*) AS missing_parent
FROM raw.orders o LEFT JOIN raw.customers c USING (customer_id) WHERE c.customer_id IS NULL
UNION ALL SELECT 'items -> orders', count(*) FROM raw.order_items i
LEFT JOIN raw.orders o USING (order_id) WHERE o.order_id IS NULL
UNION ALL SELECT 'items -> products', count(*) FROM raw.order_items i
LEFT JOIN raw.products p USING (product_id) WHERE p.product_id IS NULL
UNION ALL SELECT 'items -> sellers', count(*) FROM raw.order_items i
LEFT JOIN raw.sellers s USING (seller_id) WHERE s.seller_id IS NULL
UNION ALL SELECT 'reviews -> orders', count(*) FROM raw.reviews r
LEFT JOIN raw.orders o USING (order_id) WHERE o.order_id IS NULL;

\echo '04 / Invalid timestamp inputs (PostgreSQL 16+)'
SELECT field_name, count(*) FILTER (WHERE value IS NULL) AS missing,
       count(*) FILTER (WHERE value IS NOT NULL AND NOT pg_input_is_valid(value, 'timestamp without time zone')) AS invalid
FROM (
    SELECT field_name, nullif(value, '') AS value
    FROM raw.orders, LATERAL (VALUES
        ('purchase', order_purchase_timestamp), ('approved', order_approved_at),
        ('carrier', order_delivered_carrier_date), ('delivered', order_delivered_customer_date),
        ('estimated', order_estimated_delivery_date)) v(field_name, value)
    UNION ALL
    SELECT 'shipping_limit', nullif(shipping_limit_date, '') FROM raw.order_items
) dates GROUP BY field_name ORDER BY field_name;

\echo '05 / Invalid or missing item prices and freight'
SELECT count(*) FILTER (WHERE price IS NULL OR price !~ '^[0-9]+(\.[0-9]+)?$') AS invalid_price,
       count(*) FILTER (WHERE freight_value IS NULL OR freight_value !~ '^[0-9]+(\.[0-9]+)?$') AS invalid_freight
FROM raw.order_items;

\echo '06 / Status and delivery-date coverage'
SELECT order_status, count(*) AS orders,
       count(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing_actual_delivery,
       count(*) FILTER (WHERE order_estimated_delivery_date IS NULL) AS missing_estimate
FROM raw.orders GROUP BY order_status ORDER BY orders DESC;

\echo '07 / Suspicious delivered-before-purchased chronology'
WITH d AS (
    SELECT CASE WHEN pg_input_is_valid(order_purchase_timestamp, 'timestamp without time zone')
                THEN order_purchase_timestamp::timestamp END AS purchased,
           CASE WHEN pg_input_is_valid(order_delivered_customer_date, 'timestamp without time zone')
                THEN order_delivered_customer_date::timestamp END AS delivered
    FROM raw.orders
)
SELECT count(*) FILTER (WHERE delivered < purchased) AS delivered_before_purchase FROM d;

\echo '08 / Why direct items + reviews joins cannot be used to sum money'
SELECT count(*) AS joined_rows, count(DISTINCT o.order_id) AS distinct_orders
FROM raw.orders o LEFT JOIN raw.order_items i USING (order_id)
LEFT JOIN raw.reviews r USING (order_id);

\echo '09 / Category translation coverage'
SELECT count(*) AS products, count(*) FILTER (WHERE p.product_category_name IS NULL) AS uncategorised,
       count(*) FILTER (WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL) AS untranslated
FROM raw.products p LEFT JOIN raw.category_translation t USING (product_category_name);

\echo '10 / Examples of duplicated order IDs (HAVING)'
SELECT order_id, count(*) AS duplicate_rows FROM raw.orders
GROUP BY order_id HAVING count(*) > 1 ORDER BY duplicate_rows DESC LIMIT 10;

\echo '11 / Invalid review scores and review timestamps'
SELECT count(*) FILTER (WHERE review_score IS NULL OR review_score !~ '^[1-5]$') AS invalid_review_scores,
       count(*) FILTER (WHERE review_creation_date IS NOT NULL AND
           NOT pg_input_is_valid(review_creation_date, 'timestamp without time zone')) AS invalid_review_created,
       count(*) FILTER (WHERE review_answer_timestamp IS NOT NULL AND
           NOT pg_input_is_valid(review_answer_timestamp, 'timestamp without time zone')) AS invalid_review_answered
FROM raw.reviews;

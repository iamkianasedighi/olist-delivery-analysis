DROP SCHEMA IF EXISTS mart CASCADE;
CREATE SCHEMA mart;

-- Monetary values are parsed once; failed parses remain NULL for audit.
CREATE VIEW mart.items_clean AS
SELECT order_id, order_item_id, product_id, seller_id,
       CASE WHEN price ~ '^[0-9]+(\.[0-9]+)?$' THEN price::numeric END AS item_price,
       CASE WHEN freight_value ~ '^[0-9]+(\.[0-9]+)?$' THEN freight_value::numeric END AS freight_value,
       CASE WHEN pg_input_is_valid(shipping_limit_date, 'timestamp without time zone')
            THEN shipping_limit_date::timestamp END AS shipping_deadline
FROM raw.order_items;

-- One order can have several reviews; collapse them before joining to money.
CREATE VIEW mart.review_order AS
SELECT order_id, count(*) AS review_rows,
       avg(CASE WHEN review_score ~ '^[1-5]$' THEN review_score::numeric END) AS review_score,
       bool_or(CASE WHEN review_score ~ '^[1-5]$' THEN review_score::int <= 2 END) AS has_low_review
FROM raw.reviews GROUP BY order_id;

CREATE VIEW mart.order_delivery AS
WITH dated AS (
    SELECT o.order_id, o.customer_id, o.order_status,
           CASE WHEN pg_input_is_valid(order_purchase_timestamp, 'timestamp without time zone')
                THEN order_purchase_timestamp::timestamp END AS purchased_at,
           CASE WHEN pg_input_is_valid(order_delivered_carrier_date, 'timestamp without time zone')
                THEN order_delivered_carrier_date::timestamp END AS carrier_at,
           CASE WHEN pg_input_is_valid(order_delivered_customer_date, 'timestamp without time zone')
                THEN order_delivered_customer_date::timestamp END AS delivered_at,
           CASE WHEN pg_input_is_valid(order_estimated_delivery_date, 'timestamp without time zone')
                THEN order_estimated_delivery_date::timestamp END AS estimated_at
    FROM raw.orders o
), money AS (
    SELECT order_id, count(*) AS item_count, sum(item_price) AS merchandise_value,
           sum(freight_value) AS freight_value
    FROM mart.items_clean GROUP BY order_id
), base AS (
    SELECT d.*, c.customer_state, coalesce(m.item_count, 0) AS item_count,
           m.merchandise_value, m.freight_value, r.review_rows,
           r.review_score, r.has_low_review,
           (d.order_status = 'delivered' AND d.purchased_at IS NOT NULL
            AND d.delivered_at IS NOT NULL AND d.estimated_at IS NOT NULL
            AND d.delivered_at >= d.purchased_at) AS delivery_eligible
    FROM dated d LEFT JOIN raw.customers c USING (customer_id)
    LEFT JOIN money m USING (order_id) LEFT JOIN mart.review_order r USING (order_id)
)
SELECT *, CASE WHEN delivery_eligible THEN delivered_at::date > estimated_at::date END AS is_late,
          CASE WHEN delivery_eligible THEN greatest(delivered_at::date - estimated_at::date, 0) END AS days_late
FROM base;

-- Seller risk is attributed by seller-owned item value, not whole-order value.
CREATE VIEW mart.order_seller AS
SELECT i.order_id, i.seller_id, s.seller_state, o.purchased_at, o.delivery_eligible,
       o.is_late, o.days_late, sum(i.item_price) AS seller_item_value,
       bool_or(o.carrier_at > i.shipping_deadline) AS missed_shipping_deadline
FROM mart.items_clean i JOIN mart.order_delivery o USING (order_id)
LEFT JOIN raw.sellers s USING (seller_id)
GROUP BY i.order_id, i.seller_id, s.seller_state, o.purchased_at,
         o.delivery_eligible, o.is_late, o.days_late;

-- Category value is allocated by item; an order may appear in several categories.
CREATE VIEW mart.order_category AS
SELECT i.order_id, coalesce(t.product_category_name_english,
       p.product_category_name, '[unknown]') AS category,
       o.purchased_at, o.delivery_eligible, o.is_late, o.days_late,
       sum(i.item_price) AS category_item_value
FROM mart.items_clean i JOIN mart.order_delivery o USING (order_id)
LEFT JOIN raw.products p USING (product_id)
LEFT JOIN raw.category_translation t USING (product_category_name)
GROUP BY i.order_id, category, o.purchased_at, o.delivery_eligible,
         o.is_late, o.days_late;

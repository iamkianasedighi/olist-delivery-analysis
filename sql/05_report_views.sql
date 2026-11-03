CREATE VIEW mart.kpi_report AS
SELECT count(*) AS all_orders,
       count(*) FILTER (WHERE delivery_eligible) AS eligible_deliveries,
       count(*) FILTER (WHERE delivery_eligible AND is_late) AS late_deliveries,
       round(100.0 * count(*) FILTER (WHERE delivery_eligible AND is_late)
             / nullif(count(*) FILTER (WHERE delivery_eligible), 0), 2) AS late_rate_pct,
       round(avg(days_late) FILTER (WHERE delivery_eligible AND is_late), 2) AS avg_late_days,
       round(sum(merchandise_value) FILTER (WHERE delivery_eligible AND is_late), 2) AS late_item_value_brl
FROM mart.order_delivery;

CREATE VIEW mart.monthly_report AS
SELECT to_char(date_trunc('month', purchased_at), 'YYYY-MM') AS purchase_month,
       count(*) FILTER (WHERE order_status NOT IN ('canceled', 'unavailable') AND item_count > 0) AS placed_orders,
       round(sum(merchandise_value) FILTER (WHERE order_status NOT IN ('canceled', 'unavailable')), 2) AS placed_item_value_brl,
       count(*) FILTER (WHERE delivery_eligible) AS eligible_deliveries,
       count(*) FILTER (WHERE delivery_eligible AND is_late) AS late_deliveries,
       round(100.0 * count(*) FILTER (WHERE delivery_eligible AND is_late)
             / nullif(count(*) FILTER (WHERE delivery_eligible), 0), 2) AS late_rate_pct
FROM mart.order_delivery
WHERE purchased_at >= '2017-01-01' AND purchased_at < '2018-09-01'
GROUP BY 1;

CREATE VIEW mart.state_report AS
SELECT customer_state AS state, count(*) AS eligible_deliveries,
       count(*) FILTER (WHERE is_late) AS late_deliveries,
       round(100.0 * count(*) FILTER (WHERE is_late) / nullif(count(*), 0), 2) AS late_rate_pct,
       round(sum(merchandise_value) FILTER (WHERE is_late), 2) AS late_item_value_brl,
       round(avg(days_late) FILTER (WHERE is_late), 2) AS avg_late_days
FROM mart.order_delivery WHERE delivery_eligible
GROUP BY customer_state;

CREATE VIEW mart.category_report AS
SELECT category, count(*) AS eligible_order_category_pairs,
       count(*) FILTER (WHERE is_late) AS late_pairs,
       round(100.0 * count(*) FILTER (WHERE is_late) / nullif(count(*), 0), 2) AS late_rate_pct,
       round(sum(category_item_value), 2) AS item_value_brl,
       round(sum(category_item_value) FILTER (WHERE is_late), 2) AS late_item_value_brl
FROM mart.order_category WHERE delivery_eligible GROUP BY category;

CREATE VIEW mart.seller_report AS
SELECT seller_id, seller_state, count(*) AS eligible_order_seller_pairs,
       count(*) FILTER (WHERE is_late) AS late_pairs,
       round(100.0 * count(*) FILTER (WHERE is_late) / nullif(count(*), 0), 2) AS late_rate_pct,
       round(sum(seller_item_value) FILTER (WHERE is_late), 2) AS late_item_value_brl,
       count(*) FILTER (WHERE missed_shipping_deadline) AS late_handover_pairs
FROM mart.order_seller WHERE delivery_eligible GROUP BY seller_id, seller_state;

CREATE VIEW mart.review_report AS
SELECT CASE WHEN is_late THEN 'Late' ELSE 'On time' END AS delivery_group,
       count(*) AS reviewed_orders,
       round(avg(review_score), 2) AS avg_review_score,
       round(100.0 * count(*) FILTER (WHERE has_low_review)
             / nullif(count(*), 0), 2) AS low_score_pct
FROM mart.order_delivery
WHERE delivery_eligible AND review_score IS NOT NULL GROUP BY 1;

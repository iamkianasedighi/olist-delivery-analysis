\echo 'Q01 | Operational headline'
SELECT * FROM mart.kpi_report;

\echo 'Q02 | Which statuses have incomplete delivery data?'
SELECT order_status, count(*) AS orders, count(*) FILTER (WHERE NOT delivery_eligible) AS not_eligible
FROM mart.order_delivery GROUP BY 1 ORDER BY orders DESC;

\echo 'Q03 | Monthly value ordered, excluding canceled and unavailable orders'
SELECT purchase_month, placed_orders, placed_item_value_brl,
       round(100.0 * (placed_item_value_brl - lag(placed_item_value_brl) OVER (ORDER BY purchase_month))
             / nullif(lag(placed_item_value_brl) OVER (ORDER BY purchase_month), 0), 2) AS month_change_pct
FROM mart.monthly_report ORDER BY purchase_month;

\echo 'Q04 | Monthly delivery reliability'
SELECT purchase_month, eligible_deliveries, late_deliveries, late_rate_pct
FROM mart.monthly_report ORDER BY purchase_month;

\echo 'Q05 | Customer states: delay rate with adequate sample size'
SELECT * FROM mart.state_report WHERE eligible_deliveries >= 100
ORDER BY late_rate_pct DESC, eligible_deliveries DESC LIMIT 15;

\echo 'Q06 | Customer states: greatest associated item value'
SELECT state, late_deliveries, late_item_value_brl,
       round(100.0 * late_item_value_brl / nullif(sum(late_item_value_brl) OVER (), 0), 2) AS share_of_all_state_late_value_pct
FROM mart.state_report ORDER BY late_item_value_brl DESC LIMIT 15;

\echo 'Q07 | States with long late deliveries'
SELECT state, late_deliveries, avg_late_days
FROM mart.state_report WHERE late_deliveries >= 30 ORDER BY avg_late_days DESC LIMIT 10;

\echo 'Q08 | Category delay rate; restrict small samples'
SELECT category, eligible_order_category_pairs, late_pairs, late_rate_pct
FROM mart.category_report WHERE eligible_order_category_pairs >= 100
ORDER BY late_rate_pct DESC, late_pairs DESC LIMIT 15;

\echo 'Q09 | Categories with most value attached to late orders'
SELECT category, late_pairs, late_item_value_brl
FROM mart.category_report WHERE eligible_order_category_pairs >= 100
ORDER BY late_item_value_brl DESC NULLS LAST LIMIT 15;

\echo 'Q10 | Sellers: highest delivery delay rate'
SELECT seller_id, seller_state, eligible_order_seller_pairs, late_pairs, late_rate_pct
FROM mart.seller_report WHERE eligible_order_seller_pairs >= 30
ORDER BY late_rate_pct DESC, late_pairs DESC LIMIT 20;

\echo 'Q11 | Sellers: greatest late merchandise exposure'
SELECT seller_id, eligible_order_seller_pairs, late_pairs, late_item_value_brl
FROM mart.seller_report WHERE eligible_order_seller_pairs >= 30
ORDER BY late_item_value_brl DESC NULLS LAST LIMIT 20;

\echo 'Q12 | Shipping handover proxy: not proof of seller fault'
SELECT seller_id, eligible_order_seller_pairs, late_handover_pairs,
       round(100.0 * late_handover_pairs / nullif(eligible_order_seller_pairs, 0), 2) AS late_handover_pct
FROM mart.seller_report WHERE eligible_order_seller_pairs >= 30
ORDER BY late_handover_pct DESC NULLS LAST LIMIT 20;

\echo 'Q13 | Reviews of late versus on-time deliveries'
SELECT * FROM mart.review_report ORDER BY delivery_group;

\echo 'Q14 | Review score as delay length increases'
WITH grouped AS (
    SELECT CASE WHEN days_late = 0 THEN '0 - on time'
                WHEN days_late BETWEEN 1 AND 3 THEN '1 - 1 to 3 days'
                WHEN days_late BETWEEN 4 AND 7 THEN '2 - 4 to 7 days'
                ELSE '3 - 8+ days' END AS delay_band,
           review_score, has_low_review
    FROM mart.order_delivery WHERE delivery_eligible AND review_score IS NOT NULL
)
SELECT delay_band, count(*) AS reviewed_orders,
       round(avg(review_score), 2) AS mean_score,
       round(100.0 * count(*) FILTER (WHERE has_low_review) / count(*), 2) AS low_score_pct
FROM grouped GROUP BY delay_band ORDER BY delay_band;

\echo 'Q15 | Categories prioritised by rate and money, not rate alone'
WITH baseline AS (SELECT late_rate_pct FROM mart.kpi_report),
ranked AS (
    SELECT c.*, dense_rank() OVER (ORDER BY late_item_value_brl DESC NULLS LAST) AS value_rank
    FROM mart.category_report c WHERE eligible_order_category_pairs >= 100
)
SELECT category, eligible_order_category_pairs, late_rate_pct, late_item_value_brl, value_rank,
       CASE WHEN late_rate_pct > (SELECT late_rate_pct FROM baseline) AND value_rank <= 10
            THEN 'Investigate first' ELSE 'Monitor' END AS proposed_action
FROM ranked ORDER BY (late_rate_pct > (SELECT late_rate_pct FROM baseline) AND value_rank <= 10) DESC,
                     late_item_value_brl DESC NULLS LAST LIMIT 20;

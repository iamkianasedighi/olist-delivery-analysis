\echo 'RECONCILE / Core grain and monetary allocation'
WITH checks AS (
    SELECT 'one row per order' AS test_name,
           count(*) - count(DISTINCT order_id) AS violations FROM mart.order_delivery
    UNION ALL
    SELECT 'unqualified order assigned a delay', count(*)
    FROM mart.order_delivery WHERE NOT delivery_eligible AND is_late IS NOT NULL
    UNION ALL
    SELECT 'missing parsed item price', count(*) FROM mart.items_clean WHERE item_price IS NULL
    UNION ALL
    SELECT 'orphan item / order', count(*) FROM mart.items_clean i
    LEFT JOIN mart.order_delivery o USING (order_id) WHERE o.order_id IS NULL
), totals AS (
    SELECT (SELECT sum(item_price) FROM mart.items_clean) AS items,
           (SELECT sum(merchandise_value) FROM mart.order_delivery) AS orders,
           (SELECT sum(seller_item_value) FROM mart.order_seller) AS sellers,
           (SELECT sum(category_item_value) FROM mart.order_category) AS categories
)
SELECT test_name, violations, CASE WHEN violations = 0 THEN 'PASS' ELSE 'INVESTIGATE' END AS status
FROM checks
UNION ALL SELECT 'price allocation / order', abs(items - orders), CASE WHEN items = orders THEN 'PASS' ELSE 'INVESTIGATE' END FROM totals
UNION ALL SELECT 'price allocation / seller', abs(items - sellers), CASE WHEN items = sellers THEN 'PASS' ELSE 'INVESTIGATE' END FROM totals
UNION ALL SELECT 'price allocation / category', abs(items - categories), CASE WHEN items = categories THEN 'PASS' ELSE 'INVESTIGATE' END FROM totals;

\echo 'RECONCILE / Eligible deliveries must match state grouping'
SELECT (SELECT count(*) FROM mart.order_delivery WHERE delivery_eligible) AS order_count,
       (SELECT sum(eligible_deliveries) FROM mart.state_report) AS state_group_sum;

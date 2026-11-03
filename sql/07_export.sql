\set ON_ERROR_STOP on
-- Run from the repository root; these are grouped report tables, not raw customer data.
\copy (SELECT * FROM mart.kpi_report) TO 'exports/kpis.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM mart.monthly_report ORDER BY purchase_month) TO 'exports/monthly.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM mart.state_report ORDER BY late_item_value_brl DESC NULLS LAST) TO 'exports/states.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM mart.category_report ORDER BY late_item_value_brl DESC NULLS LAST) TO 'exports/categories.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM mart.seller_report ORDER BY late_item_value_brl DESC NULLS LAST) TO 'exports/sellers.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM mart.review_report ORDER BY delivery_group) TO 'exports/reviews.csv' WITH (FORMAT csv, HEADER true)

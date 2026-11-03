# SQL walkthrough — from raw files to a management decision

This document follows the actual execution order. Open the matching source file while reading; the explanations cover the code blocks and the meaning of the key expressions. PostgreSQL 16+ is assumed.

## `01_create_raw.sql` — preserve what the source actually says

**`DROP SCHEMA IF EXISTS raw CASCADE`** removes the old raw layer, including dependent views. Only use it in the dedicated `ecommerce_delivery` database. **`CREATE SCHEMA raw`** creates a separate namespace so imported CSVs cannot be confused with analytical outputs.

Each `CREATE TABLE raw.…` defines the column names **in the exact CSV header order**. Types are deliberately `text`: CSV files can contain missing or bad dates, blank amounts or odd ZIP-code prefixes. It is safer to inspect these than to make a load fail halfway through. PostgreSQL accepts `text` for all source columns. Source typos such as `product_name_lenght` are retained so the import lines up exactly.

There are **no primary/foreign-key constraints in `raw`**. That is a choice, not an oversight. A source audit is the right place to discover and quantify broken relationships; constraints would prevent those records from being loaded and examined.

**Verify:** `SELECT count(*) FROM raw.orders;` will return `0` immediately after table creation, before import. `\d raw.orders` in `psql` shows eight text columns.

**Common failures:** `permission denied for schema public` or `permission denied for database` means your PostgreSQL role lacks privileges. `relation already exists` usually means you skipped the schema reset or imported into a different database. Running the schema reset after import deletes imported data.

## `02_import_raw.sql` — local CSV loading

`\copy raw.orders FROM 'data/raw/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true)` reads the local file using the `psql` client, not the PostgreSQL server's filesystem. The same pattern is repeated for customers, items, products, sellers, reviews and category translation.

`FORMAT csv` handles quoting and commas inside text fields; `HEADER true` skips the first line. **It does not validate the header text or ordering.** The source header needs to match `docs/data_dictionary.md` before execution. The path is relative to the directory from which `psql` was started, not necessarily the SQL file's location. Run from the repository root.

`\set ON_ERROR_STOP on` makes the client halt on the first failed import instead of quietly continuing with six of seven tables.

**Verify:** Each successful line prints a `COPY n` message. Query `SELECT count(*) FROM raw.order_items;`. If you re-run this file without resetting `raw`, it **appends duplicate rows**. Reset `01_create_raw.sql` before a full reload.

**Common failures:** `No such file or directory` means the filenames/path are wrong; `extra data after last expected column` means the CSV does not match the expected structure; `invalid byte sequence for encoding UTF8` points to an encoding problem; partial imports can mean you ran the file twice.

## `03_quality_audit.sql` — investigate before interpreting

**Audit 01:** `COUNT(*)` is physical row count, while `COUNT(DISTINCT …)` tests the intended grain. The item key is a **composite tuple** `(order_id, order_item_id)`: the item position alone repeats across orders. This gives a quick duplicate warning.

**Audit 02:** Reviews have their own counts for total rows, distinct orders and distinct review IDs. Different numbers matter: a review table must not automatically be treated as one row per order or one unique row per `review_id`.

**Audit 03:** `LEFT JOIN … WHERE parent.id IS NULL` is an anti-join pattern. It counts missing parents rather than silently dropping child records through an `INNER JOIN`. These are source relationship problems, not legitimate zeros.

**Audit 04:** `pg_input_is_valid(value, 'timestamp without time zone')` safely checks whether PostgreSQL could interpret a timestamp. `LATERAL (VALUES …)` stacks five date columns into one field/value pair per record so their missing/invalid counts can be compared in one result. The item shipping deadline is included separately. If your PostgreSQL version is older than 16, this function will not exist.

**Audit 05:** The pattern `^[0-9]+(\.[0-9]+)?$` accepts simple non-negative decimal strings such as `14`, `14.2`, `14.25`. It does not accept commas, currency symbols, negative amounts or scientific notation; any unexpected value becomes a data-quality question, not an automatic guess.

**Audit 06:** A missing delivered date for a canceled order is not the same problem as a missing delivered date for an order marked delivered. Grouping by `order_status` prevents a misleading all-order null percentage.

**Audit 07:** Date parsing happens inside `CASE` so invalid inputs do not cause a hard cast error. Counting `delivered < purchased` detects impossible chronology that would otherwise distort delay metrics.

**Audit 08:** Joining order items and reviews directly illustrates _multiplication of rows_. Comparing joined row count to distinct order count shows why counting `*` or summing item prices at that join grain is unsafe.

**Audit 09:** Missing Portuguese categories and missing English translations are different. Untranslated categories can fall back to Portuguese; truly missing categories are labeled `[unknown]` in the analytical view.

**Verify:** investigate nonzero duplicate counts for expected primary keys, broken item relationships, invalid financial values and invalid dates. The audit identified missing delivery dates and repeated review records. All seven reconciliation checks subsequently passed.

## `04_build_marts.sql` — three grains, not one giant table

**`mart.items_clean`** parses amount fields using `CASE WHEN … ~ regex THEN value::numeric END`. If a value fails the numeric pattern, the analytical field is `NULL`, so the quality/reconciliation checks can surface it. `shipping_limit_date` receives the same safe timestamp treatment as raw orders.

**`mart.review_order`** uses `GROUP BY order_id` to return exactly one row per reviewed order. `AVG` represents the order's mean valid review score if there are multiple reviews. `BOOL_OR` answers whether _any_ valid score for that order is 1 or 2. Treating an order as having a low review if one review is low is transparent; it differs from classifying the average rating as low.

**`mart.order_delivery`** consists of three CTEs and a final `SELECT`:

- `dated` validates/casts purchase, carrier, actual and estimated timestamps. Bad source values turn into NULL rather than aborting the whole view.
- `money` groups the item table **before the join** using `GROUP BY order_id`, so each order receives one merchandise value and item count.
- `base` joins the one-row-per-order records to the (expected unique) customer row, order-level money and order-level review. It marks `delivery_eligible` only when order status and date requirements are met.
- The final `CASE` assigns `is_late` and `days_late` only to eligible orders. A boolean null means **not measurable**, not on time. Casting to `::date` enforces the calendar-day contract.

**`mart.order_seller`** joins item rows to the order outcome, then groups by `(order_id, seller_id)`. One order shared by three sellers produces three seller records. Each has the seller's own item value, but all share the order-level delivery outcome. `BOOL_OR(carrier_at > shipping_deadline)` is a **deadline proxy** using the order-level carrier date; not a finding of seller fault.

**`mart.order_category`** groups by `(order_id, category)`, with English translation where available and a fallback if not. This preserves the sum of item prices across categories without crediting the same _whole order value_ to every category. Any category-name collisions or duplicated product/translation joins should be caught by reconciliation.

**Verify:** `SELECT count(*) FROM mart.order_delivery;` should equal source order rows when `orders` keys are unique and customer keys do not duplicate. `SELECT count(*) - count(DISTINCT order_id) FROM mart.order_delivery;` should return zero. Run `08_reconciliation.sql` after building the reports.

## `05_report_views.sql` — reusable definitions for Excel

`mart.kpi_report` is the **overall** one-row scorecard. The PostgreSQL `FILTER (WHERE …)` syntax counts late orders only within eligible delivery records. `NULLIF(denominator, 0)` ensures an empty segment gives NULL rather than a division-by-zero error. `ROUND(…, 2)` improves presentation without changing the stored source values.

`mart.monthly_report` groups orders by **purchase month** using `date_trunc` and `to_char`. The cohort excludes canceled/unavailable statuses when calculating placed item value. Its late rate counts only delivery-eligible orders in the corresponding purchase month. The 2017-01 through 2018-08 window limits extreme edges of this historical sample, not a claim of complete follow-up.

`mart.state_report` groups eligible orders by destination state. It measures late-rate, late-order count, associated item value and mean days late. States with different volumes should not be ranked on rate alone.

`mart.category_report` counts **eligible order–category pairs** and their category-owned item value. `mart.seller_report` does the same for eligible order–seller pairs, plus the shipping-handover proxy. Neither pair count is the count of unique retailer orders across all categories/sellers.

`mart.review_report` compares orders with a valid review summary, separating `Late` and `On time`. No-review orders do not enter the average score or low-score rate. The separate denominator `reviewed_orders` makes that exclusion visible.

**Verify:** `SELECT * FROM mart.kpi_report;` should return one record; `SELECT * FROM mart.review_report;` typically returns up to two groups. `SELECT sum(eligible_deliveries) FROM mart.state_report;` must match eligible orders from `mart.order_delivery`.

## `06_analysis.sql` — what each investigation contributes

| Query | SQL idea                                        | Business use                                        | Interpretation warning                                |
| ----- | ----------------------------------------------- | --------------------------------------------------- | ----------------------------------------------------- |
| Q01   | `SELECT` from validated KPI view                | Establish overall reference rate and value exposure | No financial loss claim                               |
| Q02   | `GROUP BY`, conditional aggregate               | Show exclusions by order status                     | Do not call unshipped orders on time                  |
| Q03   | `LAG` window                                    | Compare placed item value month over month          | Order value, not recognized revenue                   |
| Q04   | Monthly rates                                   | Look for changes across purchase cohorts            | Historic end-of-window censoring                      |
| Q05   | `WHERE`, rank by late rate                      | Highlight high-rate customer states                 | At least 100 eligible orders                          |
| Q06   | `SUM … OVER ()`                                 | Compare states' relative value exposure             | Geographic value is not a delay cause                 |
| Q07   | Conditional `HAVING` equivalent via view filter | Find states with longer late deliveries             | At least 30 late orders                               |
| Q08   | Order-category summary                          | Compare category late rates                         | At least 100 category pairs                           |
| Q09   | Value ranking                                   | Prioritise categories by affected item value        | A multi-category order appears in several pair groups |
| Q10   | Seller rate ranking                             | Identify seller groups for review                   | At least 30 seller pairs; no fault claim              |
| Q11   | Seller value ranking                            | See where affected seller item value sits           | Not refunds, penalty or loss                          |
| Q12   | Shipping deadline proxy                         | Explore dispatch/handover process                   | Order-level carrier timestamp                         |
| Q13   | Grouped review comparisons                      | See satisfaction association                        | Not proof that lateness caused low ratings            |
| Q14   | CTE + `CASE` bands                              | Test relationship with severity of delay            | Missing reviews excluded                              |
| Q15   | CTE, subquery, `DENSE_RANK`, `CASE`             | Prioritise high-rate/high-value categories          | Priority means **investigate**, not fix proven cause  |

The analytic queries cover `JOIN`, aggregation, `HAVING` logic in source audits, `CASE`, CTEs, scalar subqueries, window functions, time operations and ranking. Q15 uses the observed overall rate as a benchmark plus top-ten value rank, rather than arbitrarily labeling every high-delay category a priority.

## `07_export.sql` — handoff from SQL to Excel

Each `\copy (SELECT …)` writes one view to a CSV with headers. Running from the repository root places the files in `exports/`. This intentionally exports **aggregated tables**, not row-level customers, purchase IDs or personal comments. The tables are enough to make four management visuals and answer the six questions.

**Verify:** `Get-Content .\exports\monthly.csv -TotalCount 3` shows the header and first two months. If `\copy` says permission denied, check your local `exports/` directory permissions. Excel may treat a decimal point differently under German regional settings; use **Data → From Text/CSV** and set the numeric locale as appropriate.

## `08_reconciliation.sql` — the test that protects the money

The `checks` CTE counts (a) duplicate order grain in the final order view, (b) delay statuses assigned to ineligible orders, (c) invalid/missing item prices and (d) item rows missing a valid order parent. All should have zero violations.

`totals` computes the same item-price total from **four independently aggregated routes**: raw typed items, order rollup, seller allocation and category allocation. The three differences should be zero. This catches the most damaging silent SQL mistake in this project: inflated revenue-like amounts after many-to-many joins.

The last statement compares the total eligible order count to the sum across customer states. Any difference indicates a bad join, duplication or aggregation assumption. Do not conceal a failure by replacing NULL with zero or deleting a category until it reconciles.

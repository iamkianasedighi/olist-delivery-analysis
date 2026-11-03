# Analytical methodology and decision rules

## Populations

**All orders** = every row in the raw `orders` file; use for import coverage, not delivery-rate denominators.

**Eligible deliveries** = orders whose status is `delivered`, purchase, delivery and estimated-delivery timestamps parse, and actual delivery is no earlier than purchase. Records with missing or invalid timestamps are kept but excluded from delivery KPIs, and the exclusion count is visible in SQL Q02.

**Monthly placed-value cohort** = orders purchased between 2017-01-01 and 2018-08-31 inclusive, with status other than `canceled` or `unavailable`. `placed_item_value_brl` is **not net recognised revenue**. Open/unfulfilled but not canceled orders can contribute. Monthly late rates are attributed to purchase month, not delivery month; recent cohorts may still be right-censored.

## Definitions and calculations

1. `is_late` is true only if `delivered_at::date > estimated_at::date`. Equal calendar date is on time. Comparing timestamps instead would treat deliveries hours later on the promised date as late; this project intentionally avoids that.
2. `late_rate_pct = 100 * late eligible orders / eligible deliveries`. `NULLIF` protects division by zero.
3. `days_late = greatest(actual_date - estimated_date, 0)`. Mean late days includes only **late** eligible orders, not zeros for on-time orders.
4. `merchandise_value = SUM(order_items.price)` at order grain. No shipping, payment validation, taxes, cancellation adjustments, refunds or profit margin.
5. `late_item_value_brl = sum(merchandise_value)` for orders marked late. It measures value *associated* with delay. Never call it loss, revenue lost, financial damage or churn.
6. Order/seller and order/category groupings are independent. All parts of a mixed order share the order-level delivery outcome, but the item prices are assigned only to the corresponding seller/category. These groups sum to the total included item value **if** foreign-key and join-uniqueness tests pass.
7. Reviews are collapsed by `order_id` to a mean valid score and whether *any* reviewed score was 1 or 2; those reviewed orders are compared across late/on-time groups. Incomplete review coverage and selection effects prevent causal claims.
8. Seller shipping deadline proxy is true when carrier timestamp is later than **at least one** seller item's shipping deadline. The recorded carrier timestamp is order-level; the measure is a lead to check, not an attribution of fault.

## Data-quality gates

- Verify one source row per `order_id`, one per `customer_id`, one per `(order_id, order_item_id)`, and expected key uniqueness of product/seller/translation.
- Count reviews independently; do not force `review_id` unique.
- Quantify missing and malformed timestamps. Separate missing timestamps from structurally impossible chronology.
- Check for orphan item references; missing product/seller references would compromise segment allocations.
- Validate prices and freight; casting invalid source values to NULL must trigger investigation.
- Compare total source item value with its order/seller/category allocations. **Zero mismatch** is required before publishing sums.
- Compare eligible delivered orders to the sum of delivery counts across destination states.

Audit is not automatic deletion. Significant anomalies require a documented decision; the build does not silently treat every issue as harmless.

## Recommended action framework

| Finding pattern | Action to test | Evidence still needed |
|---|---|---|
| High late rate, adequate volume, high affected item value | Prioritise an operational deep dive | Transport routes, carrier IDs, shipping SLAs, cost of intervention |
| High delayed-order value but average delay rate | Consider volume-targeted improvements | Feasibility, fulfilment route, actual cost |
| Higher missed shipping-deadline proxy | Review seller/handover process | Seller dispatch events and carrier acceptance times |
| Late orders have more low reviews | Evaluate proactive tracking/notifications | Controlled experiment; confirmation that messaging changes satisfaction |
| Small sample high rate | Monitor; do not escalate from rate alone | More observations / uncertainty bounds |

Rankings are descriptive and confounded by category mix, customer geography, shipping method, season and marketplace practices. Thresholds (`state ≥100`, `seller ≥30`, `category ≥100`) are operational filters, not a significance test.

## What cannot be concluded

No proven seller fault, cause of delivery delay, refund amount, net revenue, margin erosion, churn, cost savings, or contemporary Olist performance. The data do not establish whether any proposed action will work. A management recommendation must be framed as a **prioritised investigation**, not a guarantee.

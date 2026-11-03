# Raw-source data dictionary

Source: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce (Olist; CC BY-NC-SA 4.0). These are **published CSV headers**, not guessed SQL column names. Header inspection and row counts must still be verified for the downloaded version.

| File | Primary grain | Header order |
|---|---|---|
| `olist_orders_dataset.csv` | `order_id` | `order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date` |
| `olist_order_items_dataset.csv` | `(order_id, order_item_id)` | `order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value` |
| `olist_customers_dataset.csv` | `customer_id` | `customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state` |
| `olist_products_dataset.csv` | `product_id` | `product_id, product_category_name, product_name_lenght, product_description_lenght, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm` |
| `olist_sellers_dataset.csv` | `seller_id` | `seller_id, seller_zip_code_prefix, seller_city, seller_state` |
| `olist_order_reviews_dataset.csv` | Review record, not unique review ID assumed | `review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp` |
| `product_category_name_translation.csv` | Portuguese category name | `product_category_name, product_category_name_english` |

**Important:** The source really spells `product_name_lenght` and `product_description_lenght` this way. Do not correct those column names during raw import.

### Relationships

`orders.customer_id → customers.customer_id`; `order_items.order_id → orders.order_id`; `order_items.product_id → products.product_id`; `order_items.seller_id → sellers.seller_id`; `reviews.order_id → orders.order_id`; `products.product_category_name → category_translation.product_category_name`.

Not every order is delivered, not every order has line items or reviews, and a review ID should **not** be assumed unique without testing. The audit quantifies all of this for your version. Do not enforce foreign keys on the raw source until you know whether the actual file satisfies them.

### Field and metric meanings

- `order_purchase_timestamp`: placed/purchased date used for cohort and value trends.
- `order_delivered_customer_date`: actual delivery timestamp; only used when order status and chronology meet eligibility rules.
- `order_estimated_delivery_date`: estimate/promise proxy; measured in **calendar days**.
- `order_delivered_carrier_date`: order-level timestamp used for shipping-handover proxy; may not describe a particular seller's actions.
- `order_items.price`: BRL per item row. Excludes `freight_value`; no verified gross margin or net revenue.
- `shipping_limit_date`: shipping deadline tied to item record.
- `review_score`: observed score 1–5, potentially multiple rows per order.
- `customer_state`: delivery-destination state, not a reason for delay.

### Grain audit example

Consider one order with two item rows and two review rows. Joining both child tables to orders directly yields **four joined rows**. A plain `SUM(item.price)` would double the true item value. The project groups items by order and reviews by order independently before joining to the single order row.

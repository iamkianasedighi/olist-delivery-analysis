# Case Study: Where Should Delivery Operations Investigate First?

## The business problem

An overall late-delivery rate tells a company how often something goes wrong, but not where to start fixing it.

I used Olist's historical e-commerce data to investigate which regions experienced the most delays, how much merchandise value was associated with late deliveries, and how delivery performance related to customer reviews.

The goal was to identify where an operations team should investigate first.

## Data and methodology

| Area                | Description                                           |
| ------------------- | ----------------------------------------------------- |
| Dataset             | Olist Brazilian E-Commerce Public Dataset (2016–2018) |
| Total orders        | 99,441                                                |
| Eligible deliveries | 96,470                                                |
| Tools               | PostgreSQL, SQL, Google Sheets                        |
| Output              | SQL analysis, validated metrics, management dashboard |

I started by auditing the raw data before calculating delivery performance. The checks identified 8 orders marked `delivered` without an actual delivery date, 610 products without a category, and 99,224 review rows covering 98,673 distinct orders.

The review data also contained repeated IDs and one-to-many relationships that could inflate calculations. To handle this, I built analytical views at the appropriate level: one row per order, order–seller pair, or order–category pair. Item values and reviews were aggregated before joining them to other tables.

**All seven SQL reconciliation checks passed**, including checks that merchandise values remained consistent across the analytical views.

## Key findings

| Metric                                            |         Result |
| ------------------------------------------------- | -------------: |
| Eligible deliveries                               |         96,470 |
| Late deliveries                                   |          6,534 |
| Late delivery rate                                |          6.77% |
| Average delay among late orders                   |     10.62 days |
| Merchandise value associated with late deliveries | BRL 985,924.34 |

### 1. Geographic differences stand out more than product categories

Delivery performance varied substantially between destinations.

| State               | Eligible deliveries | Late rate |
| ------------------- | ------------------: | --------: |
| Alagoas (AL)        |                 397 |    21.41% |
| Maranhão (MA)       |                 717 |    17.43% |
| Ceará (CE)          |               1,279 |    13.76% |
| Bahia (BA)          |               3,256 |    12.16% |
| Rio de Janeiro (RJ) |              12,350 |    12.11% |
| São Paulo (SP)      |              40,494 |     4.49% |

RJ stands out because it combines a relatively high delay rate with substantial order volume: **1,495 late deliveries**. If RJ had matched the overall rate of 6.77%, it would have recorded approximately **660 fewer late deliveries**. This is a comparison against a benchmark, not a forecast of achievable improvement.

SP presents a different picture. Its delay rate is much lower, but its large order volume means it accounts for the greatest merchandise value associated with late orders (BRL 269,383).

By comparison, the 15 categories with the most late-order value all had delay rates between **5.4% and 8.1%**, close to the 6.77% overall average.

**What surprised me:** I expected product categories to show bigger differences, particularly categories involving furniture or electronics. Instead, the geographic differences were much more noticeable. That changed where I would focus the investigation.

### 2. Delivery performance deteriorated during specific periods

Three months stand out:

| Purchase month | Late deliveries | Late rate |
| -------------- | --------------: | --------: |
| November 2017  |             904 |    12.40% |
| February 2018  |             926 |    14.13% |
| March 2018     |           1,328 |    18.96% |

November 2017 also had unusually high purchase volume, making it worth examining alongside the February–March 2018 spike.

**Business implication:** Investigate order volumes, fulfilment capacity, dispatch times, and carrier performance during these periods to understand what changed operationally.

### 3. Longer delivery delays are associated with worse customer reviews

| Delivery timing | Average review score | Share of 1–2-star reviews |
| --------------- | -------------------: | ------------------------: |
| On time         |             4.29 / 5 |                     9.31% |
| 1–3 days late   |             3.29 / 5 |                    32.18% |
| 4–7 days late   |             2.11 / 5 |                    67.68% |
| 8+ days late    |             1.70 / 5 |                    79.36% |

Orders delivered on time received an average review score of 4.29, while orders delayed by eight or more days averaged only 1.70.

Delivery reliability is strongly associated with customer satisfaction in this dataset. However, reviews can also reflect product quality, communication, and other service issues. The relationship is correlational, not proof that delays alone caused lower scores.

## Recommended business actions

| Priority | Action                                                      | Reason                                                               |
| -------- | ----------------------------------------------------------- | -------------------------------------------------------------------- |
| 1        | Investigate routes into Rio de Janeiro                      | High delay rate combined with 1,495 affected deliveries              |
| 2        | Review transit performance in high-delay states             | Identify unreliable routes and unrealistic delivery estimates        |
| 3        | Examine fulfilment and carrier capacity during peak periods | Understand the November 2017 and February–March 2018 spikes          |
| 4        | Test proactive communication for delayed orders             | Evaluate whether better delivery updates improve customer experience |

Seller-level findings can help narrow these investigations, but delayed carrier handovers should not automatically be treated as proof of seller responsibility.

### Measuring whether changes work

I would monitor late delivery rates by destination, weekly late-order counts, average delay length, and customer review scores. Where carrier data is available, I would also compare carrier-level performance.

Any improvement should be evaluated against comparable periods and order volumes rather than a single overall percentage.

## Limitations

The analysis uses historical data from 2016–2018 and does not represent Olist's current operations.

The dataset lacks sufficient carrier-level performance, refund, margin, and customer-support cost information to establish the causes or financial consequences of delivery delays.

In particular, **BRL 985,924.34 represents merchandise value associated with late orders, not confirmed lost revenue or financial damage**.

Geographic and category comparisons are observational. Orders involving multiple sellers or categories can appear in more than one segment, so segment-level order counts are not necessarily additive.

## Technical implementation

The analysis can be reproduced using the SQL scripts in the repository:

| File                    | Purpose                                                 |
| ----------------------- | ------------------------------------------------------- |
| `03_quality_audit.sql`  | Validate data quality and relationships                 |
| `04_build_marts.sql`    | Build analytical views with consistent levels of detail |
| `05_report_views.sql`   | Calculate business metrics                              |
| `06_analysis.sql`       | Run 15 analytical investigations                        |
| `08_reconciliation.sql` | Verify totals and calculations                          |
| `07_export.sql`         | Export six CSV summaries for reporting                  |

The results are presented in the management workbook and dashboard. Setup instructions and methodology are available in the [main README](../README.md).

## Data source

[Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), licensed under CC BY-NC-SA 4.0.

Independent portfolio project; not affiliated with Olist.

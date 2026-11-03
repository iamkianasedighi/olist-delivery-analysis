# Management Brief: Delivery Performance

_Short summary for operations managers. Full investigation in [case_study.md](case_study.md)._

**Dataset:** Olist Brazilian E-Commerce, 2016–2018  
**Focus:** Delivery reliability and operational priorities

## Executive summary

Of 96,470 eligible deliveries, **6,534 (6.77%) arrived late**, with an average delay of 10.62 days among late orders. These deliveries represented BRL 985,924 in merchandise value, not confirmed financial losses.

The clearest findings concern geographic differences, specific periods of poor delivery performance, and the relationship between delays and customer reviews.

## Where to focus

| Finding            | Evidence                                     | Priority |
| ------------------ | -------------------------------------------- | -------- |
| Rio de Janeiro     | 12.11% late across 12,350 deliveries         | High     |
| High-delay states  | AL 21.41%, MA 17.43%, CE 13.76%              | High     |
| Delivery spikes    | Nov 2017: 12.40%; Feb–Mar 2018: 14.13–18.96% | High     |
| Product categories | Top 15 by late-order value: 5.4–8.1% late    | Lower    |

**Rio de Janeiro is the strongest starting point.** Its combination of delivery volume and above-average delay rate makes it a practical investigation target. At the national rate of 6.77%, RJ would have recorded approximately 660 fewer late deliveries.

Product categories show smaller differences by comparison. Broad category-level interventions are therefore a lower priority.

## Customer impact

Orders arriving **8+ days late averaged 1.70 stars**, and 79% received a 1–2-star review.

| Delivery timing | Average review |
| --------------- | -------------: |
| On time         |       4.29 / 5 |
| 1–3 days late   |       3.29 / 5 |
| 4–7 days late   |       2.11 / 5 |
| 8+ days late    |       1.70 / 5 |

This association makes delivery reliability relevant beyond logistics performance.

## Recommended actions

**1. Investigate high-delay destinations.** Start with Rio de Janeiro, followed by Alagoas, Maranhão and Ceará. Examine routes, transit times, fulfilment handovers and delivery estimates.

**2. Examine the delivery spikes.** Compare November 2017 and February–March 2018 with better-performing months to identify operational changes or capacity constraints.

**3. Monitor customer outcomes.** Track delivery performance alongside review scores and low-rating frequency to evaluate whether operational improvements correspond with better customer experiences.

## Decision requested

Prioritise an operational investigation of RJ, selected high-delay states and the identified delivery spikes.

Determine whether problems originate in dispatch, carrier transit, delivery estimates or a combination of factors before assigning corrective actions.

Measure progress through late delivery rate, affected order volume, average days late and customer review trends.

## Data confidence and limitations

All seven SQL reconciliation checks passed. Order-level and segment-level calculations were validated to prevent double-counting.

The dataset is historical and lacks sufficient carrier, refund and cost information to establish root causes or financial losses. Recommendations are investigative priorities, not proven solutions.

**Source:** [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — CC BY-NC-SA 4.0.

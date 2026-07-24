# Olist E-Commerce dbt Analytics

A dbt transformation and analytics layer built on the
[Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
(Kaggle). The project models 100k+ orders across 9 raw tables into a
tested, documented analytics layer that answers real business questions
about seller health, customer retention, delivery performance, and
category revenue.

## Live Dashboard

[View the Olist Analytics Dashboard](https://app.snowflake.com/streamlit/oudjpmi/tk51428/#/apps/luhcekb2tqkhnfo4p4jg)

Built with Snowflake Streamlit — queries the mart models directly.

---

## Business Questions

### Which sellers are at risk of churning?

Using rolling 90-day windows, sellers are scored across three signals:
order volume, average review score, and delivery delays. Each signal is
compared between the most recent 90 days and the prior 90 days, and
sellers are tiered into high, medium, and low churn risk based on how
many signals are worsening simultaneously.

Out of 2,032 active sellers:
- **430 are high risk** — volume dropped from 17.5 to 7.4 orders on
  average, lowest review scores at 3.79, highest delays at 11.6 days
- **1,121 are medium risk** — one signal worsening, mostly volume-related
- **481 are low risk** — actually growing, best scores, lowest delays

The high-risk segment is not just declining in one area. It is declining
across multiple signals at once, which makes it a stronger churn indicator
than volume alone.

### Are customers coming back?

97% of customers never place a second order. Out of 96,096 unique
customers, 93,333 ordered exactly once. Only 47 customers qualify as
loyal (4 or more orders).

The data also shows that loyal customers are worth 5x more in total
spend ($777 vs $161 average) — which means even a small improvement in
retention would have a disproportionate impact on revenue.

One non-obvious finding: returning customers spend less per order ($147)
than one-time buyers ($161). This could suggest discount-seeking behavior
or smaller repeat purchases, and is worth investigating further.

### Which delivery routes have the worst performance?

The worst corridor by average delivery time is PR to AL at 31 days with
only 67% on-time rate. But the more interesting finding is the difference
between "long and unreliable" vs "long but reliable" routes.

SP to AM averages 26 days but has a 96% on-time rate — meaning the
distance is accounted for in the delivery estimate. MA to ES and RS to MA
have lower on-time rates despite shorter routes, which points to a
mismatch between estimated and actual delivery time rather than a distance
problem.

### Which categories drive the most revenue?

Health & beauty leads in total revenue ($1.26M) while watches & gifts has
the highest average item price ($201). Housewares and auto have the
highest cancellation rates (0.70% and 0.71%) despite solid review scores,
which could indicate fulfillment issues rather than product dissatisfaction.

---

## Data Model

```
RAW (Snowflake)
└── STAGING (dbt views — one model per source table)
    └── MARTS
        ├── CORE
        │   ├── fct_orders          (one row per order)
        │   ├── fct_order_items     (one row per item within an order)
        │   ├── dim_customers       (one row per customer profile)
        │   ├── dim_sellers         (one row per seller)
        │   └── dim_products        (one row per product)
        └── ANALYTICS
            ├── mart_seller_churn_risk
            ├── mart_customer_retention
            ├── mart_delivery_corridor
            └── mart_category_performance
```

---

## Modeling Decisions

### Why two fact tables?

`orders` and `order_items` describe different things. `fct_orders` is
the central fact — each row is a purchase with a timestamp, a status,
and delivery information. `fct_order_items` is a separate fact because
each row is a specific item within that order, with a price and freight
value you can sum. An order can have multiple items, so they can't live
in the same table without duplicating the order-level data.

### Why are payments part of fct_orders and not their own model?

Payments are an extension of orders. When looking at an order, you
naturally want to know how much was paid and by what method. The
payments table already links back to orders via `order_id`, so
aggregating payment totals directly into `fct_orders` keeps that
information where it's most useful without adding an unnecessary model.

### Why deduplicate reviews?

`fct_orders` is supposed to be one row per order. Some orders in the
source data have more than one review, which means a simple join would
cause the same order to appear multiple times. That breaks the whole
point of the fact table since any count or sum on it would return wrong
numbers. The fix keeps only the most recent review per order using
Snowflake's `QUALIFY` clause.

### A few other things worth noting

**`customer_id` is not a stable customer identifier.** In this dataset,
a new `customer_id` is generated for every order. A customer who orders
three times gets three different IDs. `customer_unique_id` is the actual
person-level identifier and is preserved in `dim_customers` for that
reason. The customer retention mart depends on this distinction.

**The geolocation table has multiple records per zip code.** Coordinates
are averaged at the zip level before joining to avoid duplicating rows
in the dimension tables.

**`product_category_name_translation` is not its own dimension.** It is
a Portuguese-to-English lookup for a single column. It gets joined
directly into `dim_products` and does not appear in the marts layer on
its own.

---

## Testing

**Staging layer - generic tests**
Uniqueness and not_null on primary keys, not_null on foreign keys,
accepted_values for order status and review scores.

**Marts layer - relationship tests**
Every foreign key in the fact tables is tested against its dimension.
`customer_id` in `fct_orders` must exist in `dim_customers`. `product_id`
and `seller_id` in `fct_order_items` must exist in their respective dims.

**Singular tests - business logic**
Three custom SQL tests:
- Item prices must be greater than zero
- Payment values must be greater than or equal to zero
  (zero is valid since some orders are fully covered by vouchers)
- Delivered orders must have a delivery timestamp
  (set to `severity: warn` since 8 records in the source data fail this,
  which is a known source data issue, not a transformation bug)

---

## Stack

- **Transformation:** dbt-fusion 2.0
- **Warehouse:** Snowflake
- **Dashboard:** Snowflake Streamlit
- **Source data:** 9 CSV files loaded into `OLIST.RAW`
- **Architecture:** staging -> marts (two-layer)

---

## How to Run

```bash
dbt debug    # test connection
dbt run      # build all models
dbt test     # run all tests
dbt build    # models + tests in DAG order
```

**Expected result:**
62 total | 61 success | 1 warn
*(the warn is the 8 delivered orders missing timestamps in the source data)*
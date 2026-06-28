That's exactly the voice. Now I can write it.

```markdown
# Olist E-Commerce dbt Project

A dbt transformation layer built on the
[Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
(Kaggle). Nine raw CSV files loaded into Snowflake, modeled into a
clean, tested, and documented analytics layer using dbt-fusion.

This is a transformation project, not an analysis project. The focus
is on how the data is structured and why — not what the final numbers look like.

---

## Stack

- **Transformation:** dbt-fusion 2.0
- **Warehouse:** Snowflake
- **Source data:** 9 CSV files loaded into `OLIST.RAW`
- **Architecture:** staging → marts (two-layer)

---

## Data Model

```
RAW (Snowflake)
└── STAGING (dbt views)
    └── MARTS (dbt tables)
        ├── fct_orders         (one row per order)
        ├── fct_order_items    (one row per item within an order)
        ├── dim_customers      (one row per customer profile)
        ├── dim_sellers        (one row per seller)
        └── dim_products       (one row per product)
```

---

## Modeling Decisions

### Why two fact tables?

`orders` and `order_items` describe different things.

`fct_orders` is the central fact — each row is a purchase, with a
timestamp, a status, and delivery information. `fct_order_items` is a
separate fact because each row is a specific item within that order,
with a price and freight value you can sum. An order can have multiple
items, so they can't live in the same table without duplicating the
order-level data.

### Why are payments part of fct_orders and not their own model?

Payments are essentially an extension of orders. When looking at an
order, you naturally want to know how much was paid and by what method
— and the payments table already links back to orders via `order_id`.
Aggregating payment totals directly into `fct_orders` (total value,
distinct payment types, max installments) keeps that information where
it's most useful without adding an unnecessary model.

### Why deduplicate reviews?

`fct_orders` is supposed to be one row per order. Some orders in the
source data have more than one review, which means a simple join would
cause the same order to appear multiple times. That breaks the whole
point of the fact table — any count or sum on it would return wrong
numbers. The fix keeps only the most recent review per order using
Snowflake's `QUALIFY` clause.

### A few other things worth noting

**`customer_id` is not a stable customer identifier.** In this dataset,
a new `customer_id` is generated for every order. A customer who orders
three times gets three different IDs. `customer_unique_id` is the actual
person-level identifier and is preserved in `dim_customers` for that reason.

**The geolocation table has multiple records per zip code.** Customers
and sellers both join to geolocation via zip code, so coordinates are
averaged at the zip level before joining to avoid duplicating rows in
the dimension tables.

**`product_category_name_translation` is not its own dimension.** It's
a Portuguese-to-English lookup for a single column. It gets joined
directly into `dim_products` and doesn't appear in the marts layer on
its own.

---

## Testing

**Staging layer — generic tests**
Uniqueness and not_null on primary keys, not_null on foreign keys,
accepted_values for order status and review scores.

**Marts layer — relationship tests**
Every foreign key in the fact tables is tested against its dimension.
`customer_id` in `fct_orders` must exist in `dim_customers`. `product_id`
and `seller_id` in `fct_order_items` must exist in their respective dims.

**Singular tests — business logic**
Three custom SQL tests:
- Item prices must be greater than zero
- Payment values must be greater than or equal to zero
  (zero is valid — some orders are fully covered by vouchers)
- Delivered orders must have a delivery timestamp
  (set to `severity: warn` — 8 records in the source data fail this,
  which is a known source data issue, not a transformation bug)

---

## Project Structure

```
olist_ecommerce/
├── models/
│   ├── staging/
│   │   ├── __sources.yml
│   │   ├── __stg_olist.yml
│   │   └── stg_*.sql (9 models)
│   └── marts/
│       ├── __marts.yml
│       ├── fct_orders.sql
│       ├── fct_order_items.sql
│       ├── dim_customers.sql
│       ├── dim_sellers.sql
│       └── dim_products.sql
├── tests/
│   ├── assert_delivered_orders_have_delivery_date.sql
│   ├── assert_order_items_price_is_positive.sql
│   └── assert_payment_value_is_positive.sql
└── dbt_project.yml
```

---

## How to Run

```bash
dbt debug    # test connection
dbt run      # build all models
dbt test     # run all tests
dbt build    # models + tests in DAG order
```

**Expected result:**
58 total | 57 success | 1 warn
*(the warn is the 8 delivered orders missing timestamps in the source data)*
```
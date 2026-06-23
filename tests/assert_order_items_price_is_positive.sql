-- All order item prices must be greater than zero.
-- Any rows returned by this test are failures.

select
    order_id,
    product_id,
    price
from {{ ref('stg_order_items') }}
where price <= 0
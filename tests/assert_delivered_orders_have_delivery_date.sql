{{ config(severity='warn') }}

-- Delivered orders must always have a delivered_at timestamp.
-- Any rows returned by this test are failures.
-- NOTE: 8 known dirty records exist in source data.

select
    order_id,
    order_status,
    delivered_at
from {{ ref('stg_orders') }}
where order_status = 'delivered'
  and delivered_at is null
-- All payment values must be greater than zero.
-- Any rows returned by this test are failures.

select
    order_id,
    payment_type,
    payment_value
from {{ ref('stg_order_payments') }}
where payment_value < 0
with order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select 
        order_id,
        order_status,
        ordered_at
    from {{ ref('stg_orders') }}
),

final as (
    select oi.order_id,
        oi.order_item_id,
        oi.product_id,
        oi.seller_id,
        o.order_status,
        o.ordered_at,
        oi.shipping_limit_at,
        oi.price,
        oi.freight_value,
        oi.price + oi.freight_value as item_total
    from order_items oi
    left join orders o
        on oi.order_id = o.order_id
)

select * from final


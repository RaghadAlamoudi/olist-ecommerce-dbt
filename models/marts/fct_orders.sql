with orders as (
    select * from {{ ref('stg_orders') }}
),


payments as (
    select
        order_id,
        sum(payment_value) as total_payment_value,
        count(distinct payment_type) as payment_method_used,
        max(payment_installments) as max_installments
    from {{ ref('stg_order_payments') }}
    group by order_id
),

reviews as (
    select
        order_id,
        review_score,
        comment_title,
        comment_message,
        review_created_at,
        review_answered_at
    from {{ ref('stg_order_reviews') }}
    qualify row_number() over (partition by order_id order by review_created_at desc) = 1
),

items as (
    select
        order_id,
        count(*) as item_count,
        sum(price) as items_subtotal,
        sum(freight_value) as total_freight_value
    from {{ ref('stg_order_items') }}
    group by order_id
),

final as (
    select
        o.order_id,
        o.customer_id,
        o.order_status,
        o.ordered_at,
        o.approved_at,
        o.shipped_at,
        o.delivered_at,
        o.estimated_delivery_at,


        -- payment metrics
        p.total_payment_value,
        p.payment_method_used,
        p.max_installments,


        -- item metrics
        i.item_count,
        i.items_subtotal,
        i.total_freight_value,


        -- review
        r.review_score,
        r.comment_title,
        r.comment_message,
        r.review_created_at,
        r.review_answered_at,


        -- delivery metrics
        datediff('day', o.ordered_at, o.delivered_at) as days_to_deliver,
        datediff('day', o.delivered_at, o.estimated_delivery_at) as days_early_or_late

    from orders o
    left join payments p on o.order_id = p.order_id
    left join items i on o.order_id = i.order_id
    left join reviews r on o.order_id = r.order_id

)

select * from final
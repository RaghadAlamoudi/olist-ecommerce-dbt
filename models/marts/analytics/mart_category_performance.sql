with order_items_products as (
    select
        oi.order_id,
        oi.price,
        oi.freight_value,
        p.category_name_english
    from {{ ref('fct_order_items') }} oi
    left join {{ ref('dim_products') }} p on oi.product_id = p.product_id
    where p.category_name_english is not null
),

order_details as (
    select
        o.order_id,
        o.order_status,
        o.review_score
    from {{ ref('fct_orders') }} o
),

final as (
    select
        oip.category_name_english,
        count(distinct oip.order_id)                as total_orders,
        round(sum(oip.price), 2)                    as total_revenue,
        round(avg(oip.price), 2)                    as avg_item_price,
        round(avg(od.review_score), 2)              as avg_review_score,
        round(sum(case when od.order_status = 'canceled'
                  then 1 else 0 end) * 100.0
              / count(*), 2)                        as cancellation_rate
    from order_items_products oip
    left join order_details od on oip.order_id = od.order_id
    group by oip.category_name_english
)

select * from final
order by total_revenue desc
with delivered_orders as (
    select
        o.order_id,
        o.days_to_deliver,
        o.days_early_or_late,
        o.delivered_at,
        c.state as customer_state
    from {{ ref('fct_orders') }} o
    left join {{ ref('dim_customers') }} c on o.customer_id = c.customer_id
    where o.order_status = 'delivered'
      and o.delivered_at is not null
),

order_sellers as (
    select
        oi.order_id,
        s.state as seller_state
    from {{ ref('fct_order_items') }} oi
    left join {{ ref('dim_sellers') }} s on oi.seller_id = s.seller_id
),
corridor_metrics as (
    select
        os.seller_state,
        do.customer_state,
        count(distinct do.order_id)                 as total_orders,
        round(avg(do.days_to_deliver), 1)           as avg_days_to_deliver,
        round(avg(do.days_early_or_late), 1)        as avg_days_early_or_late,
        round(sum(case when do.days_early_or_late >= 0
                  then 1 else 0 end) * 100.0
              / count(*), 1)                        as on_time_rate
    from delivered_orders do
    left join order_sellers os on do.order_id = os.order_id
    where os.seller_state is not null
      and do.customer_state is not null
    group by os.seller_state, do.customer_state
)

select * from corridor_metrics
order by avg_days_to_deliver desc
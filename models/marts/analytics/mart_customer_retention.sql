with customer_orders as (
    select
        c.customer_unique_id,
        c.city,
        c.state,
        o.order_id,
        o.ordered_at,
        o.total_payment_value
    from {{ ref('fct_orders') }} o
    left join {{ ref('dim_customers') }} c on o.customer_id = c.customer_id
    where c.customer_unique_id is not null
),

customer_metrics as (
    select
        customer_unique_id,
        city,
        state,
        count(distinct order_id)                    as total_orders,
        min(ordered_at)                             as first_order_at,
        max(ordered_at)                             as last_order_at,
        datediff('day', min(ordered_at),
                        max(ordered_at))            as days_as_customer,
        round(avg(total_payment_value), 2)          as avg_order_value,
        round(sum(total_payment_value), 2)          as total_spend
    from customer_orders
    group by customer_unique_id, city, state
),

final as (
    select
        customer_unique_id,
        city,
        state,
        total_orders,
        first_order_at,
        last_order_at,
        days_as_customer,
        avg_order_value,
        total_spend,
        case
            when total_orders = 1 then 'one_time'
            when total_orders <= 3 then 'returning'
            else 'loyal'
        end                                         as customer_segment
    from customer_metrics
)

select * from final

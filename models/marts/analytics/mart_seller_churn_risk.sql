with date_anchor as (
    select max(ordered_at) as max_order_date
    from {{ ref('fct_orders') }}
),

seller_orders as (
    select
        oi.seller_id,
        o.order_id,
        o.ordered_at,
        o.review_score,
        o.days_early_or_late
    from {{ ref('fct_order_items') }} oi
    left join {{ ref('fct_orders') }} o on oi.order_id = o.order_id
),

current_window as (
    select
        so.seller_id,
        count(distinct so.order_id)         as current_order_count,
        avg(so.review_score)                as current_avg_review_score,
        avg(so.days_early_or_late)          as current_avg_delay
    from seller_orders so
    cross join date_anchor da
    where so.ordered_at >= dateadd('day', -90, da.max_order_date)
    group by so.seller_id
),

prior_window as (
    select
        so.seller_id,
        count(distinct so.order_id)         as prior_order_count,
        avg(so.review_score)                as prior_avg_review_score,
        avg(so.days_early_or_late)          as prior_avg_delay
    from seller_orders so
    cross join date_anchor da
    where so.ordered_at >= dateadd('day', -180, da.max_order_date)
      and so.ordered_at <  dateadd('day', -90,  da.max_order_date)
    group by so.seller_id
),

signals as (
    select
        s.seller_id,
        s.city,
        s.state,
        coalesce(c.current_order_count, 0)        as current_order_count,
        coalesce(p.prior_order_count, 0)           as prior_order_count,
        c.current_avg_review_score,
        p.prior_avg_review_score,
        c.current_avg_delay,
        p.prior_avg_delay,

        case when coalesce(c.current_order_count, 0) < coalesce(p.prior_order_count, 0)
             then 1 else 0 end                     as volume_declining,
        case when c.current_avg_review_score < p.prior_avg_review_score
             then 1 else 0 end                     as reviews_worsening,
        case when c.current_avg_delay > p.prior_avg_delay
             then 1 else 0 end                     as delivery_worsening

    from {{ ref('dim_sellers') }} s
    left join current_window c on s.seller_id = c.seller_id
    left join prior_window p   on s.seller_id = p.seller_id
    where c.seller_id is not null or p.seller_id is not null
),

final as (
    select
        seller_id,
        city,
        state,
        current_order_count,
        prior_order_count,
        round(current_avg_review_score, 2)         as current_avg_review_score,
        round(prior_avg_review_score, 2)            as prior_avg_review_score,
        round(current_avg_delay, 1)                 as current_avg_delay,
        round(prior_avg_delay, 1)                   as prior_avg_delay,
        volume_declining,
        reviews_worsening,
        delivery_worsening,
        volume_declining + reviews_worsening + delivery_worsening  as signals_worsening,
        case
            when volume_declining + reviews_worsening + delivery_worsening >= 2
                then 'high'
            when volume_declining + reviews_worsening + delivery_worsening = 1
                then 'medium'
            else 'low'
        end                                         as churn_risk_tier

    from signals
)

select * from final
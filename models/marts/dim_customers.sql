with customers as(
    select * from {{ ref('stg_customers') }}
),

geolocation as(
    select
        zip_code,
        avg(latitude) as latitude,
        avg(longitude) as longitude
    from {{ ref('stg_geolocation') }}
    group by zip_code
),

final as(
    select
        c.customer_id,
        c.customer_unique_id,
        c.zip_code,
        c.city,
        c.state,
        g.latitude,
        g.longitude
    from customers c
    left join geolocation g
        on c.zip_code = g.zip_code
)

select * from final
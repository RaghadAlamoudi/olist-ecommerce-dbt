with sellers as (
    select * from {{ ref('stg_sellers') }}
),

geolocation as (
    select
        zip_code,
        avg(latitude)  as latitude,
        avg(longitude) as longitude
    from {{ ref('stg_geolocation') }}
    group by zip_code
),

final as (
    select
        s.seller_id,
        s.zip_code,
        s.city,
        s.state,
        g.latitude,
        g.longitude
    from sellers s
    left join geolocation g on s.zip_code = g.zip_code
)

select * from final
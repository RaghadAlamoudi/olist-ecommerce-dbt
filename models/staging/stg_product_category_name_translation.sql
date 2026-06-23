with source as (
    select * from {{ source('olist', 'product_category_name_translation') }}
),

renamed as (
    select
        c1          as category_name,
        c2          as category_name_english
    from source
)

select * from renamed
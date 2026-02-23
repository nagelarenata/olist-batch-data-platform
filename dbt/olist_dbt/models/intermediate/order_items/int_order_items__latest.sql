{{ config(materialized='view') }}

select
    order_id,
    order_item_id,
    product_id,
    seller_id,

    shipping_limit_ts,
    shipping_limit_dt,

    price,
    freight_value,

    load_date,
    ingestion_ts,
    source_file,
    source_uri

from {{ ref('stg_order_items') }}

qualify row_number() over (
    partition by order_id, order_item_id
    order by load_date desc, ingestion_ts desc
) = 1

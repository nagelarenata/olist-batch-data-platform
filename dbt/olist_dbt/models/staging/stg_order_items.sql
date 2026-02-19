{{ config(materialized='view') }}

select
    -- keys
    order_id,
    order_item_id,
    product_id,
    seller_id,

    -- business fields
    shipping_limit_date as shipping_limit_ts,
    price,
    freight_value,

    -- ingestion lineage
    load_date,
    ingestion_ts,
    source_file,
    source_uri

from {{ source('olist_raw', 'order_items') }}

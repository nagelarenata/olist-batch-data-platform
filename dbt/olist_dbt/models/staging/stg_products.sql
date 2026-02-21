{{ config(materialized='view') }}

select
    product_id,

    -- product attributes
    lower(trim(product_category_name)) as product_category_name,
    product_name_lenght as product_name_length,
    product_description_lenght as product_description_length,
    product_photos_qty,

    -- physical characteristics
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,

    -- ingestion lineage
    load_date,
    ingestion_ts,
    source_file,
    source_uri

from {{ source('olist_raw', 'products') }}
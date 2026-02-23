{{ config(materialized='view') }}

select
    seller_id,

    -- geographic attributes (normalized)
    seller_zip_code_prefix,
    nullif(lower(trim(seller_city)), '') as seller_city,
    nullif(upper(trim(seller_state)), '') as seller_state,

    -- ingestion lineage
    load_date,
    ingestion_ts,
    source_file,
    source_uri

from {{ source('olist_raw', 'sellers') }}
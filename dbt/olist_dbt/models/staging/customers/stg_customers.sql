{{ config(materialized='view') }}

select
    -- business keys
    customer_id,
    customer_unique_id,

    -- location attributes (standardized)
    customer_zip_code_prefix,
    nullif(lower(trim(customer_city)), '') as customer_city,
    nullif(upper(trim(customer_state)), '') as customer_state,

    -- ingestion metadata (lineage)
    load_date,
    ingestion_ts,
    source_file,
    source_uri

from {{ source('olist_raw', 'customers') }}

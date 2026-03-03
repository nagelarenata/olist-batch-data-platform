{{ config(materialized='table') }}

select
  {{ dbt_utils.generate_surrogate_key(['seller_id']) }} as seller_key,

  -- natural key
  seller_id,

  -- attributes
  seller_zip_code_prefix,
  seller_city,
  seller_state,

  -- audit
  load_date,
  ingestion_ts,
  source_file,
  source_uri

from {{ ref('int_sellers__latest') }}
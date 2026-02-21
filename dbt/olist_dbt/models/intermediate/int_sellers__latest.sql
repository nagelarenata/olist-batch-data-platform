{{ config(materialized='view') }}

select
  seller_id,
  seller_zip_code_prefix,
  seller_city,
  seller_state,

  load_date,
  ingestion_ts,
  source_file,
  source_uri
from {{ ref('stg_sellers') }}
qualify row_number() over (
  partition by seller_id
  order by load_date desc, ingestion_ts desc, source_file desc
) = 1
{{ config(materialized='view') }}

select
  customer_id,
  customer_unique_id,
  customer_zip_code_prefix,
  customer_city,
  customer_state,

  load_date,
  ingestion_ts,
  source_file,
  source_uri
from {{ ref('stg_customers') }}
qualify row_number() over (
  partition by customer_id
  order by load_date desc, ingestion_ts desc, source_file desc
) = 1

{{ config(materialized='table') }}

select
  {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_key,

  -- natural keys
  customer_id,
  customer_unique_id,

  -- attributes
  customer_zip_code_prefix,
  customer_city,
  customer_state,

  -- audit
  load_date,
  ingestion_ts,
  source_file,
  source_uri

from {{ ref('int_customers__latest') }}
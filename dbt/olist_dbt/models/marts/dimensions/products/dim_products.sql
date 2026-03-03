{{ config(materialized='table') }}

select
  {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_key,

  -- natural key
  product_id,

  -- attributes
  product_category_name,
  product_name_length,
  product_description_length,
  product_photos_qty,
  product_weight_g,
  product_length_cm,
  product_height_cm,
  product_width_cm,

  -- audit lineage
  load_date,
  ingestion_ts,
  source_file,
  source_uri

from {{ ref('int_products__latest') }}
{{ config(materialized='view') }}

select
  product_id,
  product_category_name,
  product_name_length,
  product_description_length,
  product_photos_qty,
  product_weight_g,
  product_length_cm,
  product_height_cm,
  product_width_cm,
  load_date,
  ingestion_ts,
  source_file,
  source_uri
from {{ ref('stg_products') }}
qualify row_number() over (
  partition by product_id
  order by load_date desc, ingestion_ts desc
) = 1
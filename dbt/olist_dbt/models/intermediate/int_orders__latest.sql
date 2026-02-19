{{ config(materialized='view') }}

select
  order_id,
  customer_id,
  order_status,
  order_purchase_ts,
  order_purchase_dt,
  order_approved_ts,
  order_delivered_carrier_ts,
  order_delivered_customer_ts,
  order_estimated_delivery_ts,
  load_date,
  ingestion_ts,
  source_file,
  source_uri
from {{ ref('stg_orders') }}
qualify row_number() over (
  partition by order_id
  order by load_date desc, ingestion_ts desc
) = 1

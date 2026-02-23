{{ config(materialized='view') }}

with src as (
  select
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    load_date,
    ingestion_ts,
    source_file,
    source_uri
  from {{ source('olist_raw', 'orders') }}
),

parsed as (
  select
    order_id,
    customer_id,
    order_status,

    safe_cast(order_purchase_timestamp as timestamp) as order_purchase_ts,
    safe_cast(order_approved_at as timestamp) as order_approved_ts,
    safe_cast(order_delivered_carrier_date as timestamp) as order_delivered_carrier_ts,
    safe_cast(order_delivered_customer_date as timestamp) as order_delivered_customer_ts,
    safe_cast(order_estimated_delivery_date as timestamp) as order_estimated_delivery_ts,

    load_date,
    ingestion_ts,
    source_file,
    source_uri
  from src
)

select
  *,
  date(order_purchase_ts) as order_purchase_dt
from parsed

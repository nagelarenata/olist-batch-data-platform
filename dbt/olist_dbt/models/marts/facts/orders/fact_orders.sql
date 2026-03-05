{{ config(materialized='table') }}

with o as (
  select
    order_id,
    customer_id,
    order_status,
    order_purchase_dt,
    date(order_approved_ts) as order_approved_dt,
    date(order_delivered_customer_ts) as order_delivered_customer_dt,
    date(order_estimated_delivery_ts) as order_estimated_delivery_dt
  from {{ ref('int_orders__latest') }}
)

select
  -- degenerate dimension
  o.order_id,

  -- surrogate FK (match dim_customers)
  {{ dbt_utils.generate_surrogate_key(['o.customer_id']) }} as customer_key,

  -- date keys
  cast(format_date('%Y%m%d', o.order_purchase_dt) as int64) as order_purchase_date_key,
  cast(format_date('%Y%m%d', o.order_approved_dt) as int64) as order_approved_date_key,
  cast(format_date('%Y%m%d', o.order_delivered_customer_dt) as int64) as order_delivered_customer_date_key,
  cast(format_date('%Y%m%d', o.order_estimated_delivery_dt) as int64) as order_estimated_delivery_date_key,

  -- degenerate attribute
  o.order_status,

  -- flags
  (o.order_delivered_customer_dt is not null) as is_delivered,

  -- delivery lead time (purchase -> delivered)
  date_diff(
    o.order_delivered_customer_dt,
    o.order_purchase_dt,
    day
  ) as delivery_days,

  -- delivery delay:
  -- estimated - delivered
  -- Positive  = delivered BEFORE estimated (early)
  -- Negative  = delivered AFTER estimated (late)
  date_diff(
    o.order_estimated_delivery_dt,
    o.order_delivered_customer_dt,
    day
  ) as delivery_delay_days,

  -- SLA flag
  case
    when o.order_delivered_customer_dt is null
      or o.order_estimated_delivery_dt is null then null
    when o.order_delivered_customer_dt <= o.order_estimated_delivery_dt then true
    else false
  end as is_delivered_on_time

from o
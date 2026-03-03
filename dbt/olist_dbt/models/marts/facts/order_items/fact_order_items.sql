{{ config(materialized='table') }}

with items as (
  select
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_dt,
    price,
    freight_value
  from {{ ref('int_order_items__latest') }}
),

orders as (
  select
    order_id,
    customer_id,
    order_purchase_dt
  from {{ ref('int_orders__latest') }}
)

select
  -- degenerate dimensions
  i.order_id,
  i.order_item_id,

  -- surrogate foreign keys (must match dims)
  {{ dbt_utils.generate_surrogate_key(['i.product_id']) }} as product_key,
  {{ dbt_utils.generate_surrogate_key(['i.seller_id']) }} as seller_key,
  {{ dbt_utils.generate_surrogate_key(['o.customer_id']) }} as customer_key,

  -- date keys (conformed to dim_date)
  cast(format_date('%Y%m%d', o.order_purchase_dt) as int64) as order_purchase_date_key,
  cast(format_date('%Y%m%d', i.shipping_limit_dt) as int64) as shipping_limit_date_key,

  -- measures (additive at item grain)
  1 as item_qty,
  i.price as item_price,
  i.freight_value as item_freight,
  (i.price + i.freight_value) as item_gmv

from items i
join orders o
  on i.order_id = o.order_id
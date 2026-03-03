{{ config(materialized='table') }}

-- ==========================================================
-- Model: agg_seller_monthly
-- Grain: 1 row per seller_key + year_month
--
-- Purpose:
-- Monthly, seller-level performance KPIs.
--
-- This model combines:
--   1) Item-level commercial measures (GMV, freight, qty) from fact_order_items
--   2) Order-level delivery KPIs (delivered / on-time) from fact_orders
--
-- Key modeling rule (to avoid double counting):
-- fact_order_items has N rows per order (multiple items).
-- fact_orders has 1 row per order.
--
-- If we join orders directly to item rows and then COUNTIF(is_delivered),
-- delivery counts would be inflated for orders with multiple items.
--
-- Solution:
-- - Aggregate item metrics to seller-month (items_monthly)
-- - Deduplicate seller-month orders (seller_orders)
-- - Compute delivery KPIs at the deduplicated order level (delivery_monthly)
-- - Join both monthly results at the end
-- ==========================================================

with items as (
  select
    seller_key,
    order_id,
    order_purchase_date_key,
    item_qty,
    item_price,
    item_freight,
    item_gmv
  from {{ ref('fact_order_items') }}
),

items_enriched as (
  select
    *,
    cast(div(order_purchase_date_key, 100) as int64) as year_month,
    cast(div(order_purchase_date_key, 10000) as int64) as year,
    cast(div(mod(order_purchase_date_key, 10000), 100) as int64) as month
  from items
),

seller_orders as (
  select distinct
    seller_key,
    year_month,
    year,
    month,
    order_id
  from items_enriched
),

items_monthly as (
  select
    year_month,
    year,
    month,
    seller_key,
    count(distinct order_id) as orders_cnt,
    sum(item_qty) as items_cnt,
    sum(item_price) as items_price_sum,
    sum(item_freight) as freight_sum,
    sum(item_gmv) as gmv_sum,
    safe_divide(sum(item_gmv), count(distinct order_id)) as avg_order_value,
    safe_divide(sum(item_gmv), sum(item_qty)) as avg_item_value
  from items_enriched
  group by 1,2,3,4
),

delivery_monthly as (
  select
    so.year_month,
    so.year,
    so.month,
    so.seller_key,
    countif(o.is_delivered) as delivered_orders_cnt,
    countif(o.is_delivered_on_time) as on_time_orders_cnt,
    safe_divide(countif(o.is_delivered_on_time), countif(o.is_delivered)) as on_time_rate
  from seller_orders so
  left join {{ ref('fact_orders') }} o
    on so.order_id = o.order_id
  group by 1,2,3,4
)

select
  im.year_month,
  im.year,
  im.month,
  im.seller_key,
  im.orders_cnt,
  im.items_cnt,
  im.items_price_sum,
  im.freight_sum,
  im.gmv_sum,
  im.avg_order_value,
  im.avg_item_value,
  dm.delivered_orders_cnt,
  dm.on_time_orders_cnt,
  dm.on_time_rate
from items_monthly im
left join delivery_monthly dm
  using (year_month, year, month, seller_key)
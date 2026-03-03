{{ config(materialized='table') }}

-- ==========================================================
-- Model: agg_orders
-- Grain: 1 row per order_id
--
-- Purpose:
-- This model aggregates item-level measures from fact_order_items
-- and combines them with order-level attributes and SLA metrics
-- from fact_orders.
--
-- It serves two main purposes:
-- 1. Reconciliation layer between item and order facts
-- 2. Business-ready order-level KPI table for BI consumption
-- ==========================================================


with orders as (
  -- Order-level attributes and SLA metrics
  -- Grain: 1 row per order_id
    select
        order_id,
        customer_key,
        order_purchase_date_key,
        order_approved_date_key,
        order_delivered_customer_date_key,
        order_estimated_delivery_date_key,
        order_status,
        is_delivered,
        delivery_days,
        delivery_delay_days,
        is_delivered_on_time
    from {{ ref('fact_orders') }}
),

item_agg as (
    -- Aggregate item-level measures up to order level
    -- Grain: 1 row per order_id
    select
        order_id,
        sum(item_qty) as order_items_qty,
        sum(item_price) as order_items_price,
        sum(item_freight) as order_freight,
        sum(item_gmv) as order_gmv
    from {{ ref('fact_order_items') }}
    group by 1
)

select
    -- Degenerate dimension (business identifier)
    o.order_id,

    -- Surrogate keys (conformed dimensions)
    o.customer_key,
    o.order_purchase_date_key,
    o.order_approved_date_key,
    o.order_delivered_customer_date_key,
    o.order_estimated_delivery_date_key,

    -- Order status and SLA indicators
    o.order_status,
    o.is_delivered,
    o.delivery_days,
    o.delivery_delay_days,
    o.is_delivered_on_time,

    -- Data quality flag:
    -- Indicates whether the order has at least one associated item
    (ia.order_id is not null) as order_has_items,

    -- Aggregated measures (coalesced to 0 for BI stability)
    coalesce(ia.order_items_qty, 0) as order_items_qty,
    coalesce(ia.order_items_price, 0) as order_items_price,
    coalesce(ia.order_freight, 0) as order_freight,
    coalesce(ia.order_gmv, 0) as order_gmv,

    -- Derived KPI:
    -- Average GMV per item within the order
    -- Uses safe_divide + nullif to prevent division-by-zero
    safe_divide(coalesce(ia.order_gmv, 0), nullif(coalesce(ia.order_items_qty, 0), 0)) as avg_gmv_per_item

-- Left join ensures:
-- • All orders are preserved
-- • Orders without items are still visible (for investigation)
from orders o
left join item_agg ia
    on o.order_id = ia.order_id

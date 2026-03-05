{{
    config(
        materialized='incremental',
        unique_key='order_purchase_date_key',
        incremental_strategy='merge',
    )
}}

-- ==========================================================
-- Model: agg_sales_daily
-- Grain: 1 row per order_purchase_date_key (day)
--
-- Purpose:
-- Dashboard-ready daily time series combining:
-- - Item-based commercial metrics from fact_order_items
-- - Delivery/SLA KPIs from fact_orders
--
-- Why we do this in two steps:
-- fact_orders has 1 row per order, while fact_order_items has N rows per order.
-- Joining them first would duplicate order-level flags (e.g., is_delivered),
-- inflating COUNTIF-based metrics. We aggregate each fact at the correct grain
-- and join the daily results afterwards to avoid double counting.
--
-- Incremental strategy:
-- On incremental runs, only days >= the latest already-processed date are
-- recomputed. The most recent day is always reprocessed to capture late-arriving
-- orders (e.g., status updates that arrive after the initial load).
-- ==========================================================

with items_daily as (
    select
        order_purchase_date_key,

        -- volumes
        count(distinct order_id) as orders_cnt,
        sum(item_qty) as items_cnt,

        -- values
        sum(item_price) as items_price_sum,
        sum(item_freight) as freight_sum,
        sum(item_gmv) as gmv_sum,

        -- averages
        safe_divide(sum(item_gmv), count(distinct order_id)) as avg_order_value,
        safe_divide(sum(item_gmv), sum(item_qty)) as avg_item_value

    from {{ ref('fact_order_items') }}
    {% if is_incremental() %}
    where order_purchase_date_key >= (
        select cast(format_date('%Y%m%d', date_sub(max(parse_date('%Y%m%d', cast(order_purchase_date_key as string))), interval 1 day)) as int64)
        from {{ this }}
    )
    {% endif %}
    group by 1
),

orders_daily as (
    select
        order_purchase_date_key,

        -- sanity check
        count(*) as orders_in_fact_cnt,

        -- delivery KPIs (order-grain metrics)
        countif(is_delivered) as delivered_orders_cnt,
        countif(is_delivered_on_time) as on_time_orders_cnt,
        safe_divide(countif(is_delivered_on_time), countif(is_delivered)) as on_time_rate

    from {{ ref('fact_orders') }}
    {% if is_incremental() %}
    where order_purchase_date_key >= (
        select cast(format_date('%Y%m%d', date_sub(max(parse_date('%Y%m%d', cast(order_purchase_date_key as string))), interval 1 day)) as int64)
        from {{ this }}
    )
    {% endif %}
    group by 1
)

select
    i.order_purchase_date_key,

    -- volumes
    i.orders_cnt,
    i.items_cnt,

    -- values
    i.items_price_sum,
    i.freight_sum,
    i.gmv_sum,

    -- averages
    i.avg_order_value,
    i.avg_item_value,

    -- delivery KPIs
    o.delivered_orders_cnt,
    o.on_time_orders_cnt,
    o.on_time_rate,

    -- sanity check column
    o.orders_in_fact_cnt

from items_daily i
left join orders_daily o
    using (order_purchase_date_key)
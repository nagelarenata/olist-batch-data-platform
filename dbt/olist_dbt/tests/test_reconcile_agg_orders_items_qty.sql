-- Fails if order-level items quantity in agg_orders does not match the sum of item quantities.
-- Items qty: sum(item_qty) vs agg_orders.order_items_qty

with items as (
  select
    order_id,
    sum(item_qty) as items_qty
  from {{ ref('fact_order_items') }}
  group by 1
),

orders as (
  select
    order_id,
    order_items_qty
  from {{ ref('agg_orders') }}
)

select
  o.order_id,
  i.items_qty,
  o.order_items_qty,
  (i.items_qty - o.order_items_qty) as diff
from orders o
join items i using (order_id)
where i.items_qty != o.order_items_qty
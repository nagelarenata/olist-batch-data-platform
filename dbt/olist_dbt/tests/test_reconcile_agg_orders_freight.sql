-- Fails if order-level freight in agg_orders does not match the sum of item freight.
-- Freight: sum(item_freight) vs agg_orders.order_freight

with items as (
  select
    order_id,
    sum(item_freight) as items_freight
  from {{ ref('fact_order_items') }}
  group by 1
),

orders as (
  select
    order_id,
    order_freight
  from {{ ref('agg_orders') }}
)

select
  o.order_id,
  i.items_freight,
  o.order_freight,
  (i.items_freight - o.order_freight) as diff
from orders o
join items i using (order_id)
where abs(i.items_freight - o.order_freight) > 0.01
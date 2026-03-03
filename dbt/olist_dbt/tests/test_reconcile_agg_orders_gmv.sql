-- Fails if order-level GMV in agg_orders does not match the sum of item GMV.
-- GMV: sum(item_gmv) vs agg_orders.order_gmv

with items as (
  select
    order_id,
    sum(item_gmv) as items_gmv
  from {{ ref('fact_order_items') }}
  group by 1
),

orders as (
  select
    order_id,
    order_gmv
  from {{ ref('agg_orders') }}
)

select
  o.order_id,
  i.items_gmv,
  o.order_gmv,
  (i.items_gmv - o.order_gmv) as diff
from orders o
join items i using (order_id)
where abs(i.items_gmv - o.order_gmv) > 0.01
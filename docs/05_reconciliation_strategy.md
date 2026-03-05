# Reconciliation Strategy

## Purpose

Ensure analytical consistency across fact and aggregation models.

The reconciliation strategy validates that metrics remain consistent
across different grains of the warehouse.

---

# Reconciliation Scope

Current reconciliation tests validate consistency at the **order level**,
comparing item-level measures in `fact_order_items` against aggregated
measures in `agg_orders`.

Daily and monthly level reconciliation are not yet implemented.

---

# Implementation

Reconciliation tests are implemented as **singular dbt tests** located in:

```
dbt/olist_dbt/tests/
├── test_reconcile_agg_orders_gmv.sql
├── test_reconcile_agg_orders_freight.sql
└── test_reconcile_agg_orders_items_qty.sql
```

Each test returns rows where discrepancies are found.
A non-empty result causes the test to fail.

Tests join `fact_order_items` (aggregated to order level) with `agg_orders`
using an inner join, so only orders with associated items are validated.

---

# Validation Rules

## GMV Consistency

```
sum(fact_order_items.item_gmv)
=
agg_orders.order_gmv
```

---

## Freight Consistency

```
sum(fact_order_items.item_freight)
=
agg_orders.order_freight
```

---

## Item Quantity Consistency

```
sum(fact_order_items.item_qty)
=
agg_orders.order_items_qty
```

---

# Failure Behavior

A failing test surfaces the affected `order_id` values along with
the observed values and the difference (`diff` column).

This allows targeted investigation of data quality issues
without requiring a full pipeline rerun.

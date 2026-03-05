# Gold Layer Contract

## Purpose

This document defines the analytical contract of the Gold layer (marts).

The Gold layer represents the business-consumption boundary of the warehouse.
Models in this layer are considered stable, documented, and safe for BI tools,
dashboards, and downstream analytics use.

Any structural change in this layer should be treated as a breaking change.

---

# Layer Definition

The Gold layer contains:

- Dimensional models (`dim_*`)
- Fact models (`fact_*`)
- Aggregated models (`agg_*`)

All models follow Kimball-style dimensional modeling principles.

---

# Dimensional Modeling Standards

## 1. Surrogate Keys

All dimensions use surrogate keys generated via:

`dbt_utils.generate_surrogate_key()`

Design decisions:

- Surrogate keys are warehouse-generated
- Natural keys are preserved for traceability
- Cross-warehouse compatibility is prioritized

Note:
In production BigQuery environments, surrogate keys could be implemented as INT64 using FARM_FINGERPRINT for performance optimization.

---

## 2. Natural Keys

Natural keys are:

- Preserved in dimensions
- Never used as join keys in facts
- Maintained for reconciliation and traceability

---

## 3. Degenerate Dimensions

Degenerate dimensions are allowed in facts when operational identifiers are required for:

- Drill-down analysis
- Debugging
- Reconciliation

Examples:
- `order_id`
- `order_item_id`

---

## 4. Conformed Dimensions

The following dimensions are conformed across facts:

- `dim_date`
- `dim_customers`
- `dim_products`
- `dim_sellers`

This guarantees cross-model analytical consistency.

---

# Dimension Model Contracts

## dim_date

**Grain:** 1 row per calendar day

Contains:

- `date_key`: surrogate key in YYYYMMDD format
- Calendar attributes (year, quarter, month, week, day)
- `is_weekend` flag
- Period start dates (month, week, quarter, year)

Range: 2016-01-01 to 2020-12-31 (covers full Olist dataset period)

---

## dim_customers

**Grain:** 1 row per customer_id (latest batch state)

Contains:

- `customer_key`: surrogate key
- `customer_id`: transaction-level natural key
- `customer_unique_id`: stable customer identifier across orders
- Geographic attributes (city, state, zip code prefix)

---

## dim_sellers

**Grain:** 1 row per seller_id (latest batch state)

Contains:

- `seller_key`: surrogate key
- `seller_id`: natural key
- Geographic attributes (city, state, zip code prefix)

---

## dim_products

**Grain:** 1 row per product_id (latest batch state)

Contains:

- `product_key`: surrogate key
- `product_id`: natural key
- `product_category_name`: standardized (lowercased)
- Physical attributes (weight, dimensions)
- Content attributes (name length, description length, photos qty)

---

# Fact Model Contracts

## fact_order_items

**Grain:** 1 row per order_id + order_item_id

Contains:

- Surrogate foreign keys to dimensions
- Commercial metrics (price, freight, GMV)
- Degenerate dimensions (order_id, order_item_id)

Rules:

- Metrics must be additive
- No header-level duplication
- No joins that inflate row count

---

## fact_orders

**Grain:** 1 row per order_id

Contains:

- Surrogate FK to dim_customers
- Date keys (purchase, approval, delivery, estimated delivery)
- Delivery lead time (`delivery_days`: days from purchase to delivery)
- Delivery delay (`delivery_delay_days`: estimated minus actual, positive = early)
- SLA flag (`is_delivered_on_time`)
- Order status and delivery flag (`is_delivered`)

Rules:

- One row per order
- Delivery metrics must not depend on item-level joins

---

# Aggregation Model Contracts

## agg_orders

**Grain:** 1 row per order_id

Purpose:

- Reconciliation layer between fact_order_items and fact_orders
- Single-order business summary

Validation rules:

`sum(fact_order_items.item_gmv) = agg_orders.order_gmv`

`sum(fact_order_items.item_freight) = agg_orders.order_freight`

`sum(fact_order_items.item_qty) = agg_orders.order_items_qty`

---

## agg_sales_daily

**Grain:** 1 row per order_purchase_date_key

**Materialization:** incremental (merge on `order_purchase_date_key`)

Purpose:

- Daily business KPIs
- Dashboard-ready metrics

Rules:

- Item metrics aggregated from fact_order_items
- Delivery metrics aggregated independently from fact_orders
- No cross-grain joins allowed

Incremental behavior:

- On incremental runs, reprocesses days >= max already-processed date minus 1 day
- The 1-day lookback ensures late-arriving orders (e.g., status updates) are captured
- First run performs a full load; subsequent runs are additive via merge

---

## agg_seller_monthly

**Grain:** 1 row per seller_key + year_month

Purpose:

- Seller-level monthly performance analysis

Rules:

- Orders must be deduplicated before delivery KPI calculation
- Delivery metrics must be computed at order grain
- Commercial metrics aggregated at item grain

---

# Reconciliation Tests (Golden Tests)

The Gold layer enforces cross-grain consistency using singular dbt tests:

- GMV reconciliation between fact_order_items and agg_orders
- Freight reconciliation
- Item quantity reconciliation

A test fails if discrepancies are found.

These tests prevent silent data inflation caused by incorrect joins.

---

# Data Quality Guarantees

All Gold models enforce:

- Primary key uniqueness
- Not-null constraints
- Referential integrity
- Domain validation
- Reconciliation tests

---

# Incremental Behavior

Most Gold models use full-refresh table materializations.

`agg_sales_daily` is implemented as an incremental model (merge strategy, unique key `order_purchase_date_key`), reprocessing only new and the most recent day on each run.

Planned enhancements:

- Incremental fact models
- Partition-based incremental rebuild for remaining aggregations
- Snapshot-based SCD Type 2 dimensions

---

# Breaking Change Policy

Changes to:

- Grain
- Key structure
- Metric definitions

must be documented and versioned.

Gold models represent the analytical contract of the platform.
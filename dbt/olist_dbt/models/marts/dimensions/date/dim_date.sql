{{ config(materialized='table') }}

with calendar as (
  -- range
  select
    d as date_day
  from unnest(generate_date_array(date('2016-01-01'), date('2019-12-31'))) as d
)

select
  -- surrogate key (YYYYMMDD)
  cast(format_date('%Y%m%d', date_day) as int64) as date_key,

  date_day,

  extract(year from date_day) as year,
  extract(quarter from date_day) as quarter,
  extract(month from date_day) as month,
  format_date('%B', date_day) as month_name,
  extract(day from date_day) as day,

  extract(week from date_day) as week_of_year,
  extract(dayofweek from date_day) as day_of_week, 
  format_date('%A', date_day) as day_name,

  case when extract(dayofweek from date_day) in (1, 7) then true else false end as is_weekend,

  -- filters
  date_trunc(date_day, month) as month_start_date,
  date_trunc(date_day, week) as week_start_date,
  date_trunc(date_day, quarter) as quarter_start_date,
  date_trunc(date_day, year) as year_start_date

from calendar

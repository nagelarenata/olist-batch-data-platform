from __future__ import annotations

from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

# =====================================================
# SETTINGS
# =====================================================
DBT_PROJECT_DIR = "/opt/dbt/olist_dbt"
DBT_PROFILES_DIR = "/opt/dbt/olist_dbt"

# Airflow pool used to serialize BigQuery jobs (same pool as ingestion DAG)
BQ_POOL = "bigquery_serial"

default_args = {"owner": "data-platform", "retries": 1}

# =====================================================
# DAG
# =====================================================
with DAG(
    dag_id="02_olist_dbt_build",
    description="Olist dbt build: staging -> intermediate -> gold (full refresh)",
    start_date=datetime(2018, 10, 1),
    schedule=None,
    catchup=False,
    default_args=default_args,
    tags=["olist", "dbt", "gold", "analytics"],
    max_active_runs=1,
    max_active_tasks=1,
) as dag:

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=(
            f"dbt deps --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROFILES_DIR} && "
            f"dbt build --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROFILES_DIR}"
        ),
        pool=BQ_POOL,
    )
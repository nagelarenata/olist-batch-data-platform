from __future__ import annotations

from datetime import datetime

from airflow import DAG
from airflow.utils.task_group import TaskGroup
from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCreateEmptyDatasetOperator,
    BigQueryInsertJobOperator,
)
from airflow.operators.python import PythonOperator
from airflow.exceptions import AirflowFailException
from airflow.providers.google.cloud.hooks.gcs import GCSHook

# =====================================================
# SETTINGS
# =====================================================
PROJECT_ID = "olist-batch-data-platform"
GCS_BUCKET = "olist-data-lake-nagela"
GCP_CONN_ID = "google_cloud_default"
BQ_LOCATION = "EU"

RAW_DATASET = "olist_raw"
TMP_DATASET = "olist_raw_tmp"

GCS_BASE_PATH = "olist/raw"
DEFAULT_DS = "2018-10-01"  # one-shot batch date

FILES_TO_TABLES = {
    "olist_customers_dataset.csv": "customers",
    "olist_geolocation_dataset.csv": "geolocation",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "order_payments",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_orders_dataset.csv": "orders",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "product_category_name_translation.csv": "product_category_name_translation",
}

default_args = {"owner": "data-platform", "retries": 1}

# Airflow pool used to serialize BigQuery jobs (create it via `airflow pools set`)
BQ_POOL = "bigquery_serial"


def _check_gcs_batch_exists(**_):
    """
    Guard rail:
    Validates that gs://<bucket>/olist/raw/dt=<DEFAULT_DS>/ exists
    and that all expected CSV files are present.
    """
    ds = DEFAULT_DS
    prefix = f"{GCS_BASE_PATH}/dt={ds}/"

    hook = GCSHook(gcp_conn_id=GCP_CONN_ID)
    objs = hook.list(bucket_name=GCS_BUCKET, prefix=prefix)

    if not objs:
        raise AirflowFailException(
            f"[GCS CHECK] No objects found at gs://{GCS_BUCKET}/{prefix}. "
            f"Make sure you uploaded the batch files for dt={ds}."
        )

    expected = {f"{prefix}{fname}" for fname in FILES_TO_TABLES.keys()}
    found = set(objs)
    missing = sorted(expected - found)

    if missing:
        missing_pretty = "\n".join([f"- gs://{GCS_BUCKET}/{m}" for m in missing])
        raise AirflowFailException(
            f"[GCS CHECK] Batch dt={ds} exists, but some expected files are missing:\n{missing_pretty}"
        )


# =====================================================
# DAG
# =====================================================
with DAG(
    dag_id="01_olist_raw_ingestion_once",
    description="Olist one-shot (serial): GCS CSV -> BQ tmp (truncate) -> BQ raw partitioned (delete+insert)",
    start_date=datetime(2018, 10, 1),
    schedule=None,
    catchup=False,
    default_args=default_args,
    tags=["olist", "raw", "batch", "bigquery"],
    max_active_runs=1,
    max_active_tasks=1,  # optional: keep if your VM is very small / unstable
) as dag:

    check_gcs_batch = PythonOperator(
        task_id="check_gcs_batch",
        python_callable=_check_gcs_batch_exists,
    )

    ensure_raw_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id="ensure_raw_dataset",
        project_id=PROJECT_ID,
        dataset_id=RAW_DATASET,
        location=BQ_LOCATION,
        gcp_conn_id=GCP_CONN_ID,
        exists_ok=True,
        pool=BQ_POOL,
    )

    ensure_tmp_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id="ensure_tmp_dataset",
        project_id=PROJECT_ID,
        dataset_id=TMP_DATASET,
        location=BQ_LOCATION,
        gcp_conn_id=GCP_CONN_ID,
        exists_ok=True,
        pool=BQ_POOL,
    )

    with TaskGroup(group_id="load_all_tables") as load_all_tables:
        previous = None  # enforce full serialization across tables

        for filename, table in FILES_TO_TABLES.items():
            gcs_uri = f"gs://{GCS_BUCKET}/{GCS_BASE_PATH}/dt={DEFAULT_DS}/{filename}"

            tmp_table_id = f"{PROJECT_ID}.{TMP_DATASET}.{table}__tmp"
            raw_table_id = f"{PROJECT_ID}.{RAW_DATASET}.{table}"

            load_to_tmp = BigQueryInsertJobOperator(
                task_id=f"bq_load_tmp__{table}",
                gcp_conn_id=GCP_CONN_ID,
                location=BQ_LOCATION,
                pool=BQ_POOL,
                configuration={
                    "load": {
                        "sourceUris": [gcs_uri],
                        "destinationTable": {
                            "projectId": PROJECT_ID,
                            "datasetId": TMP_DATASET,
                            "tableId": f"{table}__tmp",
                        },
                        "sourceFormat": "CSV",
                        "skipLeadingRows": 1,
                        "autodetect": True,
                        "writeDisposition": "WRITE_TRUNCATE",
                        "createDisposition": "CREATE_IF_NEEDED",
                        "allowQuotedNewlines": True,
                        "allowJaggedRows": False,
                    }
                },
            )

            upsert_partition = BigQueryInsertJobOperator(
                task_id=f"bq_upsert_partition__{table}",
                gcp_conn_id=GCP_CONN_ID,
                location=BQ_LOCATION,
                pool=BQ_POOL,
                configuration={
                    "query": {
                        "useLegacySql": False,
                        "query": f"""
                        -- 1) Create RAW table on first run, with ingestion metadata
                        CREATE TABLE IF NOT EXISTS `{raw_table_id}`
                        PARTITION BY load_date AS
                        SELECT
                          t.*,
                          DATE('{DEFAULT_DS}') AS load_date,
                          CURRENT_TIMESTAMP() AS ingestion_ts,
                          '{filename}' AS source_file,
                          '{gcs_uri}' AS source_uri
                        FROM `{tmp_table_id}` AS t
                        WHERE 1=0;

                        -- 2) Partition-level idempotency
                        DELETE FROM `{raw_table_id}`
                        WHERE load_date = DATE('{DEFAULT_DS}');

                        -- 3) Re-insert partition
                        INSERT INTO `{raw_table_id}`
                        SELECT
                          t.*,
                          DATE('{DEFAULT_DS}') AS load_date,
                          CURRENT_TIMESTAMP() AS ingestion_ts,
                          '{filename}' AS source_file,
                          '{gcs_uri}' AS source_uri
                        FROM `{tmp_table_id}` AS t;
                        """,
                    }
                },
            )

            load_to_tmp >> upsert_partition

            # Serialize table-to-table execution as well
            if previous:
                previous >> load_to_tmp
            previous = upsert_partition

    check_gcs_batch >> ensure_raw_dataset >> ensure_tmp_dataset >> load_all_tables

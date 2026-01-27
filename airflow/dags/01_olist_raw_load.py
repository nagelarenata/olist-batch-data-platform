from __future__ import annotations

from datetime import datetime

from airflow import DAG
from airflow.utils.task_group import TaskGroup

from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCreateEmptyDatasetOperator,
    BigQueryInsertJobOperator,
)

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

# =====================================================
# DAG
# =====================================================
with DAG(
    dag_id="01_olist_raw_ingestion",
    description="Olist batch (dt={{ ds }}): GCS CSV -> BQ tmp (truncate) -> BQ raw partitioned (delete+insert)",
    start_date=datetime(2018, 10, 1),
    schedule=None,
    catchup=False,
    default_args=default_args,
    tags=["olist", "raw", "batch", "bigquery"],
) as dag:

    ensure_raw_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id="ensure_raw_dataset",
        project_id=PROJECT_ID,
        dataset_id=RAW_DATASET,
        location=BQ_LOCATION,
        gcp_conn_id=GCP_CONN_ID,
        exists_ok=True,
    )

    ensure_tmp_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id="ensure_tmp_dataset",
        project_id=PROJECT_ID,
        dataset_id=TMP_DATASET,
        location=BQ_LOCATION,
        gcp_conn_id=GCP_CONN_ID,
        exists_ok=True,
    )

    with TaskGroup(group_id="load_all_tables") as load_all_tables:
        for filename, table in FILES_TO_TABLES.items():
            gcs_uri = f"gs://{GCS_BUCKET}/{GCS_BASE_PATH}/dt={{{{ ds }}}}/{filename}"

            tmp_table_id = f"{PROJECT_ID}.{TMP_DATASET}.{table}__tmp"
            raw_table_id = f"{PROJECT_ID}.{RAW_DATASET}.{table}"

            load_to_tmp = BigQueryInsertJobOperator(
                task_id=f"bq_load_tmp__{table}",
                gcp_conn_id=GCP_CONN_ID,
                location=BQ_LOCATION,
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
                configuration={
                    "query": {
                        "useLegacySql": False,
                        "query": f"""
                        -- 1) Cria a tabela RAW particionada (primeira vez)
                        --    (schema é inferido a partir do TMP + metadata)
                        CREATE TABLE IF NOT EXISTS `{raw_table_id}`
                        PARTITION BY load_date AS
                        SELECT
                          t.*,
                          DATE('{{{{ ds }}}}') AS load_date,
                          CURRENT_TIMESTAMP() AS ingestion_ts,
                          '{filename}' AS source_file,
                          '{gcs_uri}' AS source_uri
                        FROM `{tmp_table_id}` AS t
                        WHERE 1=0;

                        -- 2) Idempotência por partição
                        DELETE FROM `{raw_table_id}`
                        WHERE load_date = DATE('{{{{ ds }}}}');

                        -- 3) Insere a partição do dia (append controlado)
                        INSERT INTO `{raw_table_id}`
                        SELECT
                          t.*,
                          DATE('{{{{ ds }}}}') AS load_date,
                          CURRENT_TIMESTAMP() AS ingestion_ts,
                          '{filename}' AS source_file,
                          '{gcs_uri}' AS source_uri
                        FROM `{tmp_table_id}` AS t;
                        """,
                    }
                },
            )

            load_to_tmp >> upsert_partition

    ensure_raw_dataset >> ensure_tmp_dataset >> load_all_tables

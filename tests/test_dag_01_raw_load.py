import pytest
from unittest.mock import MagicMock, patch
from airflow.models import DagBag
from airflow.exceptions import AirflowFailException

from conftest import DAGS_FOLDER, load_dag_module

DAG_ID = "01_olist_raw_ingestion_once"

# 9 source files × 2 tasks each (bq_load_tmp + bq_upsert_partition)
# + check_gcs_batch + ensure_raw_dataset + ensure_tmp_dataset + trigger_dbt_build
EXPECTED_TASK_COUNT = 22


@pytest.fixture(scope="module")
def dagbag():
    return DagBag(dag_folder=DAGS_FOLDER, include_examples=False)


@pytest.fixture(scope="module")
def dag(dagbag):
    return dagbag.get_dag(DAG_ID)


@pytest.fixture(scope="module")
def dag_module():
    return load_dag_module("01_olist_raw_load.py", "dag_raw_load")


# =====================================================
# DAG structure
# =====================================================


class TestDag01Structure:
    def test_dag_loads_without_errors(self, dagbag):
        assert DAG_ID not in dagbag.import_errors, dagbag.import_errors.get(DAG_ID)

    def test_dag_exists(self, dag):
        assert dag is not None

    def test_dag_id(self, dag):
        assert dag.dag_id == DAG_ID

    def test_schedule_is_none(self, dag):
        assert dag.schedule_interval is None

    def test_max_active_runs(self, dag):
        assert dag.max_active_runs == 1

    def test_tags(self, dag):
        assert set(dag.tags) == {"olist", "raw", "batch", "bigquery"}

    def test_task_count(self, dag):
        assert len(dag.tasks) == EXPECTED_TASK_COUNT

    def test_required_task_ids_exist(self, dag):
        task_ids = dag.task_ids
        assert "check_gcs_batch" in task_ids
        assert "ensure_raw_dataset" in task_ids
        assert "ensure_tmp_dataset" in task_ids
        assert "trigger_dbt_build" in task_ids

    def test_trigger_is_downstream_of_load_all_tables(self, dag):
        trigger_task = dag.get_task("trigger_dbt_build")
        upstream_ids = {t.task_id for t in trigger_task.upstream_list}
        assert any("load_all_tables" in uid for uid in upstream_ids)

    def test_trigger_points_to_dag_02(self, dag):
        trigger_task = dag.get_task("trigger_dbt_build")
        assert trigger_task.trigger_dag_id == "02_olist_dbt_build"

    def test_trigger_does_not_wait_for_completion(self, dag):
        trigger_task = dag.get_task("trigger_dbt_build")
        assert trigger_task.wait_for_completion is False


# =====================================================
# _check_gcs_batch_exists logic
# =====================================================


class TestCheckGcsBatchExists:
    def test_raises_when_bucket_is_empty(self, dag_module):
        mock_hook = MagicMock()
        mock_hook.list.return_value = []

        with patch.object(dag_module, "GCSHook", return_value=mock_hook):
            with pytest.raises(AirflowFailException, match="No objects found"):
                dag_module._check_gcs_batch_exists()

    def test_raises_when_files_are_missing(self, dag_module):
        mock_hook = MagicMock()
        # Return only one file instead of all expected files
        prefix = f"olist/raw/dt={dag_module.DEFAULT_DS}/"
        mock_hook.list.return_value = [f"{prefix}olist_customers_dataset.csv"]

        with patch.object(dag_module, "GCSHook", return_value=mock_hook):
            with pytest.raises(AirflowFailException, match="missing"):
                dag_module._check_gcs_batch_exists()

    def test_passes_when_all_files_present(self, dag_module):
        mock_hook = MagicMock()
        prefix = f"olist/raw/dt={dag_module.DEFAULT_DS}/"
        all_files = [f"{prefix}{fname}" for fname in dag_module.FILES_TO_TABLES.keys()]
        mock_hook.list.return_value = all_files

        with patch.object(dag_module, "GCSHook", return_value=mock_hook):
            # Should not raise
            dag_module._check_gcs_batch_exists()

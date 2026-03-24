import pytest
from airflow.models import DagBag

from conftest import DAGS_FOLDER

DAG_ID = "02_olist_dbt_build"


@pytest.fixture(scope="module")
def dagbag():
    return DagBag(dag_folder=DAGS_FOLDER, include_examples=False)


@pytest.fixture(scope="module")
def dag(dagbag):
    return dagbag.dags.get(DAG_ID)


@pytest.fixture(scope="module")
def dbt_build_task(dag):
    return dag.get_task("dbt_build")


# =====================================================
# DAG structure
# =====================================================


class TestDag02Structure:
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
        assert set(dag.tags) == {"olist", "dbt", "gold", "analytics"}

    def test_task_count(self, dag):
        assert len(dag.tasks) == 3

    def test_required_task_ids_exist(self, dag):
        assert "dbt_deps" in dag.task_ids
        assert "dbt_source_freshness" in dag.task_ids
        assert "dbt_build" in dag.task_ids

    def test_task_order(self, dag):
        deps_task = dag.get_task("dbt_deps")
        freshness_task = dag.get_task("dbt_source_freshness")
        build_task = dag.get_task("dbt_build")
        assert freshness_task in deps_task.downstream_list
        assert build_task in freshness_task.downstream_list


# =====================================================
# dbt_build task configuration
# =====================================================


class TestDbtBuildTask:
    def test_command_contains_dbt_build(self, dbt_build_task):
        assert "dbt build" in dbt_build_task.bash_command

    def test_command_contains_project_dir(self, dbt_build_task):
        assert "--project-dir" in dbt_build_task.bash_command

    def test_command_contains_profiles_dir(self, dbt_build_task):
        assert "--profiles-dir" in dbt_build_task.bash_command

    def test_task_uses_bq_pool(self, dbt_build_task):
        assert dbt_build_task.pool == "bigquery_serial"

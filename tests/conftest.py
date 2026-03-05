import os
import sys
import importlib.util

# Resolve dags folder relative to this file:
# - Inside Docker container: /opt/airflow/tests/../dags = /opt/airflow/dags
# - Matches the mounted volume ./airflow/dags:/opt/airflow/dags
DAGS_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "dags")


def load_dag_module(filename: str, module_alias: str):
    """
    Load a DAG module by filename using importlib.
    Required because DAG filenames start with digits (e.g. 01_olist_raw_load.py),
    which are not valid Python identifiers for standard imports.
    """
    filepath = os.path.join(DAGS_FOLDER, filename)
    spec = importlib.util.spec_from_file_location(module_alias, filepath)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_alias] = module
    spec.loader.exec_module(module)
    return module

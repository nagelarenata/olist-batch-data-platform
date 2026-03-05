FROM apache/airflow:2.9.3-python3.11

USER airflow
RUN pip install --no-cache-dir dbt-bigquery==1.11.0 pytest pytest-cov black

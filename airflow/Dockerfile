FROM apache/airflow:2.6.3
USER root
RUN apt-get update && apt-get install -y --no-install-recommends gcc
USER airflow
RUN pip install --no-cache-dir apache-airflow-providers-openlineage
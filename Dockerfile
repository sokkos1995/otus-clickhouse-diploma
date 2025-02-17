FROM python:3.8 

ENV AIRFLOW_HOME=/usr/local/airflow

ARG AIRFLOW_VERSION=2.1.4

ENV AIRFLOW__CORE__DAGS_FOLDER=/usr/local/airflow/dags 
ENV AIRFLOW__CORE__PLUGINS_FOLDER=/usr/local/airflow/plugins

ENV AIRFLOW__CORE__EXECUTOR=LocalExecutor
ENV AIRFLOW__CORE__SQL_ALCHEMY_CONN="postgresql+psycopg2://otus:otus_diploma@postgres:5432/airflow"

ENV AIRFLOW__CORE__LOAD_EXAMPLES=False

RUN pip install apache-airflow[postgres]==${AIRFLOW_VERSION}

RUN pip install airflow-code-editor
RUN pip install black fs-s3fs fs-gcsfs pandas clickhouse-driver requests

RUN mkdir /project
COPY ./airflow/scripts/ /project/scripts/
RUN chmod +x /project/scripts/init.sh

ENTRYPOINT ["/project/scripts/init.sh"]
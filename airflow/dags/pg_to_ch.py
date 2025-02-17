from datetime import datetime, timedelta, date
import logging as log
import pandas as pd
from sqlalchemy import create_engine
from clickhouse_driver import Client

from airflow.models import DAG
from airflow.operators.python import PythonOperator
from airflow.models.connection import Connection

CH_HOST = 'clickhouse1'
CH_PORT = 9000
CH_USER = 'default'
CH_PASSWORD = ''


def pg_to_ch():
    '''
    Downloads a random dataset from the web and inserts it into ClickHouse
    '''
    # Отправляем запрос к апи
    log.info('PG to CH')
    pg_engine = create_engine('postgresql://otus:otus_diploma@postgres:5432/airflow')
    df = pd.read_sql_table('dag_run', pg_engine)

    # загружаем данные в кликхаус
    conn = Connection.get_connection_from_secrets('ch_1')

    # clickhouse = Client(
    #     host=conn.host,
    #     port=conn.port,
    #     user=conn.login,
    #     password=conn.password,
    #     settings={"use_numpy":True}
    # )
    clickhouse = Client(
        host='clickhouse1',
        port=9000,
        user='default',
        password='',
        settings={"use_numpy":True}
    )  
    clickhouse.insert_dataframe('INSERT INTO prod.dag_run VALUES', df)
    log.info('data inserted')


with DAG(
    dag_id='pg_to_ch',
    start_date=datetime(2025, 2, 15),
    schedule_interval=None,
    description='Забираем данные из PostgreSQL и загружаем в кликхаус',
) as dag:
    pg_to_ch = PythonOperator(
        task_id='pg_to_ch',
        python_callable=pg_to_ch,
        retries=1,
        retry_delay=timedelta(minutes=1),
    ) 

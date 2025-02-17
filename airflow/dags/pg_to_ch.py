from datetime import datetime, timedelta, date
import logging as log
import pandas as pd
from sqlalchemy import create_engine
from clickhouse_driver import Client

from airflow.models import DAG
from airflow.operators.python import PythonOperator

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
    df = pd.read_sql_table('dag_code', pg_engine)

    # загружаем данные в кликхаус
    clickhouse = Client(
        host=CH_HOST,
        port=CH_PORT,
        user=CH_USER,
        password=CH_PASSWORD,
        settings={"use_numpy":True}
    )
    clickhouse.insert_dataframe('INSERT INTO ext.api_quotes (id, quote, year) VALUES', df)
    log.info('data inserted')

def optimize_table():
    '''
    We have table with ReplacingMT engine - start merge in order to replace data
    '''
    SQL = 'optimize table ext.api_quotes;'
    clickhouse = Client(
        host=CH_HOST,
        port=CH_PORT,
        user=CH_USER,
        password=CH_PASSWORD,
        settings={"use_numpy":True}
    )
    log.info(SQL)
    clickhouse.execute(SQL)
    log.info('Table optimized')


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

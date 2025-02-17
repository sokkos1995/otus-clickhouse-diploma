from datetime import datetime, timedelta, date
import logging as log
import requests
import pandas as pd
from clickhouse_driver import Client

from airflow.models import DAG
from airflow.operators.python import PythonOperator
from airflow.models.connection import Connection


def api_to_ch():
    '''
    Downloads a random dataset from the web and inserts it into ClickHouse
    '''
    # Отправляем запрос к апи
    log.info('API to CH')
    response = requests.get('https://kimiquotes.pages.dev/api/quotes')
    if response.status_code != 200:
        log.info(f'Api response {response.status_code}')
        log.info(f'Api response {response.text}')
        raise ValueError
    
    # Преобразуем данные в пандас датафрейм
    df = pd.DataFrame(response.json())

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
    clickhouse.insert_dataframe('INSERT INTO ext.api_quotes (id, quote, year) VALUES', df)
    log.info('data inserted')

def optimize_table():
    '''
    We have table with ReplacingMT engine - start merge in order to replace data
    '''
    SQL = 'optimize table ext.api_quotes;'
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
    log.info(SQL)
    clickhouse.execute(SQL)
    log.info('Table optimized')


with DAG(
    dag_id='kimi_raikkonen_api',
    start_date=datetime(2025, 2, 15),
    schedule_interval=None,
    description='Забираем данные из открытого апи и загружаем в кликхаус',
) as dag:
    api_to_ch = PythonOperator(
        task_id='api_to_ch',
        python_callable=api_to_ch,
        retries=1,
        retry_delay=timedelta(minutes=1),
    ) 
    optimize_table = PythonOperator(
        task_id='optimize_table',
        python_callable=optimize_table,
        retries=1,
        retry_delay=timedelta(minutes=1),
    ) 

    api_to_ch >> optimize_table

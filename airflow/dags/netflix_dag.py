from datetime import datetime, timedelta, date
import logging as log
import os

from airflow.models import DAG
from airflow.operators.python import PythonOperator

import pandas as pd
from clickhouse_driver import Client

CH_HOST = 'clickhouse1'
CH_PORT = 9000
CH_USER = 'default'
CH_PASSWORD = ''

DROP_TABLE = 'drop table if exists default.netflix'
CREATE_TABLE = '''
create table default.netflix
(
    show_id String,
    type String,
    title String,
    director String,
    cast String,
    country String,
    date_added String,
    release_year UInt16,
    rating String,
    duration String,
    listed_in String,
    description String
)
engine=MergeTree
order by tuple()
'''

def create_table():
    '''
    создаем таблицу
    '''
    clickhouse = Client(
        host=CH_HOST,
        port=CH_PORT,
        user=CH_USER,
        password=CH_PASSWORD,
        settings={"use_numpy":True}
    )
    log.info(DROP_TABLE)
    clickhouse.execute(DROP_TABLE)
    log.info('table dropped')    
    log.info(CREATE_TABLE)
    clickhouse.execute(CREATE_TABLE)
    log.info('table created')

def api_to_ch():
    '''
    Downloads a random dataset from the web and inserts it into ClickHouse
    '''
    # скачиваем произвольный датасет
    log.info('API to CH')
    df = pd.read_csv("https://raw.githubusercontent.com/practiceprobs/datasets/main/netflix-titles/netflix-titles.csv")
    log.info('df downloaded')

    clickhouse = Client(
        host=CH_HOST,
        port=CH_PORT,
        user=CH_USER,
        password=CH_PASSWORD,
        settings={"use_numpy":True}
    )
    clickhouse.insert_dataframe('insert into default.netflix values ', df)
    log.info('data inserted')

def check_results():
    '''
    Checks the results of the ETL task by running a query and logging its results
    '''
    clickhouse = Client(
        host=CH_HOST,
        port=CH_PORT,
        user=CH_USER,
        password=CH_PASSWORD,
        settings={"use_numpy":True}
    )
    log.info('select count() from default.netflix')
    results = clickhouse.execute('select count() from default.netflix')
    log.info('Results: %s', results)


with DAG(
    dag_id='netflix_dag',
    start_date=datetime(2025, 2, 15),
    schedule_interval=None,
    description='Тестовая переливка',
) as dag:
    create_table = PythonOperator(
        task_id='create_table',
        python_callable=create_table,
        retries=1,
        retry_delay=timedelta(minutes=1),
    ) 
    api_to_ch = PythonOperator(
        task_id='api_to_ch',
        python_callable=api_to_ch,
        retries=1,
        retry_delay=timedelta(minutes=1),
    ) 
    check_results = PythonOperator(
        task_id='check_results',
        python_callable=check_results,
        retries=1,
        retry_delay=timedelta(minutes=1),
    ) 

    create_table >> api_to_ch >> check_results

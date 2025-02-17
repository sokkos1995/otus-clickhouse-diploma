from datetime import datetime, timedelta, date
import logging as log
import os

from airflow.models import DAG
from airflow.operators.python import PythonOperator, ShortCircuitOperator

import pandas as pd
from clickhouse_driver import Client

CH_HOST = 'clickhouse1'
CH_PORT = 9000
CH_USER = 'default'
CH_PASSWORD = ''

FULL_BACKUP = """
BACKUP ALL ON CLUSTER otus TO Disk('s3_backup', 'backup_{num}');
"""
INCREMENTAL_BACKUP = """
BACKUP ALL ON CLUSTER otus TO Disk('s3_backup', 'backup_{num}')
    SETTINGS base_backup = Disk('s3_backup', 'test_backups')
"""

def define_backup(**context):
    """
    """
    print(context)
    params = context.get('execution_date').strftime('%Y%m%d_%H')
    print(params)
    print(FULL_BACKUP.format(num=params))

def backup_full(**context):
    '''
    Делаем полный бэкап
    '''
    # clickhouse = Client(
    #     host=CH_HOST,
    #     port=CH_PORT,
    #     user=CH_USER,
    #     password=CH_PASSWORD,
    #     settings={"use_numpy":True}
    # )
    suffix = context.get('execution_date').strftime('%Y%m%d')
    log.info(FULL_BACKUP.format(num=suffix))
    # clickhouse.execute(FULL_BACKUP) 

def backup_incremental(**context):
    '''
    Делаем инкрементальный бэкап
    '''
    # clickhouse = Client(
    #     host=CH_HOST,
    #     port=CH_PORT,
    #     user=CH_USER,
    #     password=CH_PASSWORD,
    #     settings={"use_numpy":True}
    # )
    suffix = context.get('execution_date').strftime('%Y%m%d_%H')
    log.info(INCREMENTAL_BACKUP.format(num=suffix))
    # clickhouse.execute(INCREMENTAL_BACKUP)


with DAG(
    dag_id='backup_dag',
    start_date=datetime(2025, 2, 15),
    schedule_interval=None,
    description='Даг для осуществеления резервного копирования',
) as dag:
    
    # define_backup = ShortCircuitOperator(
    #     task_id='define_backup',
    #     python_callable=define_backup
    # )

    define_backup = PythonOperator(
        task_id='define_backup',
        python_callable=define_backup
    )    
        
    backup_full = PythonOperator(
        task_id='backup_full',
        python_callable=backup_full,
        retries=1,
        retry_delay=timedelta(minutes=1),
    ) 

    backup_incremental = PythonOperator(
        task_id='backup_incremental',
        python_callable=backup_incremental,
        retries=1,
        retry_delay=timedelta(minutes=1),
    )     

    define_backup >> [backup_full, backup_incremental]

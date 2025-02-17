from datetime import datetime, timedelta, date
import logging as log
import os
from dateutil.parser import parse

from airflow.models import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.models.connection import Connection

from clickhouse_driver import Client

FULL_BACKUP = """
BACKUP ALL ON CLUSTER otus TO Disk('s3_backup', 'backup_{num}');
"""
INCREMENTAL_BACKUP = """
BACKUP ALL ON CLUSTER otus TO Disk('s3_backup', 'backup_{num}')
    SETTINGS base_backup = Disk('s3_backup', 'test_backups')
"""


def backup_full(**context):
    '''
    Делаем полный бэкап
    '''
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
    suffix = context.get('execution_date').strftime('%Y%m%d')
    log.info(FULL_BACKUP.format(num=suffix))
    # clickhouse.execute(FULL_BACKUP) 

def backup_incremental(**context):
    '''
    Делаем инкрементальный бэкап
    '''
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
    suffix = context.get('execution_date').strftime('%Y%m%d_%H')
    log.info(INCREMENTAL_BACKUP.format(num=suffix))
    # clickhouse.execute(INCREMENTAL_BACKUP)


with DAG(
    dag_id='backup_dag',
    start_date=datetime(2025, 2, 15),
    schedule_interval='@hourly',
    catchup=False,
    description='Даг для осуществления резервного копирования',
) as dag:
    
    full_backup_condition = BranchPythonOperator(
        task_id='full_backup_condition',
        python_callable=lambda: 'backup_full' if parse(os.environ['AIRFLOW_CTX_EXECUTION_DATE']).hour == 3 and parse(os.environ['AIRFLOW_CTX_EXECUTION_DATE']).weekday() == 6 else 'backup_incremental',
        dag=dag
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

    full_backup_condition >> [backup_full, backup_incremental]

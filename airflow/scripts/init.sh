#!/bin/bash

sleep 10
airflow db init
sleep 10

airflow users create \
          --username admin \
          --firstname admin \
          --lastname admin \
          --role Admin \
          --email admin@example.org \
          -p 12345

airflow connections add 'ch_1' \
    --conn-type 'HTTP' \
    --conn-login 'default' \
    --conn-password '' \
    --conn-host 'clickhouse1' \
    --conn-port '9000' 

airflow connections add 'ch_2' \
    --conn-type 'HTTP' \
    --conn-login 'default' \
    --conn-password '' \
    --conn-host 'clickhouse2' \
    --conn-port '9000' 

airflow connections add 'pg' \
    --conn-type 'HTTP' \
    --conn-login 'default' \
    --conn-password '' \
    --conn-host 'clickhouse2' \
    --conn-port '9000'     

airflow scheduler & airflow webserver

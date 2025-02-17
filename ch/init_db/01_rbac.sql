-- создаем роли

-- observer_r
-- просто просмотр структуры таблиц
drop role if exists observer_r on cluster cluster;
CREATE ROLE observer_r on cluster cluster;
grant on cluster otus CLUSTER ON *.* to observer_r;
grant on cluster otus SHOW on *.* to observer_r;

-- analytic_r
-- имеет доступ ко всем основным аналитическим схемам на чтение и показ метаданных объектов
drop role if exists analytic_r on cluster cluster;
CREATE ROLE analytic_r on cluster cluster;
grant on cluster otus CLUSTER ON *.* to analytic_r;
grant on cluster otus SELECT on raw.* TO analytic_r;
grant on cluster otus SELECT on parsed.* TO analytic_r;
grant on cluster otus SELECT, dictGet on dict.*  TO analytic_r;
grant on cluster otus SELECT on ext.* TO analytic_r;
grant on cluster otus SELECT on prod.* TO analytic_r;
grant on cluster otus SELECT on datamart.* TO analytic_r;

-- data_engineer_r
-- + селект системных таблиц, убийство запросов и релоад словарей
drop role if exists data_engineer_r on cluster cluster;
CREATE ROLE data_engineer_r on cluster cluster;
grant on cluster otus SELECT on system.* TO data_engineer_r;
grant on cluster otus SOURCES ON *.*  TO data_engineer_r;
grant on cluster otus KILL QUERY ON *.* TO data_engineer_r;
grant on cluster otus SYSTEM RELOAD DICTIONARY ON *.* TO data_engineer_r;

-- airflow_r
-- имеет доступ ко всем основным аналитическим схемам на чтение и запись
drop role if exists airflow_r on cluster cluster;
CREATE ROLE airflow_r on cluster cluster;
grant on cluster otus CLUSTER ON *.* to airflow_r;
grant on cluster otus SELECT on raw.*  TO airflow_r;
grant on cluster otus SELECT on parsed.*  TO airflow_r;
grant on cluster otus SELECT, ALTER, CREATE, DROP, OPTIMIZE, dictGet on dict.*  TO airflow_r;
grant on cluster otus SELECT on airflow_metadata.*  TO airflow_r;
grant on cluster otus SELECT, INSERT, ALTER, CREATE, DROP, TRUNCATE, OPTIMIZE on ext.*  TO airflow_r;
grant on cluster otus SELECT, INSERT, ALTER, CREATE, DROP, TRUNCATE, OPTIMIZE on prod.*  TO airflow_r;
grant on cluster otus SELECT, INSERT, ALTER, CREATE, DROP, TRUNCATE, OPTIMIZE on datamart.*  TO airflow_r;
grant on cluster otus SOURCES ON *.*  TO airflow_r;
grant on cluster otus SYSTEM RELOAD DICTIONARY ON *.* TO airflow_r;

-- bi_r
-- имеет доступ ко всем основным аналитическим схемам на чтение, потенциально урежем сеттинги на запросы
drop role if exists bi_r on cluster cluster;
CREATE ROLE bi_r on cluster cluster;
grant on cluster otus SELECT on raw.* TO bi_r;
grant on cluster otus SELECT on parsed.*  TO bi_r;
grant on cluster otus SELECT, dictGet on dict.*  TO bi_r;
grant on cluster otus SELECT on airflow_metadata.*  TO bi_r;
grant on cluster otus SELECT on ext.*  TO bi_r;
grant on cluster otus SELECT on prod.*  TO bi_r;
grant on cluster otus SELECT on datamart.*  TO bi_r;

-- monitoring_r
-- расширение роли bi - добавляем доступ к системным таблицам
drop role if exists monitoring_r on cluster cluster;
CREATE ROLE monitoring_r on cluster cluster;
grant on cluster otus SELECT on system.* TO monitoring_r;

-- dba_r
drop role if exists dba_r on cluster cluster;
CREATE ROLE dba_r on cluster cluster;
grant on cluster otus dba_r on *.* TO dba_r;

-- создаем пользователей

-- выдаем гранты

-- создаем именованные коллекции

CREATE NAMED COLLECTION airflow_pg AS
    host = 'postgres',
    port = 5432,
    database = 'airflow',
    user = 'otus',
    password = 'otus_diploma',
    schema='public';
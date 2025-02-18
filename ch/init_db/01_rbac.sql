-- создаем роли

-- observer_r
-- просто просмотр структуры таблиц
drop role if exists observer_r on cluster otus;
CREATE ROLE observer_r on cluster otus;
grant on cluster otus CLUSTER ON *.* to observer_r;
grant on cluster otus SHOW on *.* to observer_r;

-- analytic_r
-- имеет доступ ко всем основным аналитическим схемам на чтение и показ метаданных объектов
drop role if exists analytic_r on cluster otus;
CREATE ROLE analytic_r on cluster otus;
grant on cluster otus CLUSTER ON *.* to analytic_r;
grant on cluster otus SELECT on raw.* TO analytic_r;
grant on cluster otus SELECT on parsed.* TO analytic_r;
grant on cluster otus SELECT, dictGet on dict.*  TO analytic_r;
grant on cluster otus SELECT on ext.* TO analytic_r;
grant on cluster otus SELECT on prod.* TO analytic_r;
grant on cluster otus SELECT on datamart.* TO analytic_r;

-- data_engineer_r
-- + селект системных таблиц, убийство запросов и релоад словарей
drop role if exists data_engineer_r on cluster otus;
CREATE ROLE data_engineer_r on cluster otus;
grant on cluster otus SELECT on system.* TO data_engineer_r;
grant on cluster otus SOURCES ON *.*  TO data_engineer_r;
grant on cluster otus KILL QUERY ON *.* TO data_engineer_r;
grant on cluster otus SYSTEM RELOAD DICTIONARY ON *.* TO data_engineer_r;

-- airflow_r
-- имеет доступ ко всем основным аналитическим схемам на чтение и запись
drop role if exists airflow_r on cluster otus;
CREATE ROLE airflow_r on cluster otus;
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
drop role if exists bi_r on cluster otus;
CREATE ROLE bi_r on cluster otus;
grant on cluster otus SELECT on raw.* TO bi_r;
grant on cluster otus SELECT on parsed.*  TO bi_r;
grant on cluster otus SELECT, dictGet on dict.*  TO bi_r;
grant on cluster otus SELECT on airflow_metadata.*  TO bi_r;
grant on cluster otus SELECT on ext.*  TO bi_r;
grant on cluster otus SELECT on prod.*  TO bi_r;
grant on cluster otus SELECT on datamart.*  TO bi_r;

-- monitoring_r
-- расширение роли bi - добавляем доступ к системным таблицам
drop role if exists monitoring_r on cluster otus;
CREATE ROLE monitoring_r on cluster otus;
grant on cluster otus SELECT on system.* TO monitoring_r;

-- создаем пользователей и выдаем гранты
drop user if exists student ON CLUSTER otus;
CREATE USER student ON CLUSTER otus IDENTIFIED WITH sha256_password BY 'student_otus';
GRANT ON CLUSTER otus observer_r TO student;
GRANT ON CLUSTER otus analytic_r TO student;

drop user if exists teacher ON CLUSTER otus;
CREATE USER teacher ON CLUSTER otus IDENTIFIED WITH sha256_password BY 'teacher_otus';
GRANT ON CLUSTER otus observer_r TO teacher;
GRANT ON CLUSTER otus analytic_r TO teacher;
GRANT ON CLUSTER otus data_engineer_r TO teacher;
GRANT ON CLUSTER otus bi_r TO teacher;
GRANT ON CLUSTER otus monitoring_r TO teacher;

drop user if exists airflow ON CLUSTER otus;
CREATE USER airflow ON CLUSTER otus IDENTIFIED WITH sha256_password BY 'airflow_otus';
GRANT ON CLUSTER otus airflow_r TO airflow;

drop user if exists bi ON CLUSTER otus;
CREATE USER bi ON CLUSTER otus IDENTIFIED WITH sha256_password BY 'bi_otus';
GRANT ON CLUSTER otus bi_r TO bi;

-- настраиваем квоты и сеттинги
drop settings profile if exists bi_timeout_profile ON CLUSTER otus;
CREATE SETTINGS PROFILE bi_timeout_profile ON CLUSTER otus
SETTINGS max_execution_time = 5;
ALTER USER bi SETTINGS PROFILE bi_timeout_profile;

drop QUOTA if exists five_errors_quota ON CLUSTER otus;
CREATE QUOTA five_errors_quota ON CLUSTER otus
FOR INTERVAL 1 hour MAX errors = 5
TO student;

-- создаем именованные коллекции
drop NAMED COLLECTION if exists airflow_pg on cluster otus;
CREATE NAMED COLLECTION airflow_pg on cluster otus AS
    host = 'postgres',
    port = 5432,
    database = 'airflow',
    user = 'otus',
    password = 'otus_diploma',
    schema='public';
-- создаем схемы

DROP DATABASE IF EXISTS streams ON CLUSTER otus;
DROP DATABASE IF EXISTS raw ON CLUSTER otus;
DROP DATABASE IF EXISTS parsed ON CLUSTER otus;
DROP DATABASE IF EXISTS dict ON CLUSTER otus;
DROP DATABASE IF EXISTS airflow_metadata ON CLUSTER otus;
DROP DATABASE IF EXISTS ext ON CLUSTER otus;
DROP DATABASE IF EXISTS prod ON CLUSTER otus;
DROP DATABASE IF EXISTS datamart ON CLUSTER otus;

CREATE DATABASE IF NOT EXISTS streams ON CLUSTER otus COMMENT 'База данных с консьюмерами кафки';
CREATE DATABASE IF NOT EXISTS raw ON CLUSTER otus COMMENT 'База данных с сырыми данными из кафки';
CREATE DATABASE IF NOT EXISTS parsed ON CLUSTER otus COMMENT 'База данных с распаршенными данными из кафки';
CREATE DATABASE IF NOT EXISTS dict ON CLUSTER otus COMMENT 'База данных со словарями';
CREATE DATABASE IF NOT EXISTS airflow_metadata ON CLUSTER otus COMMENT 'База данных с метаданными Airflow';
CREATE DATABASE IF NOT EXISTS ext ON CLUSTER otus COMMENT 'База данных, куда складываем данные из внешних систем (апи, парсинг и тд)'; 
CREATE DATABASE IF NOT EXISTS prod ON CLUSTER otus COMMENT 'База данных, куда складываем данные из прода (ОЛТП базы данных)';
CREATE DATABASE IF NOT EXISTS datamart ON CLUSTER otus COMMENT 'Основная БД для запросов со стороны BI';

-- создаем таблицы

-- схема stream

-- TODO посмотреть как считываются данные (не будет ли дублей или пропусков?)
drop table if exists streams.sensor_data on cluster otus;
CREATE TABLE streams.sensor_data on cluster otus
(
    `message` String
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'kafka1:9092',
         kafka_topic_list = 'sensor_data',
         kafka_format = 'JSONAsString',
         kafka_group_name = 'ch_consumer'
;

-- схема raw

create table if not exists raw.sensor_data_raw on cluster otus
(
    message          String,
    _topic           LowCardinality(String),
    _offset          UInt64,
    _timestamp_ms    DateTime64,
    _partition       UInt8,
    _row_created     DateTime64(3) default now64() comment 'Дата и время записи в БД'
)
engine = ReplicatedMergeTree 
ORDER BY _timestamp_ms
comment 'Сырые данные из кафки, обогащенные метаданными';

CREATE MATERIALIZED VIEW streams.sensor_data_raw_mv on cluster otus
    TO raw.sensor_data_raw
AS
SELECT message,
       _topic,
       _offset,
       _timestamp_ms,
       _partition,
       now64() AS _row_created
FROM streams.sensor_data;

-- схема dict

DROP DICTIONARY IF EXISTS dict.airflow_ab_user_role on cluster otus;
CREATE DICTIONARY IF NOT EXISTS dict.airflow_ab_user_role ON CLUSTER otus
(
	id      UInt8,
	user_id UInt8,
	role_id UInt8
)
PRIMARY KEY id
SOURCE(POSTGRESQL(NAME airflow_pg TABLE 'ab_user_role'))
LIFETIME(MIN 86400 MAX 126000)
LAYOUT(hashed())
;

DROP DICTIONARY IF EXISTS dict.airflow_ab_role on cluster otus;
CREATE DICTIONARY IF NOT EXISTS dict.airflow_ab_role ON CLUSTER otus
(
	id   UInt8,
	name String
)
PRIMARY KEY id
SOURCE(POSTGRESQL(NAME airflow_pg TABLE 'ab_role'))
LIFETIME(MIN 86400 MAX 126000)
LAYOUT(hashed())
;

DROP DICTIONARY IF EXISTS dict.airflow_ab_user on cluster otus;
CREATE DICTIONARY IF NOT EXISTS dict.airflow_ab_user ON CLUSTER otus
(
	id               UInt8 ,
	first_name       String ,
	last_name        String ,
	username         String ,
	"password"       varchar(256),
	active           UInt8,
	email            String ,
	last_login       DateTime,
	login_count      UInt8,
	fail_login_count UInt8,
	created_on       DateTime,
	changed_on       DateTime,
	created_by_fk    UInt8,
	changed_by_fk    UInt8
)
PRIMARY KEY id
SOURCE(POSTGRESQL(NAME airflow_pg TABLE 'ab_user'))
LIFETIME(MIN 86400 MAX 126000)
LAYOUT(hashed())
;

-- схема ext

CREATE TABLE ext.api_quotes on cluster otus
(
    id           UInt16 COMMENT 'Айди цитаты',
    quote        String COMMENT 'Цитата',
    year         UInt16 COMMENT 'Год цитаты',
    _row_created DateTime64(3) default now64() COMMENT 'Таймстап вставки'
)
ENGINE = ReplicatedReplacingMergeTree(_row_created)
order by id
;

-- схема datamart

CREATE TABLE datamart.trips ON CLUSTER otus
(
    trip_id             UInt32,
    pickup_datetime     DateTime,
    dropoff_datetime    DateTime,
    pickup_longitude    Nullable(Float64),
    pickup_latitude     Nullable(Float64),
    dropoff_longitude   Nullable(Float64),
    dropoff_latitude    Nullable(Float64),
    passenger_count     UInt8,
    trip_distance       Float32,
    fare_amount         Float32,
    extra               Float32,
    tip_amount          Float32,
    tolls_amount        Float32,
    total_amount        Float32,
    payment_type        Enum('CSH' = 1, 'CRE' = 2, 'NOC' = 3, 'DIS' = 4, 'UNK' = 5),
    pickup_ntaname      LowCardinality(String),
    dropoff_ntaname     LowCardinality(String)
)
ENGINE = ReplicatedMergeTree
PRIMARY KEY (pickup_datetime, dropoff_datetime)
;

INSERT INTO datamart.trips
SELECT
    trip_id,
    pickup_datetime,
    dropoff_datetime,
    pickup_longitude,
    pickup_latitude,
    dropoff_longitude,
    dropoff_latitude,
    passenger_count,
    trip_distance,
    fare_amount,
    extra,
    tip_amount,
    tolls_amount,
    total_amount,
    payment_type,
    pickup_ntaname,
    dropoff_ntaname
FROM s3(
    'https://datasets-documentation.s3.eu-west-3.amazonaws.com/nyc-taxi/trips_{0..2}.gz',
    'TabSeparatedWithNames'
)
;
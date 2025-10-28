-- Create database for Hive Metastore
CREATE DATABASE IF NOT EXISTS metastore;

-- Create user for Hive Metastore
CREATE USER IF NOT EXISTS 'hive'@'%' IDENTIFIED BY 'hive123';
GRANT ALL PRIVILEGES ON metastore.* TO 'hive'@'%';

-- Create database for Airflow
CREATE DATABASE IF NOT EXISTS airflow;

-- Create user for Airflow
CREATE USER IF NOT EXISTS 'airflow'@'%' IDENTIFIED BY 'airflow123';
GRANT ALL PRIVILEGES ON airflow.* TO 'airflow'@'%';

FLUSH PRIVILEGES;

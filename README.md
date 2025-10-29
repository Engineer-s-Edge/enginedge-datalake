# EnginEdge Data Lake

A comprehensive local data lake setup with modern big data tools including MinIO, Apache Spark, Trino, Apache Airflow, and Jupyter Lab.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Data Sources  │    │  Object Storage │    │ Query Engines   │
│                 │ → │     (MinIO)     │ ← │    (Trino)      │
│  • Files        │    │                 │    │                 │
│  • APIs         │    │  S3-Compatible  │    │  SQL Interface  │
│  • Databases    │    └─────────────────┘    └─────────────────┘
└─────────────────┘             │                       │
                                │                       │
┌─────────────────┐             ↓                       ↓
│   Orchestration │    ┌─────────────────┐    ┌─────────────────┐
│                 │    │  Data Processing│    │    Analytics    │
│   Apache        │ → │  (Apache Spark) │ ← │   (Jupyter)     │
│   Airflow       │    │                 │    │                 │
│                 │    │  Distributed    │    │  Notebooks      │
└─────────────────┘    │  Computing      │    │  Visualization  │
                       └─────────────────┘    └─────────────────┘
                                │
                                ↓
                       ┌─────────────────┐
                       │   Metadata      │
                       │  (PostgreSQL +  │
                       │ Hive Metastore) │
                       └─────────────────┘
```

## Components

### 🗄️ Object Storage (MinIO)
- **Purpose**: S3-compatible object storage for data lake files
- **Port**: 9000 (API), 9001 (Console)
- **Use Cases**: Store raw data, processed data, backups

### ⚡ Data Processing (Apache Spark)
- **Purpose**: Distributed data processing and analytics
- **Master Port**: 8080
- **Worker Port**: 8081
- **Use Cases**: ETL jobs, batch processing, machine learning

### 🔍 Query Engine (Trino)
- **Purpose**: Distributed SQL query engine
- **Port**: 8090
- **Use Cases**: Interactive queries, data exploration, reporting

### 🔄 Orchestration (Apache Airflow)
- **Purpose**: Workflow orchestration and scheduling
- **Port**: 8082
- **Use Cases**: ETL pipelines, data workflows, job scheduling

### 📊 Analytics (Jupyter Lab)
- **Purpose**: Interactive data analysis and visualization
- **Port**: 8888
- **Use Cases**: Data exploration, prototyping, visualization

### 🗃️ Metadata Store (PostgreSQL + Hive Metastore)
- **Purpose**: Store table schemas and metadata
- **Port**: 5432
- **Use Cases**: Table definitions, data catalog, lineage

## Quick Start

### Prerequisites
- Docker and Docker Compose
- PowerShell (Windows) or Bash (Linux/Mac)
- At least 4GB RAM available for containers

### Launch the Data Lake
1. Create a `.env` file from the `.env.example` file and configure the credentials.
2. Run the launch script:
```powershell
# Windows PowerShell
.\launch-datalake.ps1
```

```bash
# Linux/Mac
docker-compose up -d
```

### Access the Services

| Service | URL |
|---------|-----|
| MinIO Console | http://localhost:9001 |
| Spark Master | http://localhost:8080 |
| Trino | http://localhost:8090 |
| Airflow | http://localhost:8082 |
| Jupyter Lab | http://localhost:8888 |

## Configuration
Create a `.env` file in the root of the project and add the following environment variables:
```
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123
POSTGRES_USER=airflow
POSTGRES_PASSWORD=airflow
POSTGRES_DB=airflow
AIRFLOW_USER=admin
AIRFLOW_PASSWORD=admin123
JUPYTER_TOKEN=jupyter123
```

## Getting Started Guide

### 1. First Steps
1. Launch the data lake using the script above
2. Open Jupyter Lab at http://localhost:8888
3. Run the `Getting_Started.ipynb` notebook
4. Explore the MinIO console to see your data

### 2. Upload Sample Data
```python
import boto3
import os

# Connect to MinIO
s3_client = boto3.client(
    's3',
    endpoint_url='http://localhost:9000',
    aws_access_key_id=os.environ['MINIO_ROOT_USER'],
    aws_secret_access_key=os.environ['MINIO_ROOT_PASSWORD']
)

# Create bucket and upload data
s3_client.create_bucket(Bucket='my-data')
# ... upload your files
```

### 3. Process Data with Spark
```python
from pyspark.sql import SparkSession
import os

spark = SparkSession.builder \
    .appName("MyDataLakeJob") \
    .master("spark://localhost:7077") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://localhost:9000") \
    .config("spark.hadoop.fs.s3a.access.key", os.environ['MINIO_ROOT_USER']) \
    .config("spark.hadoop.fs.s3a.secret.key", os.environ['MINIO_ROOT_PASSWORD']) \
    .getOrCreate()

# Read data from MinIO
df = spark.read.csv("s3a://my-data/my-file.csv", header=True)
df.show()
```

### 4. Query with Trino
```sql
-- Connect to Trino and query your data
SELECT * FROM hive.default.my_table LIMIT 10;
```

### 5. Create Airflow DAGs
Create Python files in `./airflow/dags/` to define your data pipelines.

## Directory Structure
```
.
├── docker-compose.yml
├── launch-datalake.ps1
├── airflow/
│   ├── dags/
│   └── plugins/
├── data/
├── notebooks/
│   └── Getting_Started.ipynb
├── postgres/
│   └── init/
├── spark/
│   ├── conf/
│   ├── jars/
│   └── apps/
└── trino/
    ├── etc/
    └── catalog/
```

## Common Tasks

### Create a New Bucket in MinIO
```python
import boto3
import os

s3_client = boto3.client(
    's3',
    endpoint_url='http://localhost:9000',
    aws_access_key_id=os.environ['MINIO_ROOT_USER'],
    aws_secret_access_key=os.environ['MINIO_ROOT_PASSWORD']
)

s3_client.create_bucket(Bucket='new-bucket')
```

### Submit a Spark Job
```bash
docker exec -it spark-master spark-submit \
    --master spark://spark-master:7077 \
    /opt/spark-apps/my-job.py
```

### Create a Trino Table
```sql
CREATE TABLE hive.default.my_table (
    id bigint,
    name varchar,
    value double
)
WITH (
    external_location = 's3a://my-bucket/my-table/',
    format = 'PARQUET'
);
```

### Schedule an Airflow DAG
1. Place your DAG file in `./airflow/dags/`
2. Wait for Airflow to detect it (may take a few minutes)
3. Enable and trigger it from the Airflow UI

## Troubleshooting

### Common Issues

**Services not starting**
```bash
# Check container logs
docker-compose logs [service-name]

# Restart specific service
docker-compose restart [service-name]
```

**Spark jobs failing**
- Check Spark Master UI for job status
- Verify S3 credentials in Spark configuration
- Ensure JAR files are present in spark/jars

**Trino connection issues**
- Verify Hive Metastore is running
- Check catalog configuration files
- Ensure PostgreSQL is accessible

**Airflow DAGs not appearing**
- Check DAG syntax with `python your_dag.py`
- Verify file is in the dags directory
- Check Airflow logs for import errors

### Performance Tuning

**For better performance:**
- Increase Docker memory allocation to 6-8GB
- Add more Spark workers: `docker-compose up --scale spark-worker=3`
- Tune Spark configurations in `spark-defaults.conf`
- Configure Trino memory settings

## Data Lake Best Practices

### 1. Data Organization
```
bucket/
├── raw/
├── processed/
├── curated/
└── archive/
```

### 2. File Formats
- **Raw data**: CSV, JSON, Avro
- **Processed data**: Parquet, Delta Lake
- **Large datasets**: Partition by date/region

### 3. Security
- Use IAM policies for production
- Encrypt data at rest and in transit
- Implement access controls
- Regular security audits

### 4. Monitoring
- Monitor resource usage
- Set up alerts for job failures
- Track data quality metrics
- Implement data lineage

## Extending the Data Lake

### Adding New Components
To add new services (e.g., Apache Kafka, Apache Hudi):
1. Add service definition to `docker-compose.yml`
2. Create configuration files
3. Update launch script
4. Document in README

### Integration Examples
- **Apache Kafka**: Real-time data streaming
- **Apache Hudi**: Data lakehouse capabilities
- **dbt**: Data transformation workflows
- **Apache Superset**: Business intelligence
- **MLflow**: Machine learning lifecycle management

## Cleanup

```bash
# Stop all services
docker-compose down

# Remove volumes (⚠️ deletes all data)
docker-compose down -v

# Remove images
docker-compose down --rmi all
```

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review container logs
3. Consult component documentation
4. Open an issue in the project repository

## License

This project is licensed under the MIT License - see the LICENSE file for details.

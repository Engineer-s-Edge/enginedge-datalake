# EnginEdge Data Lake

[![CI/CD](https://github.com/Chris-Alexander-Pop/enginedge-datalake/actions/workflows/datalake-ci.yml/badge.svg)](https://github.com/Chris-Alexander-Pop/enginedge-datalake/actions/workflows/datalake-ci.yml)
[![Deploy](https://github.com/Chris-Alexander-Pop/enginedge-datalake/actions/workflows/deploy.yml/badge.svg)](https://github.com/Chris-Alexander-Pop/enginedge-datalake/actions/workflows/deploy.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](docker-compose.yml)

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
                                │                       │
                                ↓                       │
                       ┌─────────────────┐              │
                       │   Metadata      │              │
                       │  (PostgreSQL +  │              │
                       │ Hive Metastore) │              │
                       └─────────────────┘              │
                                                        │
┌───────────────────────────────────────────────────────▼──┐
│              Observability & Governance                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
│  │ Datalake API │   │ Marquez      │   │ Tokern       │  │
│  │ (NestJS)     │   │ (Lineage)    │   │ (Governance) │  │
│  └──────────────┘   └──────────────┘   └──────────────┘  │
└──────────────────────────────────────────────────────────┘
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

### 📊 Data Lineage (Marquez + OpenLineage)

- **Purpose**: Track data flow and transformations
- **Marquez API Port**: 5000, 5001
- **Marquez Web Port**: 3001
- **Use Cases**: Data lineage tracking, impact analysis, compliance
- **Documentation**: See [DATA_LINEAGE.md](DATA_LINEAGE.md)

### 🧐 Data Quality (Great Expectations)

- **Purpose**: Data validation and quality checks
- **Port**: 4000
- **Use Cases**: Data quality reports, data validation pipelines

### 🌐 Data Discovery (Marquez)

- **Purpose**: Data lineage and metadata management
- **Port**: 3001
- **Use Cases**: Data discovery, data lineage, metadata management

### 🏛️ Data Governance (Tokern)

- **Purpose**: Data governance and compliance
- **Port**: 8001
- **Use Cases**: Data catalog, data lineage, access control

### 🔍 Datalake Observability Service

- **Purpose**: Centralized health and metrics API for all datalake components.
- **Port**: 3010
- **Framework**: NestJS
- **Endpoints**:
  - `/api/observability/health`: Status check for all datalake services (MinIO, Trino, Airflow, Spark)
  - `/api/observability/metrics`: Aggregated metrics (active queries, bucket counts)
- **Use Cases**: Monitoring dashboard integration, automated health checks.

## Quick Start

### Prerequisites

- Docker and Docker Compose
- PowerShell (Windows) or Bash (Linux/Mac)
- At least 4GB RAM available for containers

### Launch the Data Lake

1. Create a `.env` file from the `.env.example` file and configure the credentials.
2. Install dependencies for the observability API:

```bash
npm install
```

3. Run the launch script:

```powershell
# Windows PowerShell
.\launch-datalake.ps1
```

```bash
# Linux/Mac
docker-compose up -d
```

### Kubernetes Deployment

Alternatively, you can deploy the data lake to a Kubernetes cluster. For detailed instructions, see the [Kubernetes README](./kubernetes/README.md).

To deploy, run the following command:

```bash
kubectl apply -f kubernetes/
```

### Access the Services

| Service               | URL                   |
| --------------------- | --------------------- |
| MinIO Console         | http://localhost:9001 |
| Spark Master          | http://localhost:8080 |
| Trino                 | http://localhost:8090 |
| Airflow               | http://localhost:8082 |
| Jupyter Lab           | http://localhost:8888 |
| Great Expectations    | http://localhost:4000 |
| Marquez Web (Lineage) | http://localhost:3001 |
| Marquez API           | http://localhost:5000 |
| Tokern (Governance)   | http://localhost:8001 |

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

### 2. Data Quality with Great Expectations

1. Open Jupyter Lab at http://localhost:8888
2. Run the `Data_Quality_with_Great_Expectations.ipynb` notebook to learn how to validate data and generate data quality reports.

### 3. Data Lineage Tutorial

1. Open Jupyter Lab at http://localhost:8888
2. Run the `Data_Lineage_Tutorial.ipynb` notebook to learn how to query and visualize data lineage.
3. Explore example Spark jobs: `spark/apps/lineage_examples/`
4. Review example Airflow DAGs: `airflow/dags/lineage_examples/`
5. See Python SDK examples: `examples/lineage/`
6. Full documentation: [DATA_LINEAGE.md](DATA_LINEAGE.md)

### 4. Upload Sample Data

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

### 4. Monitoring & Logging

- Monitor resource usage
- Set up alerts for job failures
- Track data quality metrics
- Implement data lineage

**Logging Infrastructure**: The datalake includes a comprehensive Winston-based logging solution. See [Logging Documentation](src/infrastructure/logging/README.md) for details.

Key logging features:

- Pretty console output with colors and timestamps
- Automatic file rotation with compression
- Request ID tracking across async operations
- Sensitive data redaction (passwords, tokens, API keys)
- HTTP request/response logging
- Optional Sentry integration for error tracking

Configure logging via environment variables:

```bash
LOG_LEVEL=info          # Log level: error, warn, info, http, verbose, debug
LOG_DIR=logs            # Directory for log files
LOG_ENABLE_CONSOLE=true # Enable console logging
LOG_ENABLE_FILES=true   # Enable file logging
```

Log files are created in the `logs/` directory:

- `enginedge-datalake-YYYY-MM-DD-combined.log` - All logs
- `enginedge-datalake-YYYY-MM-DD-error.log` - Errors only

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

## Observability & Monitoring

### Observability API

The datalake includes an observability API that exposes health and metrics endpoints:

```bash
# Health check
curl http://localhost:3010/api/observability/health

# Metrics
curl http://localhost:3010/api/observability/metrics
```

### Prometheus Integration

ServiceMonitors are configured for all datalake services:

- MinIO cluster metrics (`/minio/v2/metrics/cluster`)
- Trino query metrics (`/v1/metrics`)
- Airflow health (`/health`)
- Spark metrics (`/metrics/json`)

### Grafana Dashboard

A comprehensive dashboard is available showing:

- Service health status
- Storage capacity and usage
- Active queries and jobs
- DAG run statistics

### API Gateway Integration (Admin-Only)

All datalake UIs are accessible through the API Gateway with admin-only access:

```bash
# Login as admin
TOKEN=$(curl -X POST http://api-gateway:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' \
  | jq -r '.accessToken')

# Access MinIO Console (admin only)
curl http://api-gateway:3001/datalake/minio/ \
  -H "Authorization: Bearer $TOKEN"

# Access other datalake UIs
curl http://api-gateway:3001/datalake/trino/ -H "Authorization: Bearer $TOKEN"
curl http://api-gateway:3001/datalake/airflow/ -H "Authorization: Bearer $TOKEN"
curl http://api-gateway:3001/datalake/jupyter/ -H "Authorization: Bearer $TOKEN"
curl http://api-gateway:3001/datalake/spark/ -H "Authorization: Bearer $TOKEN"
curl http://api-gateway:3001/datalake/marquez/ -H "Authorization: Bearer $TOKEN"
```

**Security**: Non-admin users will receive a `403 Forbidden` error when attempting to access datalake UIs.

See [INTEGRATION.md](INTEGRATION.md) for detailed documentation on the API Gateway integration.

## CI/CD Pipeline

This repository includes a comprehensive CI/CD pipeline that automates testing, security scanning, and deployment.

### Features

- ✅ **Automated Testing**: Python tests across multiple versions (3.9, 3.10, 3.11)
- 🔒 **Security Scanning**: Trivy vulnerability scanning for code and Docker images
- 🐳 **Docker Build**: Automated image building and pushing to GitHub Container Registry
- 🚀 **Automated Deployment**: Deploy to Kubernetes or Docker Compose
- 📊 **Code Coverage**: Integrated coverage reporting
- 🔄 **Dependency Updates**: Weekly automated dependency checks

### Workflows

1. **CI Pipeline** (`.github/workflows/datalake-ci.yml`)
   - Runs on every push and pull request
   - Code quality checks, tests, security scans
   - Builds and pushes Docker images

2. **Deployment Pipeline** (`.github/workflows/deploy.yml`)
   - Manual or tag-based deployments
   - Supports multiple environments (dev, staging, production)
   - Includes smoke tests and rollback capability

3. **Dependency Updates** (`.github/workflows/dependency-update.yml`)
   - Weekly automated checks for outdated packages
   - Creates pull requests for updates

4. **Release Management** (`.github/workflows/release.yml`)
   - Automated release notes generation
   - Creates GitHub releases from tags

### Quick Start

```bash
# Push to dev branch triggers CI
git push origin dev

# Create a release
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Manual deployment (requires GitHub CLI)
gh workflow run deploy.yml -f environment=staging -f version=main
```

### Documentation

- 📖 [CI/CD Documentation](docs/CICD.md) - Complete pipeline guide
- 🔐 [Secrets Setup](. github/SECRETS_SETUP.md) - Configure GitHub secrets

## Testing

This project uses `pytest` for testing the data lake components. The tests are located in the `tests/` directory.

### Prerequisites

- The data lake should be running.
- Python 3 and `pip` should be installed.

### Running the Tests

1. Install the test dependencies:

   ```bash
   pip install -r requirements-test.txt
   ```

2. Run the tests using `pytest`:
   ```bash
   pytest tests/
   ```

### Running Tests in CI

Tests are automatically run in the CI pipeline on every push and pull request. You can also run them locally:

```bash
# Run all tests with coverage
pytest tests/ --cov=. --cov-report=term -v

# Run specific test file
pytest tests/test_minio.py -v

# Run integration tests (requires services running)
docker compose up -d minio postgres
pytest tests/test_minio.py tests/test_postgres.py -v
docker compose down -v
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

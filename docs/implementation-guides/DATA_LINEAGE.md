# Data Lineage in EnginEdge Data Lake

## Overview

The EnginEdge Data Lake includes a comprehensive data lineage solution to track the flow of data through your pipelines, transformations, and queries. This enables you to:

- **Understand data origins**: Know where your data comes from
- **Track transformations**: See how data changes as it flows through pipelines
- **Impact analysis**: Understand downstream effects of changes
- **Debug data issues**: Trace problems back to their source
- **Compliance & governance**: Document data provenance for regulatory requirements
- **Data discovery**: Find related datasets and understand relationships

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Data Lineage Stack                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │   Apache    │  │   Apache    │  │   Custom    │       │
│  │   Spark     │  │   Airflow   │  │   Scripts   │       │
│  │             │  │             │  │             │       │
│  │  OpenLineage│  │  OpenLineage│  │  OpenLineage│       │
│  │   Listener  │  │   Provider  │  │   Client    │       │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘       │
│         │                │                │               │
│         └────────────────┼────────────────┘               │
│                          │                                 │
│                    HTTP POST Events                        │
│                          │                                 │
│                 ┌────────▼──────────┐                     │
│                 │   Marquez API     │                     │
│                 │  (Port 5000/5001) │                     │
│                 │                   │                     │
│                 │  - Stores lineage │                     │
│                 │  - OpenLineage    │                     │
│                 │  - REST API       │                     │
│                 └────────┬──────────┘                     │
│                          │                                 │
│                 ┌────────▼──────────┐                     │
│                 │  PostgreSQL DB    │                     │
│                 │   (Port 5433)     │                     │
│                 │                   │                     │
│                 │  - Lineage graph  │                     │
│                 │  - Jobs metadata  │                     │
│                 │  - Run history    │                     │
│                 └───────────────────┘                     │
│                                                            │
├──────────────────────────────────────────────────────────┤
│                    Visualization Layer                     │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  ┌──────────────────┐          ┌──────────────────┐     │
│  │  Marquez Web UI  │          │  Tokern Viz      │     │
│  │  (Port 3001)     │          │  (Port 8001)     │     │
│  │                  │          │                  │     │
│  │  - DAG view      │          │  - Data catalog  │     │
│  │  - Column lineage│          │  - Query lineage │     │
│  │  - Search        │          │  - Governance    │     │
│  └──────────────────┘          └──────────────────┘     │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

## Components

### 1. OpenLineage

[OpenLineage](https://openlineage.io/) is an open standard for collecting lineage metadata from data pipelines.

**Key Features:**
- Vendor-neutral lineage standard
- JSON-based event model
- Support for major data processing frameworks
- Dataset-level and column-level lineage

**Event Types:**
- `START`: Job execution begins
- `RUNNING`: Job is in progress
- `COMPLETE`: Job finished successfully
- `FAIL`: Job failed
- `ABORT`: Job was cancelled

### 2. Marquez

[Marquez](https://marquezproject.ai/) is the reference implementation of the OpenLineage API.

**Components:**
- **Marquez API** (Port 5000, 5001): Receives lineage events, stores metadata
- **Marquez Web** (Port 3001): Web UI for visualizing lineage
- **PostgreSQL**: Backend database for lineage storage

**Access:**
```bash
# Web UI
http://localhost:3001

# API
http://localhost:5000/api/v1

# Admin API
http://localhost:5001/api/v1/admin
```

**Key Concepts:**
- **Namespace**: Logical grouping (e.g., `datalake`)
- **Job**: A data processing task
- **Dataset**: Input or output data
- **Run**: Single execution of a job

### 3. Tokern Data Lineage

[Tokern](https://tokern.io/) provides additional data governance and lineage visualization capabilities.

**Components:**
- **Tokern API** (Port 4142): Data catalog and lineage API
- **Tokern Viz** (Port 8001): Web UI for data discovery and governance

**Access:**
```bash
# Web UI
http://localhost:8001

# API
http://tokern-api:4142
```

**Features:**
- Query-level lineage tracking
- Data catalog with search
- Access control policies
- PII detection
- Compliance reporting

## Integration

### Spark Integration

The data lake automatically configures Spark to send lineage events to Marquez.

**Configuration (already set up):**
```properties
# In spark-defaults.conf
spark.extraListeners=io.openlineage.spark.agent.OpenLineageSparkListener
spark.openlineage.transport.type=http
spark.openlineage.transport.url=http://marquez-api:5000
spark.openlineage.namespace=datalake
```

**What Gets Tracked:**
- Input datasets (Parquet, JSON, CSV, Hive tables, etc.)
- Output datasets
- Transformations (filter, map, join, etc.)
- Job execution metrics
- Column-level lineage for DataFrame operations

### Airflow Integration

Airflow automatically sends lineage events through the OpenLineage provider.

**Configuration (already set up):**
```python
# In docker-compose.yml
AIRFLOW__OPENLINEAGE__TRANSPORT: '{"type": "http", "url": "http://marquez-api:5000"}'
```

**What Gets Tracked:**
- DAG structure and dependencies
- Task executions
- Input/output datasets
- Task duration and status
- Error messages on failure

### Custom Python Integration

You can manually track lineage for custom Python scripts using the OpenLineage Python client.

**Installation:**
```bash
pip install openlineage-python
```

**Example Usage:**
```python
from openlineage.client import OpenLineageClient
from openlineage.client.run import RunEvent, RunState, Run, Job
from openlineage.client.facet import ParentRunFacet
from datetime import datetime

# Initialize client
client = OpenLineageClient(url="http://localhost:5000")

# Create job
job = Job(namespace="datalake", name="my-custom-job")

# Create run
run = Run(runId=str(uuid.uuid4()))

# Send START event
client.emit(RunEvent(
    eventType=RunState.START,
    eventTime=datetime.now().isoformat(),
    run=run,
    job=job,
    producer="my-script/1.0",
    inputs=[],
    outputs=[]
))

# ... do your work ...

# Send COMPLETE event
client.emit(RunEvent(
    eventType=RunState.COMPLETE,
    eventTime=datetime.now().isoformat(),
    run=run,
    job=job,
    producer="my-script/1.0",
    inputs=[
        {
            "namespace": "datalake",
            "name": "s3://my-bucket/input.parquet"
        }
    ],
    outputs=[
        {
            "namespace": "datalake",
            "name": "s3://my-bucket/output.parquet"
        }
    ]
))
```

## Usage Examples

### Example 1: Viewing Lineage in Marquez Web UI

1. Open http://localhost:3001
2. You'll see a list of namespaces (should include "datalake")
3. Click on a namespace to see jobs
4. Click on a job to see:
   - Job definition and source code
   - Run history
   - Input and output datasets
   - Lineage graph

### Example 2: Querying Lineage via API

```bash
# Get all namespaces
curl http://localhost:5000/api/v1/namespaces

# Get jobs in a namespace
curl http://localhost:5000/api/v1/namespaces/datalake/jobs

# Get job details
curl http://localhost:5000/api/v1/namespaces/datalake/jobs/my-spark-job

# Get dataset details
curl http://localhost:5000/api/v1/namespaces/datalake/datasets/s3%3A%2F%2Fmy-bucket%2Fdata.parquet

# Get lineage graph
curl http://localhost:5000/api/v1/lineage?nodeId=dataset:datalake:s3://my-bucket/data.parquet
```

### Example 3: Finding Data Dependencies

```python
import requests

def get_downstream_datasets(namespace, dataset_name):
    """Find all datasets that depend on this dataset"""
    url = f"http://localhost:5000/api/v1/lineage"
    params = {
        "nodeId": f"dataset:{namespace}:{dataset_name}",
        "depth": 10
    }
    response = requests.get(url, params=params)
    lineage = response.json()
    
    # Extract downstream datasets
    downstream = []
    for node in lineage.get("graph", []):
        if node.get("type") == "DATASET" and node.get("data", {}).get("name") != dataset_name:
            downstream.append(node["data"]["name"])
    
    return downstream

# Usage
deps = get_downstream_datasets("datalake", "s3://my-bucket/raw-data.parquet")
print(f"Datasets that depend on this data: {deps}")
```

### Example 4: Impact Analysis

When you need to change a dataset, check what will be affected:

```python
def impact_analysis(namespace, dataset_name):
    """Analyze the impact of changing a dataset"""
    lineage_url = f"http://localhost:5000/api/v1/lineage"
    params = {
        "nodeId": f"dataset:{namespace}:{dataset_name}",
        "depth": 20
    }
    
    response = requests.get(lineage_url, params=params)
    lineage = response.json()
    
    affected_jobs = set()
    affected_datasets = set()
    
    for node in lineage.get("graph", []):
        if node.get("type") == "JOB":
            affected_jobs.add(node["data"]["name"])
        elif node.get("type") == "DATASET":
            affected_datasets.add(node["data"]["name"])
    
    print(f"Impact Analysis for {dataset_name}:")
    print(f"  - {len(affected_jobs)} jobs will be affected")
    print(f"  - {len(affected_datasets)} datasets will be impacted")
    print(f"\nAffected Jobs:")
    for job in sorted(affected_jobs):
        print(f"  - {job}")
    
    return {
        "jobs": list(affected_jobs),
        "datasets": list(affected_datasets)
    }
```

## Best Practices

### 1. Namespace Organization

Use meaningful namespaces to organize your lineage:

```
datalake          # Main production namespace
datalake-dev      # Development environment
datalake-staging  # Staging environment
```

### 2. Job Naming

Use descriptive, hierarchical job names:

```
good: etl/customer-data/daily-aggregation
bad:  job123
```

### 3. Dataset Naming

Use fully qualified paths for datasets:

```
s3://bucket-name/path/to/data.parquet
postgres://localhost:5432/database/schema/table
file:///path/to/local/file.csv
```

### 4. Add Metadata

Include rich metadata in your lineage events:

```python
from openlineage.client.facet import DocumentationJobFacet

facets = {
    "documentation": DocumentationJobFacet(
        description="Daily customer aggregation pipeline"
    )
}
```

### 5. Column-Level Lineage

For critical transformations, track column-level lineage:

```python
from openlineage.client.facet import ColumnLineageDatasetFacet

facets = {
    "columnLineage": ColumnLineageDatasetFacet(
        fields={
            "total_revenue": {
                "inputFields": [
                    {"namespace": "datalake", "name": "orders", "field": "amount"},
                    {"namespace": "datalake", "name": "discounts", "field": "discount_amount"}
                ],
                "transformationType": "AGGREGATION",
                "transformationDescription": "SUM(amount - discount_amount)"
            }
        }
    )
}
```

### 6. Error Tracking

Always send FAIL events when jobs fail:

```python
try:
    # Your job logic
    pass
except Exception as e:
    client.emit(RunEvent(
        eventType=RunState.FAIL,
        eventTime=datetime.now().isoformat(),
        run=run,
        job=job,
        producer="my-job/1.0",
        inputs=[],
        outputs=[]
    ))
    raise
```

## Monitoring & Troubleshooting

### Check Marquez API Health

```bash
curl http://localhost:5000/api/v1/health
```

### View Recent Events

```bash
# Get recent job runs
curl http://localhost:5000/api/v1/namespaces/datalake/jobs/my-job/runs

# Get latest run
curl http://localhost:5000/api/v1/namespaces/datalake/jobs/my-job/runs/latest
```

### Debug Lineage Issues

1. **Events not appearing:**
   - Check that Marquez API is running: `docker ps | grep marquez`
   - Verify network connectivity: `docker exec spark-master curl http://marquez-api:5000/api/v1/health`
   - Check OpenLineage configuration in Spark/Airflow

2. **Incomplete lineage:**
   - Ensure all transformations are using supported operations
   - Check Spark/Airflow logs for OpenLineage errors
   - Verify dataset URIs are correctly formatted

3. **Performance issues:**
   - Consider batching lineage events
   - Use asynchronous emission
   - Monitor Marquez database size

### Logs

```bash
# Marquez API logs
docker logs marquez-api

# Marquez DB logs
docker logs marquez-db

# Tokern logs
docker logs tokern-data-lineage
```

## Advanced Topics

### Custom Lineage Extractors

Create custom extractors for proprietary data sources:

```python
from openlineage.client.serde import Serde

class CustomExtractor:
    def extract_lineage(self, context):
        return {
            "inputs": self._extract_inputs(context),
            "outputs": self._extract_outputs(context),
            "job": self._extract_job_info(context)
        }
```

### Lineage for ML Pipelines

Track machine learning model lineage:

```python
# Track training data
inputs = [
    Dataset(namespace="datalake", name="s3://bucket/train-data.parquet"),
    Dataset(namespace="datalake", name="s3://bucket/features.csv")
]

# Track model artifacts
outputs = [
    Dataset(namespace="datalake", name="s3://bucket/models/model-v1.pkl"),
    Dataset(namespace="datalake", name="s3://bucket/metrics/metrics.json")
]
```

### Cross-System Lineage

Track lineage across different systems:

```python
# Data flows from external source -> S3 -> Spark -> Database
inputs = [
    Dataset(namespace="external-api", name="https://api.example.com/data"),
]

outputs = [
    Dataset(namespace="datalake", name="s3://bucket/processed.parquet"),
    Dataset(namespace="database", name="postgres://localhost/mydb/results")
]
```

## API Reference

### Marquez API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/namespaces` | GET | List all namespaces |
| `/api/v1/namespaces/{namespace}/jobs` | GET | List jobs in namespace |
| `/api/v1/namespaces/{namespace}/jobs/{job}` | GET | Get job details |
| `/api/v1/namespaces/{namespace}/datasets` | GET | List datasets |
| `/api/v1/namespaces/{namespace}/datasets/{dataset}` | GET | Get dataset details |
| `/api/v1/lineage` | GET | Get lineage graph |
| `/api/v1/events/lineage` | POST | Submit lineage event |

### OpenLineage Event Schema

```json
{
  "eventType": "COMPLETE",
  "eventTime": "2025-11-07T10:00:00.000Z",
  "run": {
    "runId": "uuid"
  },
  "job": {
    "namespace": "datalake",
    "name": "my-job"
  },
  "inputs": [],
  "outputs": [],
  "producer": "spark/3.3.0"
}
```

## Resources

- **OpenLineage Documentation**: https://openlineage.io/docs/
- **Marquez Documentation**: https://marquezproject.github.io/marquez/
- **Tokern Documentation**: https://tokern.io/docs/
- **OpenLineage Spec**: https://github.com/OpenLineage/OpenLineage/blob/main/spec/OpenLineage.md

## Support

For issues with data lineage:

1. Check service logs: `docker logs marquez-api`
2. Verify connectivity: `curl http://localhost:5000/api/v1/health`
3. Review example notebooks in `notebooks/`
4. Check Spark/Airflow logs for OpenLineage errors
5. Consult the troubleshooting section above

## Next Steps

1. Run the example Spark jobs in `spark/apps/lineage_examples/`
2. Review the example Airflow DAGs in `airflow/dags/lineage_examples/`
3. Explore the lineage notebook: `notebooks/Data_Lineage_Tutorial.ipynb`
4. Try the Python SDK examples in `examples/lineage/`
5. Set up lineage tracking for your own pipelines

## Compliance & Governance

### GDPR / CCPA

Data lineage helps with compliance:

- **Data Provenance**: Track where personal data originates
- **Right to Erasure**: Identify all systems containing user data
- **Data Mapping**: Document data flows for privacy impact assessments

### SOX / Financial Regulations

- **Audit Trail**: Complete history of data transformations
- **Data Integrity**: Verify data hasn't been tampered with
- **Change Control**: Track who modified data pipelines and when

### Data Quality

- **Root Cause Analysis**: Trace data quality issues to their source
- **Validation**: Ensure data transformations are correct
- **Monitoring**: Alert on unexpected lineage changes

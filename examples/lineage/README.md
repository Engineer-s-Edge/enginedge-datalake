# OpenLineage Python SDK Examples

This directory contains practical examples of using the OpenLineage Python client to track data lineage programmatically.

## Setup

Install the OpenLineage Python client:

```bash
pip install openlineage-python
```

## Examples

### 1. Basic Lineage (`01_basic_lineage.py`)

The fundamentals of lineage tracking:
- Creating jobs and runs
- Defining input and output datasets
- Sending START and COMPLETE events

**Run:**
```bash
python 01_basic_lineage.py
```

### 2. Schema Tracking (`02_schema_tracking.py`)

Track dataset schemas:
- Define column names and types
- Add column descriptions
- Track schema evolution

**Run:**
```bash
python 02_schema_tracking.py
```

### 3. Column Lineage (`03_column_lineage.py`)

Track column-level lineage:
- Map output columns to input columns
- Specify transformation types (IDENTITY, AGGREGATION, etc.)
- Document transformation logic

**Run:**
```bash
python 03_column_lineage.py
```

### 4. Error Handling (`04_error_handling.py`)

Handle job failures:
- Send FAIL events
- Include error messages
- Track stack traces

**Run:**
```bash
python 04_error_handling.py
```

### 5. Job Metadata (`05_job_metadata.py`)

Add rich metadata to jobs:
- SQL queries
- Source code location
- Documentation
- Custom properties

**Run:**
```bash
python 05_job_metadata.py
```

## Key Concepts

### Event Lifecycle

Every job run goes through these states:

```
START → RUNNING → COMPLETE
              ↓
             FAIL
```

### Event Types

- **START**: Job begins execution
- **RUNNING**: Job is in progress (optional)
- **COMPLETE**: Job finished successfully
- **FAIL**: Job failed with error
- **ABORT**: Job was cancelled

### Core Components

#### Job
```python
Job(
    namespace="datalake",      # Logical grouping
    name="my_etl_job"         # Job name
)
```

#### Run
```python
Run(
    runId=str(uuid.uuid4())    # Unique run ID
)
```

#### Dataset
```python
Dataset(
    namespace="datalake",
    name="s3://bucket/path/data.parquet"
)
```

## Facets

Facets add metadata to jobs, runs, and datasets:

### Job Facets

- **SqlJobFacet**: SQL query text
- **SourceCodeLocationJobFacet**: Git repo and commit
- **DocumentationJobFacet**: Job documentation

### Dataset Facets

- **SchemaDatasetFacet**: Column schema
- **DataSourceDatasetFacet**: Database connection info
- **ColumnLineageDatasetFacet**: Column-level lineage
- **DataQualityMetricsInputDatasetFacet**: Data quality scores

### Run Facets

- **NominalTimeRunFacet**: Scheduled run time
- **ParentRunFacet**: Parent job relationship
- **ErrorMessageRunFacet**: Error details

## Best Practices

### 1. Use Meaningful Namespaces

```python
# Good
Job(namespace="production-datalake", name="customer_etl")

# Bad
Job(namespace="test", name="job1")
```

### 2. Fully Qualified Dataset Names

```python
# Good
Dataset(namespace="datalake", name="s3://bucket/path/file.parquet")

# Bad
Dataset(namespace="datalake", name="file.parquet")
```

### 3. Always Send START Events

```python
# Send START before work begins
client.emit(start_event)

try:
    # Do work
    process_data()
    
    # Send COMPLETE on success
    client.emit(complete_event)
except Exception as e:
    # Send FAIL on error
    client.emit(fail_event)
    raise
```

### 4. Include Schema Information

```python
schema = SchemaDatasetFacet(
    fields=[
        SchemaField(
            name="customer_id",
            type="INTEGER",
            description="Unique customer identifier"
        )
    ]
)

dataset = Dataset(
    namespace="datalake",
    name="s3://bucket/customers.parquet",
    facets={"schema": schema}
)
```

### 5. Track Column Lineage

```python
column_lineage = ColumnLineageDatasetFacet(
    fields={
        "total_revenue": ColumnLineageDatasetFacetFieldsAdditional(
            inputFields=[
                ColumnLineageDatasetFacetFieldsAdditionalInputFields(
                    namespace="datalake",
                    name="s3://bucket/sales.csv",
                    field="amount"
                )
            ],
            transformationType="AGGREGATION",
            transformationDescription="SUM(amount) grouped by customer"
        )
    }
)
```

## Common Patterns

### Pattern 1: Simple ETL

```python
from openlineage.client import OpenLineageClient
from openlineage.client.run import RunEvent, RunState, Run, Job, Dataset
from datetime import datetime
import uuid

client = OpenLineageClient(url="http://localhost:5000")

def my_etl():
    job = Job(namespace="datalake", name="my_etl")
    run = Run(runId=str(uuid.uuid4()))
    
    # START
    client.emit(RunEvent(
        eventType=RunState.START,
        eventTime=datetime.now().isoformat(),
        run=run,
        job=job,
        producer="my-script/1.0",
        inputs=[Dataset(namespace="datalake", name="input.csv")],
        outputs=[]
    ))
    
    # Do work
    result = process_data()
    
    # COMPLETE
    client.emit(RunEvent(
        eventType=RunState.COMPLETE,
        eventTime=datetime.now().isoformat(),
        run=run,
        job=job,
        producer="my-script/1.0",
        inputs=[Dataset(namespace="datalake", name="input.csv")],
        outputs=[Dataset(namespace="datalake", name="output.parquet")]
    ))
```

### Pattern 2: Multi-Step Pipeline

```python
def multi_step_pipeline():
    # Step 1: Extract
    run_step("extract", inputs=["source.csv"], outputs=["bronze/data.parquet"])
    
    # Step 2: Transform
    run_step("transform", inputs=["bronze/data.parquet"], outputs=["silver/data.parquet"])
    
    # Step 3: Load
    run_step("load", inputs=["silver/data.parquet"], outputs=["gold/analytics.parquet"])

def run_step(step_name, inputs, outputs):
    job = Job(namespace="datalake", name=f"pipeline_{step_name}")
    run = Run(runId=str(uuid.uuid4()))
    
    # Send events...
```

### Pattern 3: Error Handling

```python
def job_with_error_handling():
    job = Job(namespace="datalake", name="my_job")
    run = Run(runId=str(uuid.uuid4()))
    
    # START
    client.emit(start_event)
    
    try:
        # Work
        result = risky_operation()
        
        # COMPLETE
        client.emit(complete_event)
        
    except Exception as e:
        # FAIL
        fail_event = RunEvent(
            eventType=RunState.FAIL,
            eventTime=datetime.now().isoformat(),
            run=run,
            job=job,
            producer="my-script/1.0",
            inputs=[...],
            outputs=[]
        )
        client.emit(fail_event)
        raise
```

## Testing

Test your lineage tracking:

```python
import requests

def verify_lineage(namespace, job_name):
    """Verify lineage was tracked correctly"""
    url = f"http://localhost:5000/api/v1/namespaces/{namespace}/jobs/{job_name}"
    response = requests.get(url)
    
    assert response.status_code == 200
    job_data = response.json()
    
    assert job_data['name'] == job_name
    assert 'latestRun' in job_data
    
    print(f"✓ Lineage verified for {namespace}/{job_name}")
```

## Troubleshooting

### Events Not Appearing

1. **Check Marquez is running:**
   ```bash
   curl http://localhost:5000/api/v1/health
   ```

2. **Verify client configuration:**
   ```python
   client = OpenLineageClient(url="http://localhost:5000")
   print(f"Client URL: {client._transport._session.base_url}")
   ```

3. **Check for exceptions:**
   ```python
   try:
       client.emit(event)
   except Exception as e:
       print(f"Error emitting event: {str(e)}")
   ```

### Schema Not Showing

Ensure you're using `SchemaDatasetFacet`:
```python
from openlineage.client.facet import SchemaDatasetFacet, SchemaField

schema = SchemaDatasetFacet(
    fields=[
        SchemaField(name="id", type="INTEGER"),
        SchemaField(name="name", type="STRING")
    ]
)
```

### Column Lineage Missing

Use `ColumnLineageDatasetFacet` with proper structure:
```python
from openlineage.client.facet import (
    ColumnLineageDatasetFacet,
    ColumnLineageDatasetFacetFieldsAdditional,
    ColumnLineageDatasetFacetFieldsAdditionalInputFields
)
```

## Resources

- [OpenLineage Python Client Docs](https://openlineage.io/docs/client/python)
- [OpenLineage Spec](https://github.com/OpenLineage/OpenLineage/blob/main/spec/OpenLineage.md)
- [Marquez API Reference](https://marquezproject.github.io/marquez/openapi.html)
- [Main Lineage Documentation](../../DATA_LINEAGE.md)

## Next Steps

1. Run all examples to understand the basics
2. Modify examples for your use cases
3. Integrate into your existing scripts
4. View lineage in Marquez Web UI
5. Query lineage via API
6. Set up CI/CD integration

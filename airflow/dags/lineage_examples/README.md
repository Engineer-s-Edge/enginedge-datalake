# Airflow Lineage Examples

This directory contains example Airflow DAGs that demonstrate automatic data lineage tracking with OpenLineage and Marquez.

## Configuration

The Airflow instance is already configured to send lineage events to Marquez via the OpenLineage provider:

```python
# In docker-compose.yml
AIRFLOW__OPENLINEAGE__TRANSPORT: '{"type": "http", "url": "http://marquez-api:5000"}'
```

No additional configuration is needed in your DAGs - lineage is automatically tracked!

## Examples

### 1. Data Quality Pipeline (`data_quality_with_lineage.py`)

A complete ETL pipeline demonstrating:
- **Extract**: Read data from MinIO
- **Validate**: Perform data quality checks
- **Transform**: Apply business logic
- **Load**: Write to analytics layer
- **Report**: Generate quality report

**Features:**
- Multi-step pipeline with dependencies
- Data quality validation
- XCom usage (tracked in lineage)
- Error handling
- Complete lineage graph

**Schedule:** Daily

**Run manually:**
```bash
# Trigger DAG
docker exec airflow airflow dags trigger data_quality_with_lineage

# Check status
docker exec airflow airflow dags list-runs -d data_quality_with_lineage

# View logs
docker exec airflow airflow tasks logs data_quality_with_lineage extract_data <run_date>
```

## How It Works

### Automatic Lineage Capture

The OpenLineage Airflow provider automatically tracks:

1. **DAG Structure**
   - Task dependencies
   - Task types
   - Schedule information

2. **Task Execution**
   - Start time
   - End time
   - Duration
   - Status (success/failure)
   - Retry information

3. **Data Operations**
   - Input datasets (files, tables, APIs)
   - Output datasets
   - XCom transfers between tasks
   - Schema information

4. **Context**
   - Airflow version
   - Task operator type
   - Execution date
   - DAG run ID

### What Gets Tracked

#### For Each Task:
```json
{
  "job": {
    "namespace": "default",
    "name": "data_quality_with_lineage.extract_data"
  },
  "run": {
    "runId": "uuid",
    "facets": {
      "airflow_runArgs": {...},
      "airflow_version": "2.x.x"
    }
  },
  "inputs": [
    {
      "namespace": "s3",
      "name": "data-lake/raw/transactions/"
    }
  ],
  "outputs": [
    {
      "namespace": "xcom",
      "name": "extracted_data"
    }
  ]
}
```

## Viewing Lineage

### Marquez Web UI

1. **Access UI:** http://localhost:3001

2. **Navigate to DAG:**
   - Select namespace (usually "default")
   - Find DAG: `data_quality_with_lineage`
   - Click to view details

3. **View Lineage Graph:**
   - See all tasks and dependencies
   - View input/output datasets
   - Track data flow through pipeline
   - See task execution history

4. **Inspect Datasets:**
   - Click on any dataset node
   - View schema
   - See all jobs that read/write this dataset
   - Check data quality metrics

### Marquez API

Query lineage programmatically:

```bash
# Get DAG information
curl http://localhost:5000/api/v1/namespaces/default/jobs/data_quality_with_lineage

# Get specific task
curl http://localhost:5000/api/v1/namespaces/default/jobs/data_quality_with_lineage.extract_data

# Get lineage graph
curl http://localhost:5000/api/v1/lineage?nodeId=job:default:data_quality_with_lineage.extract_data

# Get dataset information
curl http://localhost:5000/api/v1/namespaces/s3/datasets/data-lake%2Fraw%2Ftransactions
```

## Creating Your Own Lineage-Tracked DAGs

### Basic Template

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'data-team',
    'start_date': datetime(2025, 1, 1),
    'retries': 2,
}

dag = DAG(
    'my_pipeline',
    default_args=default_args,
    schedule_interval=timedelta(days=1),
    tags=['lineage']
)

def process_data(**context):
    """
    Your data processing logic.
    OpenLineage automatically tracks:
    - File reads/writes
    - Database queries
    - API calls
    - XCom operations
    """
    # Your code here
    pass

task = PythonOperator(
    task_id='process_data',
    python_callable=process_data,
    dag=dag
)
```

### Adding Dataset Information

Help OpenLineage understand your datasets:

```python
from airflow.lineage import Dataset

def my_task(**context):
    # Define input dataset
    input_dataset = Dataset(
        namespace="s3",
        name="my-bucket/input.csv",
        facets={
            "schema": {
                "fields": [
                    {"name": "id", "type": "integer"},
                    {"name": "value", "type": "string"}
                ]
            }
        }
    )
    
    # Process data
    result = process_data()
    
    # Define output dataset
    output_dataset = Dataset(
        namespace="s3",
        name="my-bucket/output.parquet",
        facets={
            "schema": {
                "fields": [
                    {"name": "id", "type": "integer"},
                    {"name": "processed_value", "type": "string"},
                    {"name": "timestamp", "type": "timestamp"}
                ]
            }
        }
    )
    
    return result
```

### Tracking Custom Operations

For operations not automatically tracked:

```python
from openlineage.airflow import OpenLineageAdapter

def custom_operation(**context):
    adapter = OpenLineageAdapter()
    
    # Manually emit lineage event
    adapter.build_dag_run_id(
        dag_id=context['dag'].dag_id,
        execution_date=context['execution_date']
    )
    
    # Your custom logic
    result = my_custom_process()
    
    return result
```

## Best Practices

### 1. Use Descriptive Task IDs

```python
# Good
extract_customer_data = PythonOperator(
    task_id='extract_customer_data',
    ...
)

# Bad
task1 = PythonOperator(
    task_id='task1',
    ...
)
```

### 2. Tag Your DAGs

```python
dag = DAG(
    'customer_pipeline',
    tags=['production', 'customer', 'daily', 'lineage']
)
```

### 3. Use Fully Qualified Paths

```python
# Good
input_path = "s3://data-lake/raw/customers/data.csv"

# Bad
input_path = "../data.csv"
```

### 4. Add Documentation

```python
dag = DAG(
    'customer_pipeline',
    description='Daily customer data aggregation pipeline',
    doc_md="""
    ## Customer Pipeline
    
    This pipeline:
    1. Extracts customer data from S3
    2. Validates data quality
    3. Transforms and enriches data
    4. Loads to analytics layer
    
    **Upstream:** Raw customer data from CRM
    **Downstream:** Customer analytics dashboard
    """
)
```

### 5. Handle Failures Properly

```python
def task_with_error_handling(**context):
    try:
        # Your logic
        process_data()
    except Exception as e:
        # Log error (will be captured in lineage)
        logging.error(f"Task failed: {str(e)}")
        # OpenLineage will mark this run as FAILED
        raise
```

### 6. Use Sensors for Dependencies

```python
from airflow.sensors.filesystem import FileSensor

# Wait for file before processing
wait_for_file = FileSensor(
    task_id='wait_for_input',
    filepath='/path/to/file.csv',
    dag=dag
)

wait_for_file >> process_data
```

## Troubleshooting

### Lineage Not Appearing

1. **Check Airflow configuration:**
   ```bash
   docker exec airflow airflow config get-value openlineage transport
   ```

2. **Check Marquez connectivity:**
   ```bash
   docker exec airflow curl http://marquez-api:5000/api/v1/health
   ```

3. **View Airflow logs:**
   ```bash
   docker logs airflow | grep -i openlineage
   ```

4. **Check task logs:**
   ```bash
   docker exec airflow airflow tasks logs <dag_id> <task_id> <run_date>
   ```

### Incomplete Lineage

- Ensure all file operations use absolute paths
- Verify dataset namespace is correct
- Check that data sources are supported
- Confirm OpenLineage provider version compatibility

### Performance Issues

If OpenLineage impacts DAG performance:
- Use async mode (default)
- Reduce metadata detail level
- Batch lineage events
- Monitor Marquez API response times

## Testing Lineage

### Local Testing

Before deploying to production:

1. **Test DAG syntax:**
   ```bash
   docker exec airflow airflow dags test <dag_id> <execution_date>
   ```

2. **Run single task:**
   ```bash
   docker exec airflow airflow tasks test <dag_id> <task_id> <execution_date>
   ```

3. **Check lineage in Marquez:**
   - View web UI
   - Verify datasets appear
   - Confirm graph is correct

### Integration Testing

```python
def test_lineage():
    """Test that lineage is correctly captured"""
    import requests
    
    # Trigger DAG
    trigger_dag('my_pipeline')
    
    # Wait for completion
    wait_for_dag_completion('my_pipeline')
    
    # Check lineage
    response = requests.get(
        'http://localhost:5000/api/v1/namespaces/default/jobs/my_pipeline'
    )
    
    assert response.status_code == 200
    assert 'inputs' in response.json()
    assert 'outputs' in response.json()
```

## Advanced Topics

### Parent-Child Job Relationships

Track jobs triggered by other jobs:

```python
from airflow.operators.trigger_dagrun import TriggerDagRunOperator

trigger_child = TriggerDagRunOperator(
    task_id='trigger_child_pipeline',
    trigger_dag_id='child_pipeline',
    dag=dag
)
```

The lineage will show: `parent_pipeline -> trigger -> child_pipeline`

### External System Integration

Track data coming from external systems:

```python
def extract_from_api(**context):
    """
    Extract data from external API.
    Lineage shows: API -> Airflow -> S3
    """
    import requests
    
    # This operation creates lineage edge
    data = requests.get('https://api.example.com/data').json()
    
    # Save to S3 (also tracked)
    save_to_s3(data)
```

### Cross-Namespace Lineage

Track data flowing across namespaces:

```python
# Data flows from external namespace to datalake
input_dataset = Dataset(
    namespace="external-api",
    name="customers"
)

output_dataset = Dataset(
    namespace="datalake",
    name="s3://bucket/customers.parquet"
)
```

## Resources

- [OpenLineage Airflow Integration](https://openlineage.io/docs/integrations/airflow/)
- [Airflow Documentation](https://airflow.apache.org/docs/)
- [Marquez Documentation](https://marquezproject.github.io/marquez/)
- [Main Lineage Documentation](../../../DATA_LINEAGE.md)

## Next Steps

1. Run the example DAG
2. View lineage in Marquez
3. Create your own lineage-tracked DAGs
4. Explore column-level lineage
5. Set up monitoring and alerts
6. Integrate with your existing pipelines

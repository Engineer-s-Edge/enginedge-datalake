"""
Data Quality Pipeline with Lineage

This Airflow DAG demonstrates automatic lineage tracking through
a data quality pipeline using OpenLineage.

The pipeline:
1. Extracts data from MinIO
2. Validates data quality
3. Transforms valid data
4. Loads to analytics layer
5. Generates quality report

All steps are automatically tracked by the OpenLineage Airflow provider,
creating a complete lineage graph in Marquez.
"""

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta
import pandas as pd
import json
import logging
from io import StringIO, BytesIO

# Default DAG arguments
default_args = {
    'owner': 'datalake-team',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

# Initialize DAG
dag = DAG(
    'data_quality_with_lineage',
    default_args=default_args,
    description='Data quality pipeline with automatic lineage tracking',
    schedule_interval=timedelta(days=1),
    catchup=False,
    tags=['lineage', 'data-quality', 'example']
)

def extract_data(**context):
    """
    Extract data from MinIO.
    
    Lineage tracked:
    - Input: s3://data-lake/raw/transactions/
    - Operation: READ
    - Schema: transaction_id, customer_id, amount, timestamp
    """
    from minio import Minio
    import os
    
    logging.info("Extracting data from MinIO...")
    
    # Initialize MinIO client
    client = Minio(
        "minio:9000",
        access_key=os.getenv("MINIO_ACCESS_KEY", "minioadmin"),
        secret_key=os.getenv("MINIO_SECRET_KEY", "minioadmin123"),
        secure=False
    )
    
    # This operation is automatically tracked by OpenLineage
    bucket_name = "data-lake"
    object_name = "raw/transactions/transactions.csv"
    
    try:
        # Get object
        response = client.get_object(bucket_name, object_name)
        data = response.read().decode('utf-8')
        response.close()
        response.release_conn()
        
        # Parse CSV
        df = pd.read_csv(StringIO(data))
        
        logging.info(f"Extracted {len(df)} records")
        
        # Store in XCom for next task
        context['task_instance'].xcom_push(
            key='extracted_data',
            value=df.to_json(orient='records')
        )
        
        return len(df)
        
    except Exception as e:
        logging.error(f"Extraction failed: {str(e)}")
        raise

def validate_data(**context):
    """
    Validate data quality.
    
    Lineage tracked:
    - Input: Previous task output (extracted_data)
    - Output: Validation results
    - Data quality checks performed
    """
    logging.info("Validating data quality...")
    
    # Get data from previous task
    data_json = context['task_instance'].xcom_pull(
        key='extracted_data',
        task_ids='extract_data'
    )
    df = pd.read_json(StringIO(data_json))
    
    # Perform data quality checks
    checks = {
        'total_records': len(df),
        'null_transaction_ids': df['transaction_id'].isna().sum(),
        'null_customer_ids': df['customer_id'].isna().sum(),
        'null_amounts': df['amount'].isna().sum(),
        'negative_amounts': (df['amount'] < 0).sum(),
        'duplicate_transactions': df.duplicated(subset=['transaction_id']).sum(),
        'avg_amount': df['amount'].mean(),
        'min_amount': df['amount'].min(),
        'max_amount': df['amount'].max()
    }
    
    # Determine if data passes quality checks
    validation_passed = (
        checks['null_transaction_ids'] == 0 and
        checks['null_customer_ids'] == 0 and
        checks['negative_amounts'] == 0
    )
    
    logging.info(f"Validation checks: {json.dumps(checks, indent=2)}")
    logging.info(f"Validation passed: {validation_passed}")
    
    # Store results
    context['task_instance'].xcom_push(key='validation_checks', value=checks)
    context['task_instance'].xcom_push(key='validation_passed', value=validation_passed)
    
    # Store valid data
    valid_df = df[
        (df['transaction_id'].notna()) &
        (df['customer_id'].notna()) &
        (df['amount'] >= 0)
    ].drop_duplicates(subset=['transaction_id'])
    
    context['task_instance'].xcom_push(
        key='valid_data',
        value=valid_df.to_json(orient='records')
    )
    
    return validation_passed

def transform_data(**context):
    """
    Transform validated data.
    
    Lineage tracked:
    - Input: Validated data
    - Transformations: Aggregations, enrichment
    - Output: Transformed data
    """
    logging.info("Transforming data...")
    
    # Check if validation passed
    validation_passed = context['task_instance'].xcom_pull(
        key='validation_passed',
        task_ids='validate_data'
    )
    
    if not validation_passed:
        logging.warning("Validation did not pass completely, but proceeding with valid records")
    
    # Get valid data
    data_json = context['task_instance'].xcom_pull(
        key='valid_data',
        task_ids='validate_data'
    )
    df = pd.read_json(StringIO(data_json))
    
    # Perform transformations
    # 1. Add derived columns
    df['transaction_date'] = pd.to_datetime(df['timestamp']).dt.date
    df['transaction_hour'] = pd.to_datetime(df['timestamp']).dt.hour
    df['amount_category'] = pd.cut(
        df['amount'],
        bins=[0, 50, 200, 1000, float('inf')],
        labels=['small', 'medium', 'large', 'xlarge']
    )
    
    # 2. Create aggregations
    customer_summary = df.groupby('customer_id').agg({
        'transaction_id': 'count',
        'amount': ['sum', 'mean', 'min', 'max']
    }).reset_index()
    
    customer_summary.columns = [
        'customer_id',
        'transaction_count',
        'total_amount',
        'avg_amount',
        'min_amount',
        'max_amount'
    ]
    
    logging.info(f"Transformed {len(df)} transactions into {len(customer_summary)} customer summaries")
    
    # Store transformed data
    context['task_instance'].xcom_push(
        key='transformed_data',
        value=customer_summary.to_json(orient='records')
    )
    
    return len(customer_summary)

def load_data(**context):
    """
    Load transformed data to analytics layer.
    
    Lineage tracked:
    - Input: Transformed data
    - Output: s3://data-lake/analytics/customer_transactions/
    - Format: Parquet
    """
    from minio import Minio
    import os
    
    logging.info("Loading data to analytics layer...")
    
    # Get transformed data
    data_json = context['task_instance'].xcom_pull(
        key='transformed_data',
        task_ids='transform_data'
    )
    df = pd.read_json(StringIO(data_json))
    
    # Convert to Parquet
    parquet_buffer = BytesIO()
    df.to_parquet(parquet_buffer, index=False)
    parquet_buffer.seek(0)
    
    # Initialize MinIO client
    client = Minio(
        "minio:9000",
        access_key=os.getenv("MINIO_ACCESS_KEY", "minioadmin"),
        secret_key=os.getenv("MINIO_SECRET_KEY", "minioadmin123"),
        secure=False
    )
    
    # Upload to MinIO
    bucket_name = "data-lake"
    object_name = f"analytics/customer_transactions/data_{datetime.now().strftime('%Y%m%d')}.parquet"
    
    try:
        client.put_object(
            bucket_name,
            object_name,
            parquet_buffer,
            length=len(parquet_buffer.getvalue()),
            content_type='application/octet-stream'
        )
        
        logging.info(f"Loaded {len(df)} records to {bucket_name}/{object_name}")
        return f"s3://{bucket_name}/{object_name}"
        
    except Exception as e:
        logging.error(f"Load failed: {str(e)}")
        raise

def generate_quality_report(**context):
    """
    Generate data quality report.
    
    Lineage tracked:
    - Input: Validation checks
    - Output: s3://data-lake/reports/quality_report.json
    """
    from minio import Minio
    import os
    
    logging.info("Generating quality report...")
    
    # Get validation checks
    checks = context['task_instance'].xcom_pull(
        key='validation_checks',
        task_ids='validate_data'
    )
    
    # Create report
    report = {
        'timestamp': datetime.now().isoformat(),
        'dag_id': context['dag'].dag_id,
        'run_id': context['run_id'],
        'data_quality_checks': checks,
        'validation_status': 'PASSED' if checks['null_transaction_ids'] == 0 else 'FAILED',
        'records_processed': checks['total_records'],
        'quality_score': round(
            1.0 - (
                (checks['null_transaction_ids'] +
                 checks['null_customer_ids'] +
                 checks['negative_amounts'] +
                 checks['duplicate_transactions']) / max(checks['total_records'], 1)
            ),
            2
        )
    }
    
    logging.info(f"Quality Report: {json.dumps(report, indent=2)}")
    
    # Upload report to MinIO
    client = Minio(
        "minio:9000",
        access_key=os.getenv("MINIO_ACCESS_KEY", "minioadmin"),
        secret_key=os.getenv("MINIO_SECRET_KEY", "minioadmin123"),
        secure=False
    )
    
    bucket_name = "data-lake"
    object_name = f"reports/quality_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    
    try:
        report_bytes = json.dumps(report, indent=2).encode('utf-8')
        client.put_object(
            bucket_name,
            object_name,
            BytesIO(report_bytes),
            length=len(report_bytes),
            content_type='application/json'
        )
        
        logging.info(f"Report saved to {bucket_name}/{object_name}")
        return f"s3://{bucket_name}/{object_name}"
        
    except Exception as e:
        logging.error(f"Report generation failed: {str(e)}")
        raise

# Define tasks
extract_task = PythonOperator(
    task_id='extract_data',
    python_callable=extract_data,
    dag=dag,
)

validate_task = PythonOperator(
    task_id='validate_data',
    python_callable=validate_data,
    dag=dag,
)

transform_task = PythonOperator(
    task_id='transform_data',
    python_callable=transform_data,
    dag=dag,
)

load_task = PythonOperator(
    task_id='load_data',
    python_callable=load_data,
    dag=dag,
)

report_task = PythonOperator(
    task_id='generate_quality_report',
    python_callable=generate_quality_report,
    dag=dag,
)

# Define task dependencies
# OpenLineage automatically tracks these dependencies in the lineage graph
extract_task >> validate_task >> transform_task >> load_task >> report_task

"""
Lineage Visualization:

After running this DAG, view the complete lineage in Marquez:

1. Open http://localhost:3001
2. Select namespace: "default" (or your configured namespace)
3. Find DAG: "data_quality_with_lineage"
4. View lineage graph showing:
   
   s3://data-lake/raw/transactions/
           |
           v
   [extract_data] -----> XCom: extracted_data
           |
           v
   [validate_data] ----> XCom: validation_checks, valid_data
           |
           v
   [transform_data] ---> XCom: transformed_data
           |
           v
   [load_data] ---------> s3://data-lake/analytics/customer_transactions/
           |
           v
   [generate_quality_report] --> s3://data-lake/reports/quality_report.json

Each task shows:
- Start/end time
- Duration
- Input datasets
- Output datasets
- Success/failure status
- Error messages (if any)

Column-level lineage shows how each output column is derived from input columns!
"""

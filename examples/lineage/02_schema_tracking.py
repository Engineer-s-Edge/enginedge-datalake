"""
Schema Tracking Example

This example demonstrates how to track dataset schemas and column-level
information in your lineage.
"""

from openlineage.client import OpenLineageClient
from openlineage.client.run import RunEvent, RunState, Run, Job, Dataset
from openlineage.client.facet import SchemaDatasetFacet, SchemaField
from datetime import datetime
import uuid
import time

# Initialize client
client = OpenLineageClient(url="http://localhost:5000")

def schema_tracking_example():
    """
    Track schemas for input and output datasets.
    
    This helps understand:
    - What columns exist in datasets
    - Data types
    - Schema evolution over time
    """
    
    print("=" * 80)
    print("Schema Tracking Example")
    print("=" * 80)
    
    # Define job
    job = Job(namespace="datalake", name="schema_tracking_job")
    run = Run(runId=str(uuid.uuid4()))
    
    # Input dataset with schema
    input_schema = SchemaDatasetFacet(
        fields=[
            SchemaField(name="customer_id", type="INTEGER", description="Unique customer ID"),
            SchemaField(name="name", type="STRING", description="Customer name"),
            SchemaField(name="email", type="STRING", description="Customer email"),
            SchemaField(name="signup_date", type="DATE", description="Account creation date"),
            SchemaField(name="total_purchases", type="INTEGER", description="Number of purchases"),
        ]
    )
    
    input_dataset = Dataset(
        namespace="datalake",
        name="s3://data-lake/raw/customers.csv",
        facets={"schema": input_schema}
    )
    
    print("\n Input Schema:")
    for field in input_schema.fields:
        print(f"   • {field.name}: {field.type} - {field.description}")
    
    # Output dataset with transformed schema
    output_schema = SchemaDatasetFacet(
        fields=[
            SchemaField(name="customer_id", type="INTEGER", description="Unique customer ID"),
            SchemaField(name="customer_name", type="STRING", description="Cleaned customer name"),
            SchemaField(name="email_domain", type="STRING", description="Extracted email domain"),
            SchemaField(name="customer_segment", type="STRING", description="Customer segment (high/medium/low)"),
            SchemaField(name="lifetime_value", type="DOUBLE", description="Calculated customer value"),
            SchemaField(name="processed_at", type="TIMESTAMP", description="Processing timestamp"),
        ]
    )
    
    output_dataset = Dataset(
        namespace="datalake",
        name="s3://data-lake/analytics/customer_segments.parquet",
        facets={"schema": output_schema}
    )
    
    print("\nOutput Schema:")
    for field in output_schema.fields:
        print(f"   • {field.name}: {field.type} - {field.description}")
    
    # Send START event
    print("\nSending START event...")
    start_event = RunEvent(
        eventType=RunState.START,
        eventTime=datetime.now().isoformat(),
        run=run,
        job=job,
        producer="python-script/1.0",
        inputs=[input_dataset],
        outputs=[]
    )
    client.emit(start_event)
    
    # Simulate processing
    print("Processing data with schema transformations...")
    time.sleep(2)
    
    # Send COMPLETE event
    print("Sending COMPLETE event...")
    complete_event = RunEvent(
        eventType=RunState.COMPLETE,
        eventTime=datetime.now().isoformat(),
        run=run,
        job=job,
        producer="python-script/1.0",
        inputs=[input_dataset],
        outputs=[output_dataset]
    )
    client.emit(complete_event)
    
    print("\n" + "=" * 80)
    print("SUCCESS: Schema tracking complete!")
    print("\nIn Marquez, you can now:")
    print("  • View input and output schemas")
    print("  • See column data types")
    print("  • Track schema changes over time")
    print("  • Understand transformations")
    print("=" * 80)

if __name__ == "__main__":
    schema_tracking_example()

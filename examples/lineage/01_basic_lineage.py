"""
Basic OpenLineage Example

This example demonstrates the fundamentals of tracking data lineage
using the OpenLineage Python client.
"""

from openlineage.client import OpenLineageClient
from openlineage.client.run import RunEvent, RunState, Run, Job, Dataset
from openlineage.client.facet import (
    SqlJobFacet,
    SourceCodeLocationJobFacet,
    SchemaDatasetFacet,
    SchemaField
)
from datetime import datetime
import uuid
import time

# Initialize OpenLineage client
client = OpenLineageClient(url="http://localhost:5000")

def basic_lineage_example():
    """
    Basic lineage tracking example.
    
    This shows the minimal information needed to track a job:
    - Job name and namespace
    - Run ID
    - Input and output datasets
    - Event lifecycle (START -> COMPLETE)
    """
    
    print("=" * 80)
    print("Basic Lineage Example")
    print("=" * 80)
    
    # 1. Define the job
    job = Job(
        namespace="datalake",
        name="basic_python_job"
    )
    print(f"\n1. Job: {job.namespace}/{job.name}")
    
    # 2. Create a unique run ID
    run = Run(runId=str(uuid.uuid4()))
    print(f"2. Run ID: {run.runId}")
    
    # 3. Define input dataset
    input_dataset = Dataset(
        namespace="datalake",
        name="s3://data-lake/input/data.csv"
    )
    print(f"3. Input: {input_dataset.name}")
    
    # 4. Define output dataset
    output_dataset = Dataset(
        namespace="datalake",
        name="s3://data-lake/output/processed.parquet"
    )
    print(f"4. Output: {output_dataset.name}")
    
    # 5. Send START event
    print("\n5. Sending START event...")
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
    print("   ✓ START event sent")
    
    # 6. Simulate work
    print("\n6. Processing data...")
    time.sleep(2)
    print("   ✓ Processing complete")
    
    # 7. Send COMPLETE event
    print("\n7. Sending COMPLETE event...")
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
    print("   ✓ COMPLETE event sent")
    
    print("\n" + "=" * 80)
    print("SUCCESS: Basic lineage tracking complete!")
    print("\nView in Marquez:")
    print("  1. Open http://localhost:3001")
    print("  2. Select namespace: datalake")
    print("  3. Find job: basic_python_job")
    print("=" * 80)

if __name__ == "__main__":
    basic_lineage_example()

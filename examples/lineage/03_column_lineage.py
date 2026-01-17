"""
Column Lineage Example

This example demonstrates tracking column-level lineage, showing
exactly how each output column is derived from input columns.
"""

from openlineage.client import OpenLineageClient
from openlineage.client.run import RunEvent, RunState, Run, Job, Dataset
from openlineage.client.facet import (
    SchemaDatasetFacet,
    SchemaField,
    ColumnLineageDatasetFacet,
    ColumnLineageDatasetFacetFieldsAdditional,
    ColumnLineageDatasetFacetFieldsAdditionalInputFields
)
from datetime import datetime
import uuid
import time

# Initialize client
client = OpenLineageClient(url="http://localhost:5000")

def column_lineage_example():
    """
    Track column-level lineage showing how output columns
    are derived from input columns.
    """
    
    print("=" * 80)
    print("Column Lineage Example")
    print("=" * 80)
    
    # Define job
    job = Job(namespace="datalake", name="column_lineage_job")
    run = Run(runId=str(uuid.uuid4()))
    
    # Input datasets
    sales_schema = SchemaDatasetFacet(
        fields=[
            SchemaField(name="sale_id", type="INTEGER"),
            SchemaField(name="customer_id", type="INTEGER"),
            SchemaField(name="amount", type="DOUBLE"),
            SchemaField(name="discount", type="DOUBLE"),
            SchemaField(name="sale_date", type="DATE"),
        ]
    )
    
    sales_dataset = Dataset(
        namespace="datalake",
        name="s3://data-lake/sales/transactions.csv",
        facets={"schema": sales_schema}
    )
    
    customers_schema = SchemaDatasetFacet(
        fields=[
            SchemaField(name="customer_id", type="INTEGER"),
            SchemaField(name="name", type="STRING"),
            SchemaField(name="region", type="STRING"),
            SchemaField(name="segment", type="STRING"),
        ]
    )
    
    customers_dataset = Dataset(
        namespace="datalake",
        name="s3://data-lake/customers/customers.parquet",
        facets={"schema": customers_schema}
    )
    
    # Output dataset with column lineage
    output_schema = SchemaDatasetFacet(
        fields=[
            SchemaField(name="customer_id", type="INTEGER"),
            SchemaField(name="customer_name", type="STRING"),
            SchemaField(name="region", type="STRING"),
            SchemaField(name="total_revenue", type="DOUBLE"),
            SchemaField(name="transaction_count", type="INTEGER"),
            SchemaField(name="avg_transaction", type="DOUBLE"),
        ]
    )
    
    # Define column lineage
    column_lineage = ColumnLineageDatasetFacet(
        fields={
            # customer_id: direct from customers table
            "customer_id": ColumnLineageDatasetFacetFieldsAdditional(
                inputFields=[
                    ColumnLineageDatasetFacetFieldsAdditionalInputFields(
                        namespace="datalake",
                        name="s3://data-lake/customers/customers.parquet",
                        field="customer_id"
                    )
                ],
                transformationType="IDENTITY",
                transformationDescription="Direct copy from customers table"
            ),
            
            # customer_name: from customers.name
            "customer_name": ColumnLineageDatasetFacetFieldsAdditional(
                inputFields=[
                    ColumnLineageDatasetFacetFieldsAdditionalInputFields(
                        namespace="datalake",
                        name="s3://data-lake/customers/customers.parquet",
                        field="name"
                    )
                ],
                transformationType="IDENTITY",
                transformationDescription="Renamed from name to customer_name"
            ),
            
            # region: direct from customers
            "region": ColumnLineageDatasetFacetFieldsAdditional(
                inputFields=[
                    ColumnLineageDatasetFacetFieldsAdditionalInputFields(
                        namespace="datalake",
                        name="s3://data-lake/customers/customers.parquet",
                        field="region"
                    )
                ],
                transformationType="IDENTITY",
                transformationDescription="Direct copy from customers table"
            ),
            
            # total_revenue: SUM(amount - discount) from sales
            "total_revenue": ColumnLineageDatasetFacetFieldsAdditional(
                inputFields=[
                    ColumnLineageDatasetFacetFieldsAdditionalInputFields(
                        namespace="datalake",
                        name="s3://data-lake/sales/transactions.csv",
                        field="amount"
                    ),
                    ColumnLineageDatasetFacetFieldsAdditionalInputFields(
                        namespace="datalake",
                        name="s3://data-lake/sales/transactions.csv",
                        field="discount"
                    )
                ],
                transformationType="AGGREGATION",
                transformationDescription="SUM(amount - discount) grouped by customer"
            ),
            
            # transaction_count: COUNT from sales
            "transaction_count": ColumnLineageDatasetFacetFieldsAdditional(
                inputFields=[
                    ColumnLineageDatasetFacetFieldsAdditionalInputFields(
                        namespace="datalake",
                        name="s3://data-lake/sales/transactions.csv",
                        field="sale_id"
                    )
                ],
                transformationType="AGGREGATION",
                transformationDescription="COUNT(sale_id) grouped by customer"
            ),
            
            # avg_transaction: AVG from sales
            "avg_transaction": ColumnLineageDatasetFacetFieldsAdditional(
                inputFields=[
                    ColumnLineageDatasetFacetFieldsAdditionalInputFields(
                        namespace="datalake",
                        name="s3://data-lake/sales/transactions.csv",
                        field="amount"
                    ),
                    ColumnLineageDatasetFacetFieldsAdditionalInputFields(
                        namespace="datalake",
                        name="s3://data-lake/sales/transactions.csv",
                        field="discount"
                    )
                ],
                transformationType="AGGREGATION",
                transformationDescription="AVG(amount - discount) grouped by customer"
            ),
        }
    )
    
    output_dataset = Dataset(
        namespace="datalake",
        name="s3://data-lake/analytics/customer_revenue.parquet",
        facets={
            "schema": output_schema,
            "columnLineage": column_lineage
        }
    )
    
    print("\nColumn Lineage Mapping:")
    print("-" * 80)
    for col_name, col_lineage in column_lineage.fields.items():
        print(f"\n{col_name}:")
        print(f"  Type: {col_lineage.transformationType}")
        print(f"  Description: {col_lineage.transformationDescription}")
        print(f"  Source columns:")
        for input_field in col_lineage.inputFields:
            print(f"    • {input_field.name}/{input_field.field}")
    print("-" * 80)
    
    # Send events
    print("\nSending START event...")
    start_event = RunEvent(
        eventType=RunState.START,
        eventTime=datetime.now().isoformat(),
        run=run,
        job=job,
        producer="python-script/1.0",
        inputs=[sales_dataset, customers_dataset],
        outputs=[]
    )
    client.emit(start_event)
    
    print("Processing with column transformations...")
    time.sleep(2)
    
    print("Sending COMPLETE event...")
    complete_event = RunEvent(
        eventType=RunState.COMPLETE,
        eventTime=datetime.now().isoformat(),
        run=run,
        job=job,
        producer="python-script/1.0",
        inputs=[sales_dataset, customers_dataset],
        outputs=[output_dataset]
    )
    client.emit(complete_event)
    
    print("\n" + "=" * 80)
    print("SUCCESS: Column lineage tracking complete!")
    print("\nIn Marquez, you can now:")
    print("  • Click on the output dataset")
    print("  • View the 'Column Lineage' tab")
    print("  • See exactly how each column is derived")
    print("  • Understand transformation types")
    print("  • Trace back to source columns")
    print("=" * 80)

if __name__ == "__main__":
    column_lineage_example()

#!/usr/bin/env python3
"""
Advanced ETL with Column-Level Lineage

This example demonstrates column-level lineage tracking, showing exactly
how each output column is derived from input columns.

This job:
1. Reads sales and customer data
2. Joins the datasets
3. Performs aggregations
4. Writes the result with detailed column lineage

OpenLineage automatically tracks:
- Which input columns contribute to each output column
- Join operations
- Aggregation functions
- Filter conditions
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, sum as spark_sum, count, avg, 
    year, month, to_date, coalesce, lit
)
from datetime import datetime
import sys

def create_spark_session(app_name="advanced_etl_with_column_lineage"):
    """Create Spark session with OpenLineage configured."""
    spark = SparkSession.builder \
        .appName(app_name) \
        .getOrCreate()
    
    spark.sparkContext.setLogLevel("WARN")
    return spark

def read_sales_data(spark, sales_path):
    """
    Read sales transactions.
    
    Lineage tracked:
    - Dataset: s3a://data-lake/raw/sales/
    - Columns: sale_id, customer_id, product_id, amount, sale_date
    """
    print(f"Reading sales data from: {sales_path}")
    
    df = spark.read \
        .option("header", "true") \
        .option("inferSchema", "true") \
        .csv(sales_path)
    
    # Ensure proper date format
    df = df.withColumn("sale_date", to_date(col("sale_date")))
    
    print(f"Sales records: {df.count()}")
    return df

def read_customer_data(spark, customer_path):
    """
    Read customer information.
    
    Lineage tracked:
    - Dataset: table default.processed_customers
    - Columns: customer_id, name, email, region, segment
    """
    table_name = "default.processed_customers"
    print(f"Reading customer data from table: {table_name}")
    
    df = spark.read.table(table_name)
    
    print(f"Customer records: {df.count()}")
    return df

def create_customer_sales_summary(sales_df, customer_df):
    """
    Create aggregated customer sales summary.
    
    Column-level lineage tracked:
    - customer_id: FROM customers.customer_id (JOIN key)
    - customer_name: FROM customers.name
    - customer_segment: FROM customers.segment
    - total_sales: AGGREGATION(SUM) FROM sales.amount
    - transaction_count: AGGREGATION(COUNT) FROM sales.sale_id
    - avg_transaction: AGGREGATION(AVG) FROM sales.amount
    - first_purchase_year: AGGREGATION(MIN) + EXTRACT(YEAR) FROM sales.sale_date
    - last_purchase_year: AGGREGATION(MAX) + EXTRACT(YEAR) FROM sales.sale_date
    """
    print("Creating customer sales summary...")
    
    # Add year columns for temporal analysis
    sales_with_year = sales_df.withColumn(
        "sale_year",
        year(col("sale_date"))
    ).withColumn(
        "sale_month",
        month(col("sale_date"))
    )
    
    # Join sales with customers
    # Lineage tracks this relationship: sales + customers -> joined_data
    joined = sales_with_year.join(
        customer_df,
        on="customer_id",
        how="inner"
    )
    
    print(f"Joined records: {joined.count()}")
    
    # Aggregate by customer
    # Each aggregation function is tracked in the lineage
    summary = joined.groupBy("customer_id", "name", "segment") \
        .agg(
            spark_sum("amount").alias("total_sales"),
            count("sale_id").alias("transaction_count"),
            avg("amount").alias("avg_transaction_amount"),
            year(col("sale_date")).alias("first_purchase_year"),
            year(col("sale_date")).alias("last_purchase_year")
        )
    
    # Add derived columns
    # These transformations are also tracked
    summary = summary.withColumn(
        "customer_value_segment",
        when(col("total_sales") > 10000, "High")
        .when(col("total_sales") > 5000, "Medium")
        .otherwise("Low")
    )
    
    # Add processing metadata
    summary = summary.withColumn(
        "processed_at",
        lit(datetime.now().isoformat())
    )
    
    print(f"Summary records: {summary.count()}")
    print("\nSample data:")
    summary.show(5, truncate=False)
    
    return summary

def write_summary(df, output_path):
    """
    Write customer sales summary.
    
    Lineage tracked:
    - Output dataset: s3a://data-lake/analytics/customer_sales_summary/
    - All column mappings from input to output
    - Partition strategy
    """
    print(f"Writing summary to: {output_path}")
    
    df.write \
        .mode("overwrite") \
        .partitionBy("processed_at") \
        .parquet(output_path)
    
    print("Write complete!")

def main():
    """
    Main pipeline with column-level lineage.
    
    This pipeline demonstrates:
    1. Multi-source lineage (sales + customers)
    2. Join lineage (which datasets were joined)
    3. Column-level lineage (how each column is derived)
    4. Aggregation lineage (which functions were used)
    5. Partition lineage (how data is organized)
    
    All of this is automatically captured by OpenLineage!
    """
    # Configuration
    sales_path = "s3a://data-lake/raw/sales/*.csv"
    customer_path = "s3a://data-lake/processed/customers/"
    output_path = "s3a://data-lake/analytics/customer_sales_summary/"
    
    if len(sys.argv) > 1:
        sales_path = sys.argv[1]
    if len(sys.argv) > 2:
        customer_path = sys.argv[2]
    if len(sys.argv) > 3:
        output_path = sys.argv[3]
    
    print("=" * 80)
    print("Advanced ETL with Column-Level Lineage")
    print("=" * 80)
    print(f"Sales Input:    {sales_path}")
    print(f"Customer Input: {customer_path}")
    print(f"Output:         {output_path}")
    print("=" * 80)
    
    try:
        # Create Spark session
        spark = create_spark_session()
        
        # Read both datasets
        sales_df = read_sales_data(spark, sales_path)
        customer_df = read_customer_data(spark, customer_path)
        
        # Create summary with joins and aggregations
        summary_df = create_customer_sales_summary(sales_df, customer_df)
        
        # Write result
        write_summary(summary_df, output_path)
        
        print("=" * 80)
        print("SUCCESS: Job completed successfully!")
        print("=" * 80)
        print("\nView column-level lineage in Marquez:")
        print("  1. Open http://localhost:3001")
        print("  2. Select namespace: datalake")
        print("  3. Find job: advanced_etl_with_column_lineage")
        print("  4. Click on output dataset")
        print("  5. View column lineage tab")
        print("  6. See how each column is derived!")
        print("=" * 80)
        
    except Exception as e:
        print("=" * 80)
        print(f"ERROR: Job failed with error: {str(e)}")
        print("=" * 80)
        raise
    
    finally:
        spark.stop()

if __name__ == "__main__":
    main()

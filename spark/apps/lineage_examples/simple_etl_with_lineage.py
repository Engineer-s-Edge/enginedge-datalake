#!/usr/bin/env python3
"""
Simple ETL Job with Data Lineage

This example demonstrates automatic data lineage tracking with Spark and OpenLineage.
The lineage is automatically captured by the OpenLineage Spark listener configured
in the cluster.

This job:
1. Reads raw customer data from S3/MinIO
2. Performs data cleaning and transformation
3. Writes processed data back to S3/MinIO

All lineage is automatically tracked and sent to Marquez.
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, upper, regexp_replace, when
from datetime import datetime
import sys

def create_spark_session(app_name="simple_etl_with_lineage"):
    """
    Create Spark session with OpenLineage configuration.
    
    The OpenLineage listener is already configured in spark-defaults.conf,
    so we don't need to add it here. But we're showing how to do it
    programmatically if needed.
    """
    spark = SparkSession.builder \
        .appName(app_name) \
        .config("spark.jars.packages", "io.openlineage:openlineage-spark:1.39.0") \
        .config("spark.extraListeners", "io.openlineage.spark.agent.OpenLineageSparkListener") \
        .config("spark.openlineage.transport.type", "http") \
        .config("spark.openlineage.transport.url", "http://marquez-api:5000") \
        .config("spark.openlineage.namespace", "datalake") \
        .getOrCreate()
    
    spark.sparkContext.setLogLevel("WARN")
    return spark

def read_raw_data(spark, input_path):
    """
    Read raw customer data.
    
    This operation is automatically tracked by OpenLineage:
    - Input dataset: s3a://data-lake/raw/customers/
    - Schema information
    - Number of records
    """
    print(f"Reading data from: {input_path}")
    df = spark.read \
        .option("header", "true") \
        .option("inferSchema", "true") \
        .csv(input_path)
    
    print(f"Records read: {df.count()}")
    print("Schema:")
    df.printSchema()
    
    return df

def clean_data(df):
    """
    Clean and transform data.
    
    OpenLineage tracks these transformations:
    - Column operations (select, withColumn)
    - Filter operations
    - Data quality rules
    """
    print("Cleaning data...")
    
    # Remove duplicates
    df_clean = df.dropDuplicates(["customer_id"])
    
    # Clean email addresses
    df_clean = df_clean.withColumn(
        "email",
        regexp_replace(col("email"), " ", "")
    )
    
    # Normalize names
    df_clean = df_clean.withColumn(
        "name",
        upper(col("name"))
    )
    
    # Filter out invalid records
    df_clean = df_clean.filter(
        (col("customer_id").isNotNull()) &
        (col("email").isNotNull()) &
        (col("email").contains("@"))
    )
    
    # Add processing timestamp
    df_clean = df_clean.withColumn(
        "processed_at",
        when(col("customer_id").isNotNull(), datetime.now().isoformat())
    )
    
    print(f"Records after cleaning: {df_clean.count()}")
    return df_clean

def write_processed_data(df, output_path):
    """
    Write processed data to output location.
    
    OpenLineage tracks:
    - Output dataset: s3a://data-lake/processed/customers/
    - Write format (parquet)
    - Partition information
    - Number of records written
    """
    print(f"Writing data to: {output_path}")
    
    df.write \
        .mode("overwrite") \
        .partitionBy("processed_at") \
        .parquet(output_path)
    
    print("Write complete!")

def main():
    """
    Main ETL pipeline.
    
    This entire pipeline is tracked as a single "job" in Marquez:
    - Job name: simple_etl_with_lineage
    - Namespace: datalake
    - Input datasets
    - Output datasets
    - Run duration
    - Run status (success/failure)
    """
    # Configuration
    input_path = "s3a://data-lake/raw/customers/*.csv"
    output_path = "s3a://data-lake/processed/customers/"
    
    if len(sys.argv) > 1:
        input_path = sys.argv[1]
    if len(sys.argv) > 2:
        output_path = sys.argv[2]
    
    print("=" * 80)
    print("Simple ETL Job with Data Lineage")
    print("=" * 80)
    print(f"Input:  {input_path}")
    print(f"Output: {output_path}")
    print("=" * 80)
    
    try:
        # Create Spark session
        spark = create_spark_session()
        
        # Read data (lineage tracked automatically)
        df_raw = read_raw_data(spark, input_path)
        
        # Transform data (lineage tracked automatically)
        df_clean = clean_data(df_raw)
        
        # Write data (lineage tracked automatically)
        write_processed_data(df_clean, output_path)
        
        print("=" * 80)
        print("SUCCESS: Job completed successfully!")
        print("=" * 80)
        print("\nView lineage in Marquez:")
        print("  1. Open http://localhost:3001")
        print("  2. Select namespace: datalake")
        print("  3. Find job: simple_etl_with_lineage")
        print("  4. View the lineage graph")
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

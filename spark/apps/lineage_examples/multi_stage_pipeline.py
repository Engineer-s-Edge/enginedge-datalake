#!/usr/bin/env python3
"""
Multi-Stage Pipeline with Lineage

This example demonstrates a multi-stage data pipeline where each stage
produces intermediate outputs. This creates a complete lineage graph
showing data flowing through multiple transformations.

Pipeline stages:
1. Ingest: Raw data -> Bronze layer
2. Clean: Bronze -> Silver layer
3. Enrich: Silver -> Gold layer
4. Aggregate: Gold -> Analytics layer

Each stage is tracked as a separate job run, creating a complete
lineage chain from raw data to final analytics.
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, current_timestamp, lit, when,
    md5, concat_ws, regexp_replace, trim,
    count, avg
)
import sys

def create_spark_session(stage_name):
    """Create Spark session for a specific stage."""
    app_name = f"multi_stage_pipeline_{stage_name}"
    
    spark = SparkSession.builder \
        .appName(app_name) \
        .getOrCreate()
    
    spark.sparkContext.setLogLevel("WARN")
    return spark

def stage_1_ingest(input_path, output_path):
    """
    Stage 1: Ingest raw data
    
    Lineage: raw_source -> bronze_layer
    
    This stage reads raw data and writes it to the bronze layer
    with minimal transformation (just adding ingestion metadata).
    """
    print("=" * 80)
    print("STAGE 1: INGEST")
    print("=" * 80)
    
    spark = create_spark_session("ingest")
    
    try:
        print(f"Reading raw data from: {input_path}")
        df = spark.read \
            .option("header", "true") \
            .option("inferSchema", "true") \
            .csv(input_path)
        
        # Add ingestion metadata
        df_bronze = df.withColumn("ingestion_timestamp", current_timestamp()) \
                      .withColumn("source_system", lit("raw_file"))
        
        print(f"Writing bronze layer to table: default.bronze_layer")
        df_bronze.writeTo("default.bronze_layer").createOrReplace()
        
        print(f"✓ Stage 1 complete: {df_bronze.count()} records")
        return True
        
    except Exception as e:
        print(f"✗ Stage 1 failed: {str(e)}")
        raise
    finally:
        spark.stop()

def stage_2_clean(input_path, output_path):
    """
    Stage 2: Clean and standardize
    
    Lineage: bronze_layer -> silver_layer
    
    This stage cleans data, removes duplicates, and standardizes formats.
    """
    print("=" * 80)
    print("STAGE 2: CLEAN")
    print("=" * 80)
    
    spark = create_spark_session("clean")
    
    try:
        print(f"Reading bronze layer from table: default.bronze_layer")
        df = spark.read.table("default.bronze_layer")
        
        # Clean and standardize
        df_silver = df.dropDuplicates() \
            .withColumn("email", trim(regexp_replace(col("email"), " ", ""))) \
            .withColumn("phone", regexp_replace(col("phone"), "[^0-9]", "")) \
            .filter(col("email").isNotNull()) \
            .withColumn("cleaning_timestamp", current_timestamp()) \
            .withColumn("data_quality_score", lit(0.95))
        
        print(f"Writing silver layer to table: default.silver_layer")
        df_silver.writeTo("default.silver_layer").createOrReplace()
        
        print(f"✓ Stage 2 complete: {df_silver.count()} records")
        return True
        
    except Exception as e:
        print(f"✗ Stage 2 failed: {str(e)}")
        raise
    finally:
        spark.stop()

def stage_3_enrich(input_path, lookup_path, output_path):
    """
    Stage 3: Enrich with additional data
    
    Lineage: silver_layer + lookup_data -> gold_layer
    
    This stage enriches data by joining with reference datasets.
    """
    print("=" * 80)
    print("STAGE 3: ENRICH")
    print("=" * 80)
    
    spark = create_spark_session("enrich")
    
    try:
        print(f"Reading silver layer from: {input_path}")
        df = spark.read.parquet(input_path)
        
        # In a real scenario, we'd join with lookup tables
        # For this example, we'll add derived fields
        df_gold = df \
            .withColumn("customer_hash", md5(concat_ws("_", col("customer_id"), col("email")))) \
            .withColumn("is_premium", when(col("data_quality_score") > 0.9, True).otherwise(False)) \
            .withColumn("enrichment_timestamp", current_timestamp())
        
        print(f"Writing gold layer to: {output_path}")
        df_gold.write.mode("overwrite").parquet(output_path)
        
        print(f"✓ Stage 3 complete: {df_gold.count()} records")
        return True
        
    except Exception as e:
        print(f"✗ Stage 3 failed: {str(e)}")
        raise
    finally:
        spark.stop()

def stage_4_aggregate(input_path, output_path):
    """
    Stage 4: Create aggregated analytics
    
    Lineage: gold_layer -> analytics_layer
    
    This stage creates aggregated views for analytics and reporting.
    """
    print("=" * 80)
    print("STAGE 4: AGGREGATE")
    print("=" * 80)
    
    spark = create_spark_session("aggregate")
    
    try:
        print(f"Reading gold layer from: {input_path}")
        df = spark.read.parquet(input_path)
        
        # Create aggregations
        df_analytics = df.groupBy("is_premium") \
            .agg(
                count("customer_id").alias("customer_count"),
                avg("data_quality_score").alias("avg_quality_score")
            ) \
            .withColumn("aggregation_timestamp", current_timestamp())
        
        print(f"Writing analytics layer to: {output_path}")
        df_analytics.write.mode("overwrite").parquet(output_path)
        
        print(f"✓ Stage 4 complete: {df_analytics.count()} records")
        print("\nAggregation results:")
        df_analytics.show()
        
        return True
        
    except Exception as e:
        print(f"✗ Stage 4 failed: {str(e)}")
        raise
    finally:
        spark.stop()

def main():
    """
    Execute multi-stage pipeline.
    
    Each stage runs as a separate Spark job, creating individual
    lineage entries in Marquez. Together, they form a complete
    lineage graph showing data flowing through all stages:
    
    Raw -> Bronze -> Silver -> Gold -> Analytics
    
    This pattern is common in medallion/lakehouse architectures.
    """
    # Configuration
    base_path = "s3a://data-lake"
    
    if len(sys.argv) > 1:
        base_path = sys.argv[1]
    
    # Define paths for each layer
    raw_path = f"{base_path}/raw/customers/*.csv"
    bronze_path = f"{base_path}/bronze/customers"
    silver_path = f"{base_path}/silver/customers"
    gold_path = f"{base_path}/gold/customers"
    analytics_path = f"{base_path}/analytics/customer_summary"
    lookup_path = f"{base_path}/reference/lookups"
    
    print("=" * 80)
    print("MULTI-STAGE PIPELINE WITH LINEAGE")
    print("=" * 80)
    print(f"Base path: {base_path}")
    print("=" * 80)
    print("\nPipeline:")
    print(f"  1. Raw       -> Bronze:    {raw_path} -> {bronze_path}")
    print(f"  2. Bronze    -> Silver:    {bronze_path} -> {silver_path}")
    print(f"  3. Silver    -> Gold:      {silver_path} -> {gold_path}")
    print(f"  4. Gold      -> Analytics: {gold_path} -> {analytics_path}")
    print("=" * 80)
    
    try:
        # Execute each stage
        stage_1_ingest(raw_path, bronze_path)
        stage_2_clean(bronze_path, silver_path)
        stage_3_enrich(silver_path, lookup_path, gold_path)
        stage_4_aggregate(gold_path, analytics_path)
        
        print("=" * 80)
        print("SUCCESS: All pipeline stages completed!")
        print("=" * 80)
        print("\nView complete pipeline lineage in Marquez:")
        print("  1. Open http://localhost:3001")
        print("  2. Select namespace: datalake")
        print("  3. Find jobs:")
        print("     - multi_stage_pipeline_ingest")
        print("     - multi_stage_pipeline_clean")
        print("     - multi_stage_pipeline_enrich")
        print("     - multi_stage_pipeline_aggregate")
        print("  4. View the complete lineage graph")
        print("  5. See data flow through all stages!")
        print("=" * 80)
        
    except Exception as e:
        print("=" * 80)
        print(f"ERROR: Pipeline failed at stage: {str(e)}")
        print("=" * 80)
        raise

if __name__ == "__main__":
    main()

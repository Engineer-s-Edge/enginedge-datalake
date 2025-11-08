# Spark Lineage Examples

This directory contains example Spark jobs that demonstrate automatic data lineage tracking with OpenLineage and Marquez.

## Examples

### 1. Simple ETL with Lineage (`simple_etl_with_lineage.py`)

A basic ETL job showing:
- Reading CSV data from S3/MinIO
- Data cleaning transformations
- Writing Parquet output
- Automatic lineage tracking

**Run:**
```bash
docker exec -it spark-master spark-submit \
  --master spark://spark-master:7077 \
  /opt/spark-apps/lineage_examples/simple_etl_with_lineage.py
```

### 2. Advanced ETL with Column-Level Lineage (`advanced_etl_with_column_lineage.py`)

Shows column-level lineage tracking:
- Multi-source data (sales + customers)
- Join operations
- Aggregations (SUM, COUNT, AVG)
- Derived columns
- Complete column lineage graph

**Run:**
```bash
docker exec -it spark-master spark-submit \
  --master spark://spark-master:7077 \
  /opt/spark-apps/lineage_examples/advanced_etl_with_column_lineage.py
```

### 3. Multi-Stage Pipeline (`multi_stage_pipeline.py`)

Demonstrates a medallion architecture pipeline:
1. **Ingest**: Raw → Bronze layer
2. **Clean**: Bronze → Silver layer
3. **Enrich**: Silver → Gold layer
4. **Aggregate**: Gold → Analytics layer

Each stage creates separate lineage entries, forming a complete pipeline graph.

**Run:**
```bash
docker exec -it spark-master spark-submit \
  --master spark://spark-master:7077 \
  /opt/spark-apps/lineage_examples/multi_stage_pipeline.py
```

## How It Works

### Automatic Lineage Capture

The Spark cluster is configured with OpenLineage listener in `spark-defaults.conf`:

```properties
spark.extraListeners=io.openlineage.spark.agent.OpenLineageSparkListener
spark.openlineage.transport.type=http
spark.openlineage.transport.url=http://marquez-api:5000
spark.openlineage.namespace=datalake
```

This configuration automatically captures:
- **Job information**: Name, start time, duration, status
- **Input datasets**: All data sources read
- **Output datasets**: All data sinks written
- **Transformations**: Operations performed on data
- **Column lineage**: How each output column is derived
- **Execution metrics**: Rows read/written, data size, etc.

### What Gets Tracked

#### Dataset Information
- URI (s3a://bucket/path, file://, jdbc://, etc.)
- Schema (column names and types)
- Number of records
- Data format (Parquet, CSV, JSON, etc.)
- Partition information

#### Column Lineage
- Source columns for each output column
- Transformation type (PROJECTION, AGGREGATION, JOIN, etc.)
- Transformation description (formulas, functions)

#### Job Metadata
- Job name and namespace
- Start/end timestamps
- Success/failure status
- Error messages (if failed)
- Source code location

## Viewing Lineage

### Marquez Web UI

1. Open http://localhost:3001
2. Select namespace: `datalake`
3. Browse jobs and datasets
4. Click on any job to see:
   - Run history
   - Input/output datasets
   - Lineage graph
   - Column-level lineage

### Marquez API

Query lineage programmatically:

```bash
# Get all jobs
curl http://localhost:5000/api/v1/namespaces/datalake/jobs

# Get job details
curl http://localhost:5000/api/v1/namespaces/datalake/jobs/simple_etl_with_lineage

# Get lineage graph
curl http://localhost:5000/api/v1/lineage?nodeId=job:datalake:simple_etl_with_lineage
```

## Creating Sample Data

To test these examples, create some sample CSV data:

```bash
# Create sample customers data
docker exec -it minio mkdir -p /data/data-lake/raw/customers

cat > customers.csv << EOF
customer_id,name,email,region,segment
1,John Doe,john@example.com,US,Premium
2,Jane Smith,jane@example.com,EU,Standard
3,Bob Johnson,bob@example.com,US,Premium
EOF

docker cp customers.csv minio:/data/data-lake/raw/customers/

# Create sample sales data
cat > sales.csv << EOF
sale_id,customer_id,product_id,amount,sale_date
1001,1,P100,150.00,2025-01-15
1002,2,P200,75.50,2025-01-16
1003,1,P100,150.00,2025-02-20
EOF

docker cp sales.csv minio:/data/data-lake/raw/sales/
```

## Best Practices

### 1. Use Meaningful Job Names

```python
# Good
app_name = "customer_daily_aggregation"

# Bad
app_name = "job1"
```

### 2. Use Fully Qualified Paths

```python
# Good
input_path = "s3a://data-lake/raw/customers/*.csv"

# Bad
input_path = "../data.csv"
```

### 3. Add Metadata

```python
spark.conf.set("spark.openlineage.job.metadata.owner", "data-team")
spark.conf.set("spark.openlineage.job.metadata.description", "Daily customer aggregation")
```

### 4. Handle Failures Properly

Ensure FAIL events are sent when jobs fail:
```python
try:
    # Your job logic
    process_data()
except Exception as e:
    # OpenLineage will automatically send FAIL event
    raise
finally:
    spark.stop()
```

### 5. Test Lineage Locally

Before deploying to production:
1. Run job locally
2. Check Marquez UI
3. Verify datasets appear
4. Confirm lineage graph is correct

## Troubleshooting

### Lineage Not Appearing

1. **Check Marquez is running:**
   ```bash
   docker ps | grep marquez
   curl http://localhost:5000/api/v1/health
   ```

2. **Check Spark configuration:**
   ```bash
   docker exec spark-master cat /opt/spark/conf/spark-defaults.conf
   ```

3. **Check network connectivity:**
   ```bash
   docker exec spark-master curl http://marquez-api:5000/api/v1/health
   ```

4. **Check Spark logs:**
   ```bash
   docker logs spark-master | grep -i openlineage
   ```

### Incomplete Lineage

1. Ensure all datasets use fully qualified URIs
2. Check that data sources are supported (Parquet, CSV, JSON, Hive, JDBC)
3. Verify Spark version compatibility (3.x required)

### Performance Issues

If OpenLineage impacts performance:
1. Use asynchronous mode (default)
2. Reduce event detail level
3. Batch events
4. Monitor Marquez API performance

## Next Steps

1. Run the examples above
2. Modify them for your use cases
3. Create your own lineage-tracked jobs
4. Explore the Marquez Web UI
5. Query lineage via API
6. Set up alerts for lineage changes

## Resources

- [OpenLineage Documentation](https://openlineage.io/docs/)
- [Marquez Documentation](https://marquezproject.github.io/marquez/)
- [OpenLineage Spark Integration](https://openlineage.io/docs/integrations/spark/)
- [Main Lineage Documentation](../../../DATA_LINEAGE.md)

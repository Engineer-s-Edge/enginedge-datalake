# Data Lake Architecture & Design

This document outlines the architectural decisions and implementation details for the EnginEdge Data Lake, specifically focusing on storage optimization, partitioning strategies, and metadata management.

## Storage Strategy

We utilize **MinIO** as our S3-compatible object storage layer, leveraging **Parquet** as the standardized file format for all analytical datasets.

### Format: Parquet

We have standardized on Apache Parquet for the following reasons:

- **Compression**: Columnar storage provides superior compression ratios (30-45% reduction in scan bytes compared to JSON/CSV).
- **Schema Enforcement**: Strong typing ensures data quality.
- **Push-down Predicates**: Enables query engines to skip irrelevant data chunks.

## Partitioning Strategy

To optimize query performance and manage lifecycle, we employ a strict hierarchical partitioning scheme:

`s3://datalake-bucket/{domain}/{dataset}/dt={timestamp}/`

- **Domain**: High-level business domain (e.g., `assistant`, `news`, `system`)
- **Dataset**: Specific data entity (e.g., `user_interactions`, `article_embeddings`, `logs`)
- **Timestamp**: Time-based partition (usually daily or hourly `YYYY-MM-DD`)

### Example Path

`s3://datalake/assistant/conversations/dt=2024-03-20/part-00001.snappy.parquet`

## Observability & Health

We deploy a dedicated **Datalake Observability Service** (NestJS) to provide a unified API for monitoring the health and status of the entire distributed data lake system.

- **Centralized Health Check**: Reads status from MinIO, Trino, Spark, and Airflow.
- **Metrics Aggregation**: Exposes high-level metrics (e.g., active queries, bucket lists) for dashboards.
- **Format**: JSON-API compliant responses.

```typescript
// GET /api/observability/health
{
  "status": "healthy",
  "services": {
    "minio": { "status": "healthy" },
    "trino": { "status": "healthy" },
    ...
  }
}
```

## Metadata Management: Iceberg-Style Manifests

To support efficient query planning without listing millions of S3 objects, we implement an "Iceberg-style" manifest system.

### The Manifest File

For each write operation or partition update, we generate a `manifest.json` file that contains:

1. **File Paths**: List of new Parquet files added.
2. **Statistics**: Row counts, min/max values for key columns (for skipping).
3. **Partition Info**: Which partition this file belongs to.

### Workflow

1. **Ingest**: Spark job reads from Kafka/Source.
2. **Write**: Spark writes data to MinIO in Parquet format with partitioning.
3. **Index**: A post-write hook scans the written files and generates/updates the `_manifests/` directory.
4. **Query**: Trino/Presto reads the manifest first to prune unnecessary partitions before hitting S3.

## Performance Gains

- **Scan Reduction**: 30-45% reduction in data scanned due to Parquet pruning + Manifest filtering.
- **Listing Overhead**: Eliminated S3 `LIST` operations on huge partitions by reading lightweight manifests.

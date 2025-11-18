# EnginEdge Data Lake Helm Chart

A comprehensive Helm chart for deploying the EnginEdge Data Lake infrastructure on Kubernetes. This chart includes Trino, Apache Spark, Apache Airflow, MinIO, PostgreSQL, Hive Metastore, and data lineage tracking with Marquez.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (for persistent storage)

## Quick Links

- **[Local Deployment Guide](LOCAL_DEPLOYMENT.md)** - Deploy on kind, k3d, Docker Desktop, or Minikube
- **[Quickstart](QUICKSTART.md)** - Get started quickly
- **[Implementation Summary](IMPLEMENTATION_SUMMARY.md)** - Architecture and design details

## Components

This Helm chart deploys the following components:

- **MinIO**: S3-compatible object storage
- **PostgreSQL**: Database backend for Airflow and Hive Metastore
- **Hive Metastore**: Metadata management for data lake tables
- **Trino**: Distributed SQL query engine
- **Apache Spark**: Distributed data processing (Master + Workers)
- **Apache Airflow**: Workflow orchestration and scheduling
- **Marquez**: OpenLineage-based data lineage tracking
- **Jupyter**: Interactive notebook environment
- **Great Expectations**: Data quality validation
- **Tokern**: Data governance and discovery

## Installation

### Local Cluster (kind, k3d, Docker Desktop, Minikube)

For local development, use the provided PowerShell script:

```powershell
# Quick install with default local settings
.\deploy-local.ps1

# Minimal installation (core services only)
.\deploy-local.ps1 -Minimal

# Without persistence (ephemeral)
.\deploy-local.ps1 -NoPersistence

# Or manually with Helm
helm install datalake . -n datalake --values values-local.yaml --create-namespace
```

See **[LOCAL_DEPLOYMENT.md](LOCAL_DEPLOYMENT.md)** for detailed instructions.

### Development Environment

```bash
helm install datalake . -n datalake-dev --values values-dev.yaml --create-namespace
```

### Production Environment

```bash
helm install datalake . -n datalake-prod --values values-prod.yaml --create-namespace
```

### Install from local chart

```bash
# Create namespace
kubectl create namespace datalake

# Install the chart
helm install datalake . -n datalake

# Or install with custom values
helm install datalake . -n datalake -f custom-values.yaml
```

### Upgrade an existing release

```bash
helm upgrade datalake ./datalake -n datalake
```

### Uninstall

```bash
helm uninstall datalake -n datalake
```

## Configuration

The following table lists the configurable parameters of the Data Lake chart and their default values.

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.namespace` | Kubernetes namespace | `datalake` |
| `global.labels.app` | Application label | `enginedge` |
| `global.labels.environment` | Environment label | `development` |

### MinIO Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `minio.enabled` | Enable MinIO deployment | `true` |
| `minio.replicaCount` | Number of MinIO replicas | `1` |
| `minio.image.repository` | MinIO image repository | `minio/minio` |
| `minio.image.tag` | MinIO image tag | `RELEASE.2023-09-07T02-05-02Z` |
| `minio.service.port` | MinIO API port | `9000` |
| `minio.service.consolePort` | MinIO console port | `9001` |
| `minio.persistence.enabled` | Enable persistent storage | `true` |
| `minio.persistence.size` | Storage size | `10Gi` |
| `minio.rootUser` | MinIO root username | `minioadmin` |
| `minio.rootPassword` | MinIO root password | `minioadmin123` |

### PostgreSQL Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgres.enabled` | Enable PostgreSQL deployment | `true` |
| `postgres.replicaCount` | Number of PostgreSQL replicas | `1` |
| `postgres.image.repository` | PostgreSQL image repository | `postgres` |
| `postgres.image.tag` | PostgreSQL image tag | `14` |
| `postgres.service.port` | PostgreSQL service port | `5432` |
| `postgres.persistence.enabled` | Enable persistent storage | `true` |
| `postgres.persistence.size` | Storage size | `5Gi` |
| `postgres.user` | PostgreSQL username | `airflow` |
| `postgres.password` | PostgreSQL password | `airflow` |
| `postgres.database` | PostgreSQL database name | `airflow` |

### Trino Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `trino.enabled` | Enable Trino deployment | `true` |
| `trino.replicaCount` | Number of Trino replicas | `1` |
| `trino.image.repository` | Trino image repository | `trinodb/trino` |
| `trino.image.tag` | Trino image tag | `418` |
| `trino.service.port` | Trino service port | `8080` |
| `trino.config.maxMemory` | Maximum query memory | `2GB` |
| `trino.config.maxMemoryPerNode` | Maximum memory per node | `1GB` |

### Spark Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `spark.enabled` | Enable Spark deployment | `true` |
| `spark.master.replicaCount` | Number of Spark master replicas | `1` |
| `spark.worker.replicaCount` | Number of Spark worker replicas | `2` |
| `spark.master.service.webPort` | Spark master web UI port | `8080` |
| `spark.master.service.masterPort` | Spark master port | `7077` |
| `spark.worker.service.webPort` | Spark worker web UI port | `8081` |
| `spark.openlineage.enabled` | Enable OpenLineage integration | `true` |

### Airflow Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `airflow.enabled` | Enable Airflow deployment | `true` |
| `airflow.replicaCount` | Number of Airflow replicas | `1` |
| `airflow.image.repository` | Airflow image repository | `apache/airflow` |
| `airflow.image.tag` | Airflow image tag | `2.6.3` |
| `airflow.service.port` | Airflow web UI port | `8080` |
| `airflow.executor` | Airflow executor type | `LocalExecutor` |
| `airflow.webserverUser` | Airflow admin username | `admin` |
| `airflow.webserverPassword` | Airflow admin password | `admin123` |
| `airflow.persistence.logs.enabled` | Enable logs persistence | `true` |
| `airflow.persistence.logs.size` | Logs storage size | `5Gi` |

## Examples

### Minimal Installation

Install with default values:

```bash
helm install datalake ./datalake -n datalake
```

### Custom Storage Classes

```yaml
# custom-values.yaml
minio:
  persistence:
    storageClass: "fast-ssd"
    size: 50Gi

postgres:
  persistence:
    storageClass: "fast-ssd"
    size: 20Gi
```

```bash
helm install datalake ./datalake -n datalake -f custom-values.yaml
```

### Production Configuration

```yaml
# production-values.yaml
global:
  labels:
    environment: production

minio:
  replicaCount: 3
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"
  persistence:
    size: 100Gi

postgres:
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
  persistence:
    size: 20Gi

spark:
  worker:
    replicaCount: 5
    resources:
      requests:
        memory: "4Gi"
        cpu: "2000m"
      limits:
        memory: "8Gi"
        cpu: "4000m"

trino:
  replicaCount: 2
  resources:
    requests:
      memory: "4Gi"
      cpu: "2000m"
    limits:
      memory: "8Gi"
      cpu: "4000m"
```

### Disable Optional Components

```yaml
# minimal-values.yaml
jupyter:
  enabled: false

greatExpectations:
  enabled: false

tokern:
  enabled: false

marquez:
  enabled: false
```

## Accessing Services

After installation, you can access the services using port-forwarding:

```bash
# Trino
kubectl port-forward -n datalake svc/trino 8080:8080
# Access at: http://localhost:8080

# Airflow
kubectl port-forward -n datalake svc/airflow 8082:8080
# Access at: http://localhost:8082

# Spark Master UI
kubectl port-forward -n datalake svc/spark-master 8083:8080
# Access at: http://localhost:8083

# MinIO Console
kubectl port-forward -n datalake svc/minio 9001:9001
# Access at: http://localhost:9001
```

## Monitoring

Enable ServiceMonitor for Prometheus Operator:

```yaml
serviceMonitor:
  enabled: true
  interval: 30s
  labels:
    prometheus: kube-prometheus
```

## Troubleshooting

### Check pod status

```bash
kubectl get pods -n datalake
```

### View logs

```bash
# All pods
kubectl logs -n datalake -l app.kubernetes.io/name=datalake

# Specific component
kubectl logs -n datalake -l app.kubernetes.io/component=trino
```

### Describe pod for events

```bash
kubectl describe pod -n datalake <pod-name>
```

### Check PVC status

```bash
kubectl get pvc -n datalake
```

## Upgrading

To upgrade to a new version:

```bash
helm upgrade datalake ./datalake -n datalake
```

## Contributing

Please refer to the main repository's CONTRIBUTING.md for guidelines.

## License

See LICENSE file in the main repository.

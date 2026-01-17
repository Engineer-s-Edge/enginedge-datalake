# Values Files Comparison

This document compares the different values files available for deploying the EnginEdge Datalake.

## Available Values Files

| File | Purpose | Use Case |
|------|---------|----------|
| `values.yaml` | Base configuration | Default settings, can be used as-is or as a base for customization |
| `values-local.yaml` | Local clusters | kind, k3d, Docker Desktop, Minikube - optimized for single-node local development |
| `values-dev.yaml` | Development environment | Remote dev clusters, CI/CD testing, minimal resources |
| `values-prod.yaml` | Production environment | Production deployments with HA, high resources, and full features |

## Resource Comparison

### Memory Allocations

| Component | values.yaml | values-local.yaml | values-dev.yaml | values-prod.yaml |
|-----------|-------------|-------------------|-----------------|------------------|
| MinIO | 512Mi - 2Gi | 256Mi - 1Gi | 256Mi - 512Mi | 2Gi - 4Gi |
| PostgreSQL | 256Mi - 1Gi | 128Mi - 512Mi | 128Mi - 512Mi | 2Gi - 4Gi |
| Trino | 2Gi - 4Gi | 1Gi - 2Gi | 1Gi - 2Gi | 8Gi - 16Gi |
| Spark Master | 1Gi - 2Gi | 512Mi - 1Gi | 512Mi - 1Gi | 4Gi - 8Gi |
| Spark Worker | 1Gi - 2Gi | 512Mi - 1Gi | 512Mi - 1Gi | 8Gi - 16Gi |
| Airflow | 1Gi - 2Gi | 512Mi - 1Gi | 512Mi - 1Gi | 2Gi - 4Gi |

### CPU Allocations

| Component | values.yaml | values-local.yaml | values-dev.yaml | values-prod.yaml |
|-----------|-------------|-------------------|-----------------|------------------|
| MinIO | 250m - 1000m | 100m - 500m | 100m - 500m | 1000m - 2000m |
| PostgreSQL | 250m - 1000m | 100m - 500m | 100m - 500m | 1000m - 2000m |
| Trino | 500m - 2000m | 250m - 1000m | 250m - 1000m | 4000m - 8000m |
| Spark Master | 500m - 1000m | 250m - 500m | 250m - 500m | 2000m - 4000m |
| Spark Worker | 500m - 1000m | 250m - 500m | 250m - 500m | 4000m - 8000m |
| Airflow | 500m - 1000m | 250m - 500m | 250m - 500m | 1000m - 2000m |

### Replica Counts

| Component | values.yaml | values-local.yaml | values-dev.yaml | values-prod.yaml |
|-----------|-------------|-------------------|-----------------|------------------|
| MinIO | 1 | 1 | 1 | 3 (HA) |
| PostgreSQL | 1 | 1 | 1 | 1 |
| Trino | 1 | 1 | 1 | 3 |
| Spark Master | 1 | 1 | 1 | 2 (HA) |
| Spark Worker | 2 | 1 | 1 | 5 |
| Airflow | 1 | 1 | 1 | 2 (HA) |

### Storage Configuration

| Component | values.yaml | values-local.yaml | values-dev.yaml | values-prod.yaml |
|-----------|-------------|-------------------|-----------------|------------------|
| MinIO PVC | 10Gi, default SC | 5Gi, default SC | Disabled (emptyDir) | 100Gi, fast-ssd |
| PostgreSQL PVC | 5Gi, default SC | 2Gi, default SC | Disabled (emptyDir) | 50Gi, fast-ssd |
| Airflow Logs | 5Gi, default SC | 2Gi, default SC | Disabled (emptyDir) | 20Gi, fast-ssd |
| Airflow Plugins | 1Gi, default SC | 500Mi, default SC | Disabled (emptyDir) | 5Gi, fast-ssd |
| Jupyter | 5Gi, default SC | 2Gi, default SC | Disabled | 10Gi, fast-ssd |
| Marquez DB | 5Gi, default SC | 2Gi, default SC | Disabled | 20Gi, fast-ssd |

### Feature Toggles

| Feature | values.yaml | values-local.yaml | values-dev.yaml | values-prod.yaml |
|---------|-------------|-------------------|-----------------|------------------|
| Persistence | Enabled | Enabled | Disabled | Enabled |
| Metrics | Enabled | Enabled | Disabled | Enabled |
| Jupyter | Enabled | Enabled | Disabled | Enabled |
| Great Expectations | Enabled | Enabled | Disabled | Enabled |
| Marquez | Enabled | Enabled | Optional | Enabled |
| Tokern | Enabled | Enabled | Optional | Enabled |
| ServiceMonitor | Disabled | Enabled | Disabled | Enabled |
| Ingress | Disabled | Disabled | Disabled | Enabled |

## Recommendations

### Choose `values-local.yaml` if:
- ✅ Running on your laptop/workstation
- ✅ Using kind, k3d, Docker Desktop, or Minikube
- ✅ Need persistent storage for development work
- ✅ Want to test with realistic data that persists between restarts
- ✅ Have 8GB+ RAM available for Docker/Kubernetes

### Choose `values-dev.yaml` if:
- ✅ Deploying to a shared development cluster
- ✅ Running CI/CD tests that don't need persistence
- ✅ Want fast teardown and recreation
- ✅ Testing deployment scripts and configurations
- ✅ Need minimal resource footprint

### Choose `values-prod.yaml` if:
- ✅ Deploying to production environment
- ✅ Need high availability and redundancy
- ✅ Have dedicated infrastructure with SSDs
- ✅ Require maximum performance
- ✅ Need full monitoring and observability

### Choose `values.yaml` if:
- ✅ Need a balanced starting point for customization
- ✅ Deploying to a staging environment
- ✅ Want middle-ground resource allocation
- ✅ Testing before moving to production

## Customization

You can combine multiple values files or override specific values:

```bash
# Base + local customizations
helm install datalake . \
  --values values-local.yaml \
  --set spark.worker.replicaCount=2 \
  --set minio.persistence.size=10Gi

# Base + production + custom overrides
helm install datalake . \
  --values values-prod.yaml \
  --values custom-values.yaml

# Disable specific components
helm install datalake . \
  --values values-local.yaml \
  --set jupyter.enabled=false \
  --set marquez.enabled=false
```

## Storage Class Notes

### Local Clusters
- **kind**: Uses `local-path` provisioner (default)
- **k3d**: Uses `local-path` provisioner (default)
- **Docker Desktop**: Uses `hostpath` provisioner (default)
- **Minikube**: Uses `standard` provisioner (default)

All local values use empty string `""` for `storageClass`, which automatically uses the cluster's default StorageClass.

### Production Clusters
- **AWS EKS**: Use `gp3` or `io2` for SSD storage
- **GCP GKE**: Use `pd-ssd` or `pd-balanced`
- **Azure AKS**: Use `managed-premium` for SSD storage
- **On-Premise**: Create custom StorageClass for your storage backend

## Environment Variables Override

You can also override values using environment-specific secrets or ConfigMaps:

```bash
# Create secrets for sensitive data
kubectl create secret generic datalake-secrets \
  --from-literal=minio-root-password='prod-secure-password' \
  --from-literal=postgres-password='prod-db-password' \
  -n datalake

# Reference in values file or override
helm install datalake . \
  --values values-prod.yaml \
  --set minio.rootPassword='${MINIO_PASSWORD}' \
  --set postgres.password='${POSTGRES_PASSWORD}'
```

## Resource Calculation

### Minimum Node Requirements

**Local (single node):**
- CPU: 4 cores minimum, 8 cores recommended
- Memory: 8GB minimum, 16GB recommended
- Disk: 50GB minimum, 100GB recommended

**Development (can be single or multi-node):**
- CPU: 4 cores minimum
- Memory: 8GB minimum
- Disk: 50GB minimum

**Production (multi-node):**
- CPU: 16+ cores per node, 3+ nodes
- Memory: 32GB+ per node
- Disk: 500GB+ SSD storage, preferably with CSI driver

## Monitoring Resource Usage

Check actual resource usage:

```bash
# Node resources
kubectl top nodes

# Pod resources in namespace
kubectl top pods -n datalake

# Describe node to see allocatable resources
kubectl describe node <node-name>
```

## Further Reading

- [LOCAL_DEPLOYMENT.md](LOCAL_DEPLOYMENT.md) - Detailed local deployment guide
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [README.md](README.md) - Full documentation

# Local Cluster Configuration Summary

This directory contains comprehensive configuration files for deploying the EnginEdge Datalake on local Kubernetes clusters.

## Files Created

### 1. `values-local.yaml`
Optimized Helm values for local Kubernetes clusters (kind, k3d, Docker Desktop, Minikube).

**Key Features:**
- Reduced resource allocations (256Mi-1Gi memory, 100m-500m CPU)
- Single replica for all services
- Smaller PVC sizes (2-5Gi)
- Uses default StorageClass automatically
- All services enabled with persistent storage
- Metrics and monitoring enabled

### 2. `storageclass-local.yaml`
StorageClass definitions for various local cluster types.

**Includes:**
- `local-path` - For kind and k3d clusters
- `hostpath` - For Docker Desktop
- `standard` - For Minikube
- `local-storage` - For manual PV provisioning
- `fast-ssd` - Template for production-like testing

### 3. `deploy-local.ps1`
PowerShell automation script for local deployment.

**Features:**
- Automatic cluster detection and validation
- StorageClass auto-creation if missing
- Minimal installation mode (core services only)
- Disable persistence option for ephemeral testing
- Pod readiness monitoring
- Comprehensive access information display

**Usage Examples:**
```powershell
# Default installation
.\deploy-local.ps1

# Minimal (core services only)
.\deploy-local.ps1 -Minimal

# Without persistence
.\deploy-local.ps1 -NoPersistence

# Wait for all pods to be ready
.\deploy-local.ps1 -Wait -Timeout 15m

# Dry run
.\deploy-local.ps1 -DryRun
```

### 4. `LOCAL_DEPLOYMENT.md`
Comprehensive deployment guide for local clusters.

**Covers:**
- Prerequisites and cluster setup
- Quick start instructions
- Storage configuration options
- Accessing services via port-forward
- Cluster-specific notes (kind, k3d, Docker Desktop, Minikube)
- Troubleshooting common issues
- Resource optimization tips
- Monitoring setup (optional Prometheus)
- Cleanup procedures

### 5. `VALUES_COMPARISON.md`
Side-by-side comparison of all values files.

**Compares:**
- Resource allocations (memory, CPU)
- Replica counts
- Storage configurations
- Feature toggles
- Recommendations for each environment
- Customization examples

## Deployment Workflow

### Option 1: Automated Deployment (Recommended)

```powershell
# Navigate to helm chart directory
cd helm/datalake

# Run deployment script
.\deploy-local.ps1

# Access services using the displayed port-forward commands
```

### Option 2: Manual Deployment

```bash
# Check cluster
kubectl cluster-info

# Apply StorageClass if needed
kubectl apply -f storageclass-local.yaml

# Create namespace
kubectl create namespace datalake

# Install with Helm
helm install datalake . \
  --namespace datalake \
  --values values-local.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app=enginedge -n datalake --timeout=10m

# Port-forward to access services
kubectl port-forward -n datalake svc/minio 9001:9001
```

### Option 3: Minimal Installation

```powershell
# Core services only (MinIO, PostgreSQL, Trino, Spark, Airflow)
.\deploy-local.ps1 -Minimal

# Or with Helm
helm install datalake . \
  --namespace datalake \
  --values values-local.yaml \
  --set jupyter.enabled=false \
  --set greatExpectations.enabled=false \
  --set marquez.enabled=false \
  --set tokern.enabled=false
```

### Option 4: Ephemeral Testing

```powershell
# No persistence, fast teardown
.\deploy-local.ps1 -NoPersistence

# Or with Helm
helm install datalake . \
  --namespace datalake \
  --values values-local.yaml \
  --set minio.persistence.enabled=false \
  --set postgres.persistence.enabled=false \
  --set airflow.persistence.logs.enabled=false \
  --set airflow.persistence.plugins.enabled=false
```

## Resource Requirements

### Minimum System Requirements
- **CPU**: 4 cores
- **Memory**: 8GB RAM
- **Disk**: 50GB available space
- **Network**: Internet connection for image pulls

### Recommended System Requirements
- **CPU**: 8 cores
- **Memory**: 16GB RAM
- **Disk**: 100GB available space (SSD preferred)
- **Network**: High-speed internet for faster image pulls

### Actual Resource Usage (Local Configuration)

| Component | Memory Request | Memory Limit | CPU Request | CPU Limit | Storage |
|-----------|----------------|--------------|-------------|-----------|---------|
| MinIO | 256Mi | 1Gi | 100m | 500m | 5Gi |
| PostgreSQL | 128Mi | 512Mi | 100m | 500m | 2Gi |
| Trino | 1Gi | 2Gi | 250m | 1000m | - |
| Spark Master | 512Mi | 1Gi | 250m | 500m | - |
| Spark Worker | 512Mi | 1Gi | 250m | 500m | - |
| Airflow | 512Mi | 1Gi | 250m | 500m | 2.5Gi |
| Jupyter | 256Mi | 1Gi | 100m | 500m | 2Gi |
| Marquez API | 256Mi | 512Mi | 100m | 500m | - |
| Marquez Web | 128Mi | 256Mi | 100m | 250m | - |
| Marquez DB | - | - | - | - | 2Gi |
| **Total** | **~3.5Gi** | **~10Gi** | **~1.5 cores** | **~5 cores** | **~15Gi** |

## Storage Class Strategy

The local values file uses an empty string `""` for `storageClass`, which means:

1. **Automatic Detection**: Uses the cluster's default StorageClass
2. **No Manual Configuration**: Works out-of-the-box on most local clusters
3. **Cluster-Specific**: Adapts to kind (local-path), k3d (local-path), Docker Desktop (hostpath), or Minikube (standard)

If your cluster doesn't have a default StorageClass, the `deploy-local.ps1` script automatically creates one.

## Service Access Patterns

### Port-Forward (Recommended for Local)
- Secure, encrypted tunnel
- No external exposure
- No ingress controller needed
- Easy to manage

```bash
# Single service
kubectl port-forward -n datalake svc/airflow 8080:8080

# Multiple terminals for multiple services
```

### NodePort (Alternative)
- Exposes service on node's IP
- Requires external IP access
- Good for sharing with team on same network

```bash
helm upgrade datalake . \
  --values values-local.yaml \
  --set airflow.service.type=NodePort
```

### Ingress (Not Recommended for Local)
- Requires ingress controller
- Adds complexity
- Better suited for remote clusters

## Monitoring Integration

### With Prometheus/Grafana

```bash
# Install Prometheus stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Deploy datalake with ServiceMonitor enabled
.\deploy-local.ps1

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Login: admin / prom-operator
```

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| Pods stuck in Pending | Check PVC status: `kubectl get pvc -n datalake` |
| ImagePullBackOff | Check internet connectivity and image names |
| Out of memory | Reduce replicas or resource limits |
| StorageClass not found | Run `kubectl apply -f storageclass-local.yaml` |
| PVC not binding | Check StorageClass has `volumeBindingMode: WaitForFirstConsumer` |
| Cannot access services | Use `kubectl port-forward` instead of direct access |

## Cleanup

### Uninstall but keep data
```bash
helm uninstall datalake -n datalake
# PVCs remain intact
```

### Complete cleanup
```bash
helm uninstall datalake -n datalake
kubectl delete pvc -n datalake --all
kubectl delete namespace datalake
```

### Delete cluster
```bash
# kind
kind delete cluster

# k3d
k3d cluster delete datalake

# Minikube
minikube delete
```

## Next Steps

1. **Deploy**: Choose your deployment method and execute
2. **Verify**: Check all pods are running
3. **Access**: Use port-forward to access services
4. **Explore**: Try the example notebooks and DAGs
5. **Monitor**: Set up Prometheus/Grafana if needed
6. **Customize**: Adjust resources based on your machine

## Additional Resources

- [LOCAL_DEPLOYMENT.md](LOCAL_DEPLOYMENT.md) - Detailed deployment guide
- [VALUES_COMPARISON.md](VALUES_COMPARISON.md) - Compare all values files
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [README.md](README.md) - Main documentation
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - Architecture details

## Support

For issues or questions:
1. Check [LOCAL_DEPLOYMENT.md](LOCAL_DEPLOYMENT.md) troubleshooting section
2. Review [VALUES_COMPARISON.md](VALUES_COMPARISON.md) for configuration options
3. Check pod logs: `kubectl logs -n datalake <pod-name>`
4. Check events: `kubectl get events -n datalake --sort-by='.lastTimestamp'`

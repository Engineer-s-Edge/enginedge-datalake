# Quick Start Guide - EnginEdge Data Lake Helm Chart

This guide will help you quickly deploy the EnginEdge Data Lake on Kubernetes using Helm.

## Prerequisites

1. **Kubernetes Cluster** (one of):
   - Docker Desktop with Kubernetes enabled
   - Kind: `kind create cluster --config kind-config.yaml`
   - Minikube: `minikube start`
   - Cloud Kubernetes (GKE, EKS, AKS)

2. **Helm 3.x** installed
   ```powershell
   # Windows (Chocolatey)
   choco install kubernetes-helm
   
   # Windows (Scoop)
   scoop install helm
   ```

3. **kubectl** configured to access your cluster
   ```powershell
   kubectl cluster-info
   ```

## Installation

### Option 1: Using the deployment script (Recommended)

```powershell
# Navigate to the helm/datalake directory
cd helm/datalake

# Deploy with default values
.\deploy.ps1

# Deploy with custom values
.\deploy.ps1 -ValuesFile values-dev.yaml

# Dry run to see what will be deployed
.\deploy.ps1 -DryRun

# Upgrade existing deployment
.\deploy.ps1 -Upgrade
```

### Option 2: Using Helm directly

```powershell
# Create namespace
kubectl create namespace datalake

# Install the chart
helm install datalake ./helm/datalake -n datalake

# Install with development values
helm install datalake ./helm/datalake -n datalake -f ./helm/datalake/values-dev.yaml
```

## Verify Installation

```powershell
# Check all pods are running
kubectl get pods -n datalake

# Check services
kubectl get svc -n datalake

# View deployment notes
helm get notes datalake -n datalake
```

## Access Services

### Port Forward to Local Machine

```powershell
# Trino SQL Engine (in a new terminal)
kubectl port-forward -n datalake svc/trino 8080:8080
# Access at: http://localhost:8080

# Airflow (in a new terminal)
kubectl port-forward -n datalake svc/airflow 8082:8080
# Access at: http://localhost:8082
# Default credentials: admin/admin123

# Spark Master UI (in a new terminal)
kubectl port-forward -n datalake svc/spark-master 8083:8080
# Access at: http://localhost:8083

# MinIO Console (in a new terminal)
kubectl port-forward -n datalake svc/minio 9001:9001
# Access at: http://localhost:9001
# Default credentials: minioadmin/minioadmin123
```

## Quick Test

### Test Trino Connection

```powershell
# Install Trino CLI (optional)
# Download from: https://trino.io/docs/current/client/cli.html

# Connect to Trino
kubectl exec -n datalake -it deploy/datalake-trino -- trino

# Run a test query
trino> SHOW CATALOGS;
trino> SELECT * FROM system.runtime.nodes;
```

### Test MinIO

```powershell
# Access MinIO console at http://localhost:9001
# Create a test bucket
# Upload a test file
```

## Troubleshooting

### Pods not starting

```powershell
# Check pod status
kubectl get pods -n datalake

# Describe problematic pod
kubectl describe pod <pod-name> -n datalake

# View pod logs
kubectl logs -n datalake <pod-name>

# Check events
kubectl get events -n datalake --sort-by='.lastTimestamp'
```

### Storage issues

```powershell
# Check PVCs
kubectl get pvc -n datalake

# Describe PVC
kubectl describe pvc <pvc-name> -n datalake

# For development, you can disable persistence in values-dev.yaml
```

### Service connectivity issues

```powershell
# Test service DNS resolution
kubectl run -n datalake test-pod --image=busybox --rm -it -- nslookup postgres

# Test service connectivity
kubectl run -n datalake test-pod --image=busybox --rm -it -- nc -zv postgres 5432
```

## Customization

### Override specific values

```powershell
# Override via command line
helm install datalake ./helm/datalake -n datalake \
  --set minio.persistence.size=20Gi \
  --set spark.worker.replicaCount=3
```

### Create custom values file

```yaml
# my-values.yaml
spark:
  worker:
    replicaCount: 5
    resources:
      requests:
        memory: "4Gi"
        cpu: "2000m"

minio:
  persistence:
    size: 50Gi
```

```powershell
helm install datalake ./helm/datalake -n datalake -f my-values.yaml
```

## Upgrade

```powershell
# Upgrade to latest chart
helm upgrade datalake ./helm/datalake -n datalake

# Upgrade with new values
helm upgrade datalake ./helm/datalake -n datalake -f values-prod.yaml
```

## Uninstall

```powershell
# Uninstall the release
helm uninstall datalake -n datalake

# Delete namespace (this will delete all PVCs)
kubectl delete namespace datalake
```

## Next Steps

1. **Configure Data Sources**: Add your data sources to Trino catalogs
2. **Create Airflow DAGs**: Deploy workflow definitions
3. **Submit Spark Jobs**: Run data processing jobs
4. **Set up Monitoring**: Enable Prometheus/Grafana integration
5. **Configure Ingress**: Expose services externally (production)

## Common Scenarios

### Minimal Local Development

Use `values-dev.yaml` for minimal resources:
```powershell
helm install datalake ./helm/datalake -n datalake -f ./helm/datalake/values-dev.yaml
```

### Production Deployment

Use `values-prod.yaml` for production:
```powershell
helm install datalake ./helm/datalake -n datalake-prod -f ./helm/datalake/values-prod.yaml
```

### Enable Only Core Services

Create a minimal values file:
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

## Support

- Documentation: See `helm/datalake/README.md`
- Issues: https://github.com/Chris-Alexander-Pop/enginedge-datalake/issues
- Main README: `../../README.md`

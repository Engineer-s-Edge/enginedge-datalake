# Data Lake Helm Deployment

This directory contains Helm values files and deployment scripts for the EnginEdge Data Lake infrastructure components.

## Components

Currently, the following components are deployed via Helm:

- **PostgreSQL** - Database for Airflow and Hive Metastore (Bitnami chart)
- **MinIO** - S3-compatible object storage (Official MinIO chart)

The following components are still deployed using raw Kubernetes manifests in `../kubernetes/`:
- Spark (Master & Workers)
- Trino
- Apache Airflow
- Jupyter Lab
- Hive Metastore
- Great Expectations
- Marquez (Data Lineage)

## Prerequisites

1. **Kubernetes cluster** - Running and accessible via `kubectl`
   - Kind: `kind create cluster`
   - Docker Desktop: Enable Kubernetes in settings
   - Minikube: `minikube start`

2. **Helm 3** - Package manager for Kubernetes
   ```powershell
   # Windows (Chocolatey)
   choco install kubernetes-helm
   
   # Windows (winget)
   winget install Helm.Helm
   ```

3. **kubectl** - Kubernetes CLI tool
   ```powershell
   # Windows (Chocolatey)
   choco install kubernetes-cli
   ```

## Quick Start

### Deploy All Components

Run the PowerShell deployment script:

```powershell
# From the helm directory
.\deploy-datalake.ps1

# Specify custom namespace
.\deploy-datalake.ps1 -Namespace production

# Skip Helm repo update
.\deploy-datalake.ps1 -SkipRepoUpdate
```

### Manual Deployment

If you prefer to run commands manually:

```powershell
# Add Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add minio https://charts.min.io/
helm repo update

# Create namespace
kubectl create namespace datalake

# Deploy PostgreSQL
helm upgrade --install postgres bitnami/postgresql \
  --namespace datalake \
  --values postgres-values.yaml \
  --wait

# Deploy MinIO
helm upgrade --install minio minio/minio \
  --namespace datalake \
  --values minio-values.yaml \
  --wait

# Deploy other components (using raw manifests)
kubectl apply -f ../kubernetes/secrets.yml -n datalake
kubectl apply -f ../kubernetes/ -n datalake
```

## Configuration

### PostgreSQL (`postgres-values.yaml`)

Key configurations:
- Database: `airflow`
- Username: `airflow`
- Password: `airflow` (change for production!)
- Storage: 10Gi PVC
- Creates `metastore` database for Hive

To customize, edit `postgres-values.yaml` before deployment.

### MinIO (`minio-values.yaml`)

Key configurations:
- Root User: `minioadmin`
- Root Password: `minioadmin123` (change for production!)
- Storage: 10Gi PVC
- Mode: Standalone
- Ports: 9000 (API), 9001 (Console)

To customize, edit `minio-values.yaml` before deployment.

## Accessing Services

### Port Forwarding (Development)

```powershell
# MinIO Console
kubectl port-forward -n datalake svc/minio 9000:9000 9001:9001

# PostgreSQL
kubectl port-forward -n datalake svc/postgres-postgresql 5432:5432

# Spark Master (from raw manifest)
kubectl port-forward -n datalake svc/spark-master 8080:8080

# Airflow (from raw manifest)
kubectl port-forward -n datalake svc/airflow 8082:8080

# Trino (from raw manifest)
kubectl port-forward -n datalake svc/trino 8090:8080

# Jupyter (from raw manifest)
kubectl port-forward -n datalake svc/jupyter 8888:8888
```

Then access:
- MinIO Console: http://localhost:9001
- Airflow: http://localhost:8082
- Spark: http://localhost:8080
- Trino: http://localhost:8090
- Jupyter: http://localhost:8888

### Ingress (Production)

For production deployments, configure ingress in the values files:

```yaml
# In minio-values.yaml
ingress:
  enabled: true
  hosts:
    - minio.yourdomain.com
  tls:
    - secretName: minio-tls
      hosts:
        - minio.yourdomain.com
```

## Upgrading

To upgrade an existing deployment:

```powershell
# Upgrade PostgreSQL
helm upgrade postgres bitnami/postgresql \
  --namespace datalake \
  --values postgres-values.yaml

# Upgrade MinIO
helm upgrade minio minio/minio \
  --namespace datalake \
  --values minio-values.yaml
```

## Uninstalling

To remove the Helm releases:

```powershell
# Uninstall PostgreSQL
helm uninstall postgres -n datalake

# Uninstall MinIO
helm uninstall minio -n datalake

# Delete namespace (removes all resources)
kubectl delete namespace datalake
```

## Troubleshooting

### Check deployment status
```powershell
kubectl get pods -n datalake
kubectl get svc -n datalake
kubectl get pvc -n datalake
```

### View logs
```powershell
kubectl logs -n datalake deployment/postgres-postgresql
kubectl logs -n datalake deployment/minio
```

### Check Helm releases
```powershell
helm list -n datalake
helm status postgres -n datalake
helm status minio -n datalake
```

### Get values
```powershell
helm get values postgres -n datalake
helm get values minio -n datalake
```

## Future Improvements

- [ ] Create custom Helm chart for Spark cluster
- [ ] Create custom Helm chart for Trino
- [ ] Create custom Helm chart for Airflow (or use official chart)
- [ ] Create custom Helm chart for Jupyter Lab
- [ ] Add Helm chart for Hive Metastore
- [ ] Consolidate all components into a single umbrella chart
- [ ] Add support for different environments (dev, staging, prod)
- [ ] Implement proper secrets management (e.g., Sealed Secrets, External Secrets Operator)

## References

- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [MinIO Helm Chart](https://github.com/minio/minio/tree/master/helm/minio)
- [Helm Documentation](https://helm.sh/docs/)

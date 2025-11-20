# Storage and Secrets Configuration Guide

This guide covers the configuration of Persistent Volume Claims (PVCs), StorageClasses, and Kubernetes Secrets for the EnginEdge Datalake.

## Table of Contents

1. [Overview](#overview)
2. [StorageClasses](#storageclasses)
3. [Persistent Volume Claims](#persistent-volume-claims)
4. [Kubernetes Secrets](#kubernetes-secrets)
5. [Deployment Methods](#deployment-methods)
6. [Best Practices](#best-practices)
7. [Cloud Provider Examples](#cloud-provider-examples)

## Overview

The datalake requires persistent storage for:
- **PostgreSQL**: Database storage for Airflow metadata and Hive Metastore
- **MinIO**: Object storage buckets for data lake (Bronze, Silver, Gold layers)
- **Airflow**: Logs and plugins

Security credentials are managed through Kubernetes Secrets for:
- Database credentials (PostgreSQL, Hive Metastore)
- Object storage keys (MinIO root user/password)
- Application credentials (Airflow, Trino, Jupyter)

## StorageClasses

### Available StorageClasses

The datalake provides multiple StorageClass options optimized for different workloads:

| StorageClass | Use Case | Performance | Cost | Recommended For |
|--------------|----------|-------------|------|-----------------|
| `datalake-standard` | General purpose | Medium | Medium | Development, Testing |
| `datalake-fast` | High IOPS workloads | High | High | PostgreSQL, Gold layer |
| `datalake-bulk` | Large datasets | Medium | Low | MinIO buckets, Bronze/Silver layers |
| `datalake-local` | Local development | Medium | N/A | kind, k3d, Docker Desktop |
| `datalake-shared` | Multi-pod access | Medium | Medium | Airflow DAGs (ReadWriteMany) |

### Creating StorageClasses

#### Method 1: Standalone Manifests

```bash
# Apply StorageClasses directly
kubectl apply -f kubernetes/storageclass.yml
```

#### Method 2: Via Helm

Enable StorageClass creation in `values.yaml`:

```yaml
storageClass:
  enabled: true
  standard:
    provisioner: kubernetes.io/gce-pd  # For GCP
    parameters:
      type: pd-standard
```

Then deploy:

```bash
helm upgrade --install datalake ./helm/datalake -f values-custom.yaml
```

### Cloud Provider Provisioners

Update the `provisioner` field based on your cloud provider:

- **AWS**: `kubernetes.io/aws-ebs` or `ebs.csi.aws.com`
- **GCP**: `kubernetes.io/gce-pd` or `pd.csi.storage.gke.io`
- **Azure**: `kubernetes.io/azure-disk` or `disk.csi.azure.com`
- **Local (kind/k3d)**: `rancher.io/local-path`

## Persistent Volume Claims

### PostgreSQL PVC

**Size**: 5-10Gi (adjustable based on metadata volume)  
**StorageClass**: `datalake-fast` (recommended for database performance)  
**Access Mode**: ReadWriteOnce

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: datalake
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: datalake-fast
  resources:
    requests:
      storage: 10Gi
```

### MinIO PVCs

#### Primary Storage
**Size**: 50Gi+  
**StorageClass**: `datalake-bulk`  
**Access Mode**: ReadWriteOnce

#### Data Lake Layers

The datalake implements a medallion architecture with separate storage:

1. **Bronze Layer** (Raw Data)
   - Size: 50Gi
   - StorageClass: `datalake-bulk`
   - Purpose: Raw ingested data

2. **Silver Layer** (Cleaned Data)
   - Size: 30Gi
   - StorageClass: `datalake-bulk`
   - Purpose: Cleaned and transformed data

3. **Gold Layer** (Curated Data)
   - Size: 20Gi
   - StorageClass: `datalake-fast`
   - Purpose: Business-ready, frequently accessed data

### Airflow PVCs

#### Logs PVC
**Size**: 10Gi  
**StorageClass**: `datalake-standard`  
**Access Mode**: ReadWriteOnce

#### DAGs PVC (Optional)
**Size**: 5Gi  
**StorageClass**: `datalake-shared`  
**Access Mode**: ReadWriteMany (for multi-pod access)

### Applying PVCs

#### Method 1: Standalone Manifests

```bash
# Apply all PVCs
kubectl apply -f kubernetes/pvcs.yml

# Verify
kubectl get pvc -n datalake
```

#### Method 2: Via Helm

PVCs are automatically created when deploying via Helm:

```bash
helm upgrade --install datalake ./helm/datalake
```

Configure in `values.yaml`:

```yaml
postgres:
  persistence:
    enabled: true
    storageClass: "datalake-fast"
    size: 10Gi

minio:
  persistence:
    enabled: true
    storageClass: "datalake-bulk"
    size: 50Gi
  lakehouse:
    enabled: true  # Enable separate lakehouse storage
    persistence:
      size: 100Gi
```

## Kubernetes Secrets

### Security Warning

⚠️ **IMPORTANT**: Never commit actual secrets to version control!

The repository includes `secrets.yml.example` as a template. Always:
1. Copy to `secrets.yml`
2. Update with real credentials
3. Apply to cluster
4. Keep `secrets.yml` out of git (it's in `.gitignore`)

### Available Secrets

| Secret Name | Contains | Used By |
|-------------|----------|---------|
| `datalake-secrets` | All service credentials | All components |
| `minio-secret` | MinIO credentials | MinIO, Trino, Spark, Hive |
| `postgres-secret` | PostgreSQL credentials | PostgreSQL, Airflow, Hive |
| `airflow-secret` | Airflow-specific config | Airflow |
| `trino-secret` | Trino catalog credentials | Trino |
| `hive-metastore-secret` | Hive Metastore config | Hive Metastore |
| `spark-secret` | Spark credentials | Spark |

### Creating Secrets

#### Method 1: From Example File

```bash
# Copy and edit
cp kubernetes/secrets.yml.example kubernetes/secrets.yml
nano kubernetes/secrets.yml  # Edit with actual credentials

# Apply
kubectl apply -f kubernetes/secrets.yml
```

#### Method 2: Imperatively

```bash
# Create PostgreSQL secret
kubectl create secret generic postgres-secret \
  --from-literal=username=airflow \
  --from-literal=password='YOUR_STRONG_PASSWORD' \
  --from-literal=database=airflow \
  -n datalake

# Create MinIO secret
kubectl create secret generic minio-secret \
  --from-literal=root-user=minioadmin \
  --from-literal=root-password='YOUR_STRONG_PASSWORD' \
  --from-literal=access-key=minioadmin \
  --from-literal=secret-key='YOUR_STRONG_PASSWORD' \
  -n datalake
```

#### Method 3: Via Helm

Secrets are automatically created from `values.yaml`:

```yaml
postgres:
  user: airflow
  password: "CHANGE_IN_PRODUCTION"
  database: airflow

minio:
  rootUser: minioadmin
  rootPassword: "CHANGE_IN_PRODUCTION"
```

### Generating Strong Credentials

```bash
# Generate random passwords
openssl rand -base64 32

# Generate Airflow Fernet key
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

# Generate UUID for secret keys
uuidgen
```

## Deployment Methods

### Option 1: Standalone Kubernetes Manifests

Best for: Direct Kubernetes deployments, GitOps workflows

```bash
# 1. Create namespace
kubectl create namespace datalake

# 2. Apply StorageClasses
kubectl apply -f kubernetes/storageclass.yml

# 3. Create secrets
cp kubernetes/secrets.yml.example kubernetes/secrets.yml
# Edit secrets.yml with actual credentials
kubectl apply -f kubernetes/secrets.yml

# 4. Apply PVCs
kubectl apply -f kubernetes/pvcs.yml

# 5. Deploy applications
kubectl apply -f kubernetes/postgres.yml
kubectl apply -f kubernetes/minio.yml
# ... other services
```

### Option 2: Helm Deployment

Best for: Parameterized deployments, multiple environments

```bash
# 1. Create custom values file
cp helm/datalake/values.yaml values-custom.yaml
# Edit values-custom.yaml

# 2. Deploy with Helm
helm upgrade --install datalake ./helm/datalake \
  -f values-custom.yaml \
  --namespace datalake \
  --create-namespace

# 3. Verify
kubectl get all,pvc,secret -n datalake
```

### Option 3: Local Development

For local clusters (kind, k3d, Docker Desktop):

```bash
# Use local values
helm upgrade --install datalake ./helm/datalake \
  -f helm/datalake/values-local.yaml \
  --namespace datalake \
  --create-namespace

# Or use the provided script
./helm/datalake/deploy-local.ps1 -Environment local
```

## Best Practices

### Storage

1. **Choose the Right StorageClass**
   - Use `fast` SSD storage for databases (PostgreSQL)
   - Use `bulk` storage for large datasets (MinIO buckets)
   - Use `shared` storage only when multiple pods need access

2. **Size Appropriately**
   - Start small and enable volume expansion
   - Monitor usage with Prometheus metrics
   - Plan for 30-50% growth headroom

3. **Implement Backup Strategies**
   - Use PVC snapshots (VolumeSnapshot CRD)
   - Regular database backups (pg_dump)
   - MinIO bucket versioning and replication

4. **Enable Volume Expansion**
   - Set `allowVolumeExpansion: true` in StorageClass
   - Use CSI drivers that support expansion

### Secrets

1. **Never Commit Secrets to Git**
   - Use `secrets.yml.example` as template
   - Keep actual `secrets.yml` in `.gitignore`

2. **Use Strong, Unique Passwords**
   - Generate cryptographically random passwords
   - Different password for each service
   - Minimum 32 characters for production

3. **Consider External Secret Management**
   - **Sealed Secrets**: Encrypt secrets for Git storage
   - **External Secrets Operator**: Sync from Vault, AWS Secrets Manager, etc.
   - **HashiCorp Vault**: Enterprise secret management
   - **Cloud Provider Solutions**: AWS Secrets Manager, GCP Secret Manager, Azure Key Vault

4. **Rotate Credentials Regularly**
   - Implement secret rotation policies
   - Update secrets without downtime (rolling updates)

5. **Use RBAC to Restrict Secret Access**
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     name: secret-reader
     namespace: datalake
   rules:
   - apiGroups: [""]
     resources: ["secrets"]
     verbs: ["get", "list"]
   ```

### Production Considerations

1. **High Availability**
   - Use replicated storage for critical data
   - Configure PostgreSQL with replication
   - Deploy MinIO in distributed mode

2. **Monitoring**
   - Monitor PVC usage with Prometheus
   - Set alerts for storage capacity thresholds
   - Track IOPS and throughput metrics

3. **Disaster Recovery**
   - Document backup and restore procedures
   - Test disaster recovery regularly
   - Keep backups in separate availability zones

## Cloud Provider Examples

### AWS (EKS)

```yaml
storageClass:
  enabled: true
  fast:
    name: datalake-fast
    provisioner: ebs.csi.aws.com
    parameters:
      type: gp3
      iops: "3000"
      throughput: "125"
  bulk:
    name: datalake-bulk
    provisioner: ebs.csi.aws.com
    parameters:
      type: sc1  # Cold HDD for bulk storage
```

### GCP (GKE)

```yaml
storageClass:
  enabled: true
  fast:
    name: datalake-fast
    provisioner: pd.csi.storage.gke.io
    parameters:
      type: pd-ssd
      replication-type: regional-pd
  bulk:
    name: datalake-bulk
    provisioner: pd.csi.storage.gke.io
    parameters:
      type: pd-standard
```

### Azure (AKS)

```yaml
storageClass:
  enabled: true
  fast:
    name: datalake-fast
    provisioner: disk.csi.azure.com
    parameters:
      skuName: Premium_LRS
      kind: managed
  bulk:
    name: datalake-bulk
    provisioner: disk.csi.azure.com
    parameters:
      skuName: Standard_LRS
```

### Local Development (kind)

```yaml
storageClass:
  enabled: true
  standard:
    name: datalake-standard
    provisioner: rancher.io/local-path
    volumeBindingMode: WaitForFirstConsumer
```

## Verification

### Check PVCs

```bash
# List all PVCs
kubectl get pvc -n datalake

# Check PVC details
kubectl describe pvc postgres-pvc -n datalake

# Check bound PV
kubectl get pv
```

### Check Secrets

```bash
# List secrets
kubectl get secrets -n datalake

# View secret (base64 encoded)
kubectl get secret minio-secret -n datalake -o yaml

# Decode secret value
kubectl get secret postgres-secret -n datalake -o jsonpath='{.data.password}' | base64 -d
```

### Verify Storage Usage

```bash
# Check pod volume mounts
kubectl describe pod postgres-0 -n datalake

# Check disk usage in pod
kubectl exec -it postgres-0 -n datalake -- df -h
```

## Troubleshooting

### PVC Stuck in Pending

```bash
# Check PVC events
kubectl describe pvc <pvc-name> -n datalake

# Common issues:
# - No StorageClass available
# - Insufficient storage capacity
# - Provisioner not configured
```

### Secret Not Found

```bash
# Verify secret exists
kubectl get secret <secret-name> -n datalake

# Check pod secret mounts
kubectl describe pod <pod-name> -n datalake
```

### Permission Denied in Pods

```bash
# Check volume permissions
kubectl exec -it <pod-name> -n datalake -- ls -la /data

# Fix with initContainer if needed (see Helm templates)
```

## Additional Resources

- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [MinIO Distributed Mode](https://min.io/docs/minio/kubernetes/upstream/)
- [PostgreSQL on Kubernetes](https://www.postgresql.org/docs/current/high-availability.html)

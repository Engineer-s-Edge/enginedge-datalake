# Quick Start: Storage and Secrets Setup

This guide provides a fast-track to setting up storage and secrets for the EnginEdge Datalake.

## 🚀 Quick Start (5 Minutes)

### Step 1: Clone and Navigate (30 seconds)

```bash
cd enginedge-splitrepos/enginedge-datalake
```

### Step 2: Apply StorageClasses (30 seconds)

```bash
# For local development (kind, k3d, Docker Desktop)
kubectl apply -f kubernetes/storageclass.yml

# For cloud deployments, edit first:
# nano kubernetes/storageclass.yml  # Update provisioner fields
```

### Step 3: Create Secrets (2 minutes)

```bash
# Copy the template
cp kubernetes/secrets.yml.example kubernetes/secrets.yml

# Generate strong passwords (Linux/Mac)
openssl rand -base64 32  # Run multiple times for different passwords

# Edit with your credentials
nano kubernetes/secrets.yml  # or use your preferred editor

# Apply secrets
kubectl create namespace datalake  # Create namespace first
kubectl apply -f kubernetes/secrets.yml
```

### Step 4: Apply PVCs (30 seconds)

```bash
# Apply all PVCs
kubectl apply -f kubernetes/pvcs.yml

# Verify
kubectl get pvc -n datalake
```

### Step 5: Deploy Services (1 minute)

```bash
# Deploy all services
kubectl apply -f kubernetes/

# Watch deployment
kubectl get pods -n datalake -w
```

## ✅ Verification

```bash
# Check everything
kubectl get all,pvc,secret -n datalake

# Expected output:
# - 5+ pods running
# - 8+ PVCs bound
# - 7+ secrets created
```

## 🎯 What You Get

### Storage

- **PostgreSQL**: 10Gi fast SSD storage
- **MinIO**: 50Gi+ bulk storage with medallion architecture
- **Airflow**: 10Gi logs + 5Gi plugins

### Secrets

- Database credentials (PostgreSQL, Hive)
- Object storage keys (MinIO)
- Application passwords (Airflow, Trino, Jupyter)

## 🔧 Common Configurations

### Adjust Storage Sizes

Edit `kubernetes/pvcs.yml`:

```yaml
# Increase PostgreSQL storage
spec:
  resources:
    requests:
      storage: 20Gi  # Change from 10Gi
```

### Change StorageClass

```yaml
# Use different StorageClass
spec:
  storageClassName: datalake-standard  # Change from datalake-fast
```

### Update Passwords

Edit `kubernetes/secrets.yml`:

```yaml
stringData:
  POSTGRES_PASSWORD: "your-strong-password-here"
  MINIO_ROOT_PASSWORD: "your-minio-password-here"
```

## 🐛 Troubleshooting

### PVCs Stuck in Pending

```bash
# Check StorageClass exists
kubectl get storageclass

# Check PVC details
kubectl describe pvc postgres-pvc -n datalake

# Common fix: Create or specify default StorageClass
kubectl patch storageclass datalake-standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Pods Can't Mount Volumes

```bash
# Check pod events
kubectl describe pod <pod-name> -n datalake

# Check PVC binding
kubectl get pvc -n datalake

# Ensure PVC is Bound before pod starts
```

### Secret Not Found Errors

```bash
# Verify secrets exist
kubectl get secrets -n datalake

# Check secret in correct namespace
kubectl get secrets --all-namespaces | grep datalake

# Recreate if needed
kubectl delete secret datalake-secrets -n datalake
kubectl apply -f kubernetes/secrets.yml
```

## 📚 Next Steps

1. **Configure Ingress**: See `kubernetes/INGRESS_README.md`
2. **Enable Monitoring**: See `docs/MONITORING.md`
3. **Setup Data Lineage**: See `docs/DATA_LINEAGE.md`
4. **Configure Backups**: See full guide

## 🔗 Additional Resources

- [Complete Storage & Secrets Guide](STORAGE_AND_SECRETS.md) - Full documentation
- [Implementation Summary](STORAGE_SECRETS_IMPLEMENTATION.md) - Technical details
- [Kubernetes Directory README](../kubernetes/README.md) - Service access info

## 💡 Pro Tips

1. **Use Helm for Multiple Environments**
   ```bash
   helm upgrade --install datalake ./helm/datalake \
     -f helm/datalake/values-dev.yaml \
     --namespace datalake
   ```

2. **Enable Volume Expansion**
   ```yaml
   # In StorageClass
   allowVolumeExpansion: true
   ```

3. **Use Separate Namespaces per Environment**
   ```bash
   kubectl create namespace datalake-dev
   kubectl create namespace datalake-prod
   ```

4. **Monitor Storage Usage**
   ```bash
   # Install metrics-server first
   kubectl top pods -n datalake
   kubectl exec -it postgres-0 -n datalake -- df -h
   ```

5. **Generate Airflow Fernet Key**
   ```bash
   python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
   ```

## 🔒 Security Checklist

- [ ] Changed all default passwords
- [ ] Generated unique Fernet key for Airflow
- [ ] Secrets file not committed to git
- [ ] RBAC configured for secret access
- [ ] Using strong passwords (32+ characters)
- [ ] Different password per service
- [ ] Documented password storage location

## 📞 Support

Issues? Check:
1. [Troubleshooting Section](#troubleshooting)
2. [Full Documentation](STORAGE_AND_SECRETS.md#troubleshooting)
3. GitHub Issues
4. Team Slack Channel

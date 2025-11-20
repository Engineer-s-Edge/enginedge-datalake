# EnginEdge Data Lake on Kubernetes

This directory contains the Kubernetes manifests for deploying the EnginEdge Data Lake.

## Quick Links

- 📚 **[Complete Storage & Secrets Guide](../docs/STORAGE_AND_SECRETS.md)** - Comprehensive documentation
- 🔐 **[secrets.yml.example](secrets.yml.example)** - Secret template with all credentials
- 💾 **[storageclass.yml](storageclass.yml)** - StorageClass definitions for different environments
- 📦 **[pvcs.yml](pvcs.yml)** - PersistentVolumeClaims for all services

## Deployment

### 1. Configure StorageClasses

Apply the appropriate StorageClasses for your environment:

```bash
# Apply all StorageClasses
kubectl apply -f kubernetes/storageclass.yml

# Or edit to match your cloud provider first
nano kubernetes/storageclass.yml
```

See [Cloud Provider Examples](../docs/STORAGE_AND_SECRETS.md#cloud-provider-examples) for AWS, GCP, Azure configurations.

### 2. Create Persistent Volume Claims

Apply PVCs for PostgreSQL, MinIO, and Airflow:

```bash
# Review and adjust sizes if needed
kubectl apply -f kubernetes/pvcs.yml

# Verify PVCs are bound
kubectl get pvc -n datalake
```

### 3. Create Secrets

Create secrets from the example template:

```bash
# Copy the template
cp kubernetes/secrets.yml.example kubernetes/secrets.yml

# IMPORTANT: Edit with your actual credentials
nano kubernetes/secrets.yml

# Apply secrets
kubectl apply -f kubernetes/secrets.yml
```

⚠️ **Security Note**: Never commit `secrets.yml` to version control. Use strong, unique passwords for production.

### 4. Deploy Services

Deploy all data lake services:

```bash
# Create namespace
kubectl create namespace datalake

# Deploy all services
kubectl apply -f kubernetes/

# Or deploy individually
kubectl apply -f kubernetes/postgres.yml
kubectl apply -f kubernetes/minio.yml
kubectl apply -f kubernetes/hive-metastore.yml
kubectl apply -f kubernetes/trino.yml
kubectl apply -f kubernetes/spark.yml
kubectl apply -f kubernetes/airflow.yml
```

This will create all the necessary Deployments, Services, PersistentVolumeClaims, and Secrets.

**Note on the Observability Service:** The `datalake-observability` service is deployed with a placeholder image. To use this service, you must build your own Docker image and update the `kubernetes/datalake-observability.yml` file with your image name.

## Accessing Services

### Option 1: Port Forwarding (Development)

You can access the services using `kubectl port-forward`:

*   **MinIO:** `kubectl port-forward svc/minio 9000:9000`
*   **PostgreSQL:** `kubectl port-forward svc/postgres 5432:5432`
*   **Spark Master:** `kubectl port-forward svc/spark-master 8080:8080`
*   **Trino:** `kubectl port-forward svc/trino 8090:8080`
*   **Airflow:** `kubectl port-forward svc/airflow 8082:8080`
*   **Jupyter:** `kubectl port-forward svc/jupyter 8888:8888`
*   **Great Expectations:** `kubectl port-forward svc/great-expectations 4000:8000`
*   **Marquez API:** `kubectl port-forward svc/marquez-api 5000:5000`
*   **Marquez Web:** `kubectl port-forward svc/marquez-web 3000:3000`
*   **Datalake Observability:** `kubectl port-forward svc/datalake-observability 3010:3010`

You can then access the services in your browser at the corresponding `localhost` ports.

### Option 2: Ingress with Authentication (Production)

For production deployments with proper authentication and SSL/TLS, use the Ingress configuration:

```bash
# Deploy Ingress with Basic Authentication
./kubernetes/deploy-ingress.sh --type basic

# Or deploy with OAuth2 (SSO) for enterprise use
./kubernetes/deploy-ingress.sh --type oauth2
```

**Features:**
- 🔐 Basic Authentication or OAuth2/SSO
- 🔒 SSL/TLS support with cert-manager
- 🛡️ Network policies for additional security
- ⚡ Rate limiting and IP whitelisting
- 📊 Security headers (HSTS, X-Frame-Options, etc.)

**Supported OAuth Providers:**
- Google Workspace
- GitHub
- Azure Active Directory
- Okta
- Keycloak
- Generic OIDC

**Quick Start:**
```bash
# 1. Install NGINX Ingress Controller (if not already installed)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# 2. Update /etc/hosts (for local testing)
echo "127.0.0.1 airflow.datalake.local trino.datalake.local" | sudo tee -a /etc/hosts

# 3. Deploy Ingress
./kubernetes/deploy-ingress.sh --type basic

# 4. Access UIs
# Airflow: http://airflow.datalake.local (default: admin/airflow123)
# Trino: http://trino.datalake.local (default: admin/trino123)
```

**Full Documentation:** See [INGRESS_README.md](INGRESS_README.md) for complete setup instructions, OAuth2 configuration, TLS setup, and troubleshooting.

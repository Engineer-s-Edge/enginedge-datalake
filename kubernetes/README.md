# EnginEdge Data Lake on Kubernetes

This directory contains the Kubernetes manifests for deploying the EnginEdge Data Lake.

## Deployment

### 1. Create Secrets

First, create a `secrets.yml` file from the example:

```bash
cp kubernetes/secrets.yml.example kubernetes/secrets.yml
```

Then, **review and update the `kubernetes/secrets.yml` file** with your own credentials. This file is ignored by git, so your secrets will not be committed to the repository.

### 2. Deploy the Data Lake

To deploy the data lake to your Kubernetes cluster, apply the manifests in this directory:

```bash
kubectl apply -f kubernetes/
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

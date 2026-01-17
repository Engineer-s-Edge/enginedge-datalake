# Ingress Configuration for Airflow and Trino

This directory contains Kubernetes Ingress configurations for securing access to Airflow and Trino UIs.

## 📁 Files

- **`ingress.yml`** - Basic authentication using htpasswd
- **`ingress-oauth2.yml`** - Enterprise OAuth2 authentication using OAuth2 Proxy
- **`ingress-rbac.yml`** - (Optional) Role-based access control configurations

## 🔐 Authentication Methods

### Method 1: Basic Authentication (Simple)

Best for: Development, testing, small teams

**File:** `ingress.yml`

#### Quick Setup

```bash
# 1. Generate password hash (requires htpasswd or openssl)
# For Airflow (username: admin, password: airflow123)
echo -n "admin:$(openssl passwd -apr1 airflow123)" | base64

# For Trino (username: admin, password: trino123)
echo -n "admin:$(openssl passwd -apr1 trino123)" | base64

# 2. Update the secrets in ingress.yml with your generated hashes

# 3. Apply the configuration
kubectl apply -f ingress.yml

# 4. Add to /etc/hosts (for local testing)
echo "127.0.0.1 airflow.datalake.local trino.datalake.local" | sudo tee -a /etc/hosts
```

#### Change Passwords

To change passwords, regenerate the hash:

```bash
# Windows (PowerShell)
$password = "yournewpassword"
$hash = docker run --rm httpd:2.4-alpine htpasswd -nbB admin $password
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($hash))
Write-Output $encoded

# Linux/Mac
echo -n "admin:$(openssl passwd -apr1 yournewpassword)" | base64
```

### Method 2: OAuth2 Authentication (Enterprise)

Best for: Production, SSO integration, large teams

**File:** `ingress-oauth2.yml`

Supported providers:
- Google Workspace
- GitHub
- Azure Active Directory
- Okta
- Keycloak
- Generic OIDC

#### Setup OAuth2 Proxy

**Step 1: Get OAuth Credentials**

**For Google:**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable Google+ API
4. Go to Credentials → Create Credentials → OAuth 2.0 Client ID
5. Set authorized redirect URI: `https://auth.datalake.local/oauth2/callback`
6. Note the Client ID and Client Secret

**For GitHub:**
1. Go to Settings → Developer settings → OAuth Apps
2. Create new OAuth App
3. Set callback URL: `https://auth.datalake.local/oauth2/callback`
4. Note the Client ID and Client Secret

**For Azure AD:**
1. Azure Portal → Azure Active Directory → App registrations
2. New registration
3. Add redirect URI: `https://auth.datalake.local/oauth2/callback`
4. Note Application (client) ID and create a client secret

**Step 2: Generate Cookie Secret**

```bash
# Python
python -c 'import secrets; print(secrets.token_urlsafe(32))'

# OpenSSL
openssl rand -base64 32 | tr -d '\n'

# PowerShell
[Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

**Step 3: Update Configuration**

Edit `ingress-oauth2.yml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: oauth2-proxy-secrets
stringData:
  client-id: "YOUR_CLIENT_ID_HERE"
  client-secret: "YOUR_CLIENT_SECRET_HERE"
  cookie-secret: "YOUR_GENERATED_COOKIE_SECRET"
```

Edit the ConfigMap for your provider:

```yaml
# For Google
provider = "google"
email_domains = ["yourdomain.com"]  # Or "*" for all

# For GitHub
provider = "github"
github_org = "your-org"  # Optional: restrict to org
github_team = "your-team"  # Optional: restrict to team

# For Azure
provider = "azure"
azure_tenant = "your-tenant-id"

# For OIDC (generic)
provider = "oidc"
oidc_issuer_url = "https://your-idp.com"
```

**Step 4: Deploy**

```bash
# Deploy OAuth2 Proxy and ingresses
kubectl apply -f ingress-oauth2.yml

# Verify deployment
kubectl get pods -l app=oauth2-proxy
kubectl get ingress
```

## 🚀 Deployment

### Prerequisites

1. **Kubernetes Cluster** with Ingress Controller
   ```bash
   # Install NGINX Ingress Controller
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
   ```

2. **DNS or /etc/hosts entries**
   ```bash
   # For local testing (Linux/Mac)
   sudo sh -c 'echo "127.0.0.1 airflow.datalake.local trino.datalake.local auth.datalake.local" >> /etc/hosts'
   
   # For local testing (Windows - run as Administrator)
   Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 airflow.datalake.local trino.datalake.local auth.datalake.local"
   ```

3. **TLS Certificates** (optional but recommended)
   
   **Option A: cert-manager (Recommended for production)**
   ```bash
   # Install cert-manager
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   
   # Create ClusterIssuer
   kubectl apply -f - <<EOF
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: your-email@example.com
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - http01:
           ingress:
             class: nginx
   EOF
   
   # Uncomment TLS sections in ingress files
   ```
   
   **Option B: Self-signed certificates**
   ```bash
   # Generate self-signed cert
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout tls.key -out tls.crt \
     -subj "/CN=*.datalake.local"
   
   # Create secret
   kubectl create secret tls datalake-tls --key=tls.key --cert=tls.crt
   ```

### Deploy Basic Auth

```bash
# Apply the configuration
kubectl apply -f kubernetes/ingress.yml

# Verify
kubectl get ingress
kubectl describe ingress airflow-ingress
kubectl describe ingress trino-ingress

# Test access
curl -k -u admin:airflow123 https://airflow.datalake.local
curl -k -u admin:trino123 https://trino.datalake.local
```

### Deploy OAuth2

```bash
# Apply the configuration
kubectl apply -f kubernetes/ingress-oauth2.yml

# Check OAuth2 Proxy
kubectl get pods -l app=oauth2-proxy
kubectl logs -l app=oauth2-proxy

# Test access (will redirect to login)
open https://airflow.datalake.local
open https://trino.datalake.local
```

## 🔧 Configuration Options

### IP Whitelisting

Restrict access to specific IP ranges:

```yaml
annotations:
  nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

### Rate Limiting

Prevent abuse and brute force attacks:

```yaml
annotations:
  nginx.ingress.kubernetes.io/limit-rps: "10"  # Requests per second
  nginx.ingress.kubernetes.io/limit-connections: "5"  # Concurrent connections
```

### Custom Domains

Change hostnames in the Ingress rules:

```yaml
spec:
  rules:
    - host: airflow.yourdomain.com  # Your actual domain
      http:
        paths:
          - path: /
```

### Timeout Configuration

For long-running Trino queries:

```yaml
annotations:
  nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"  # 1 hour
  nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  nginx.ingress.kubernetes.io/proxy-body-size: "0"  # No limit
```

## 🔍 Troubleshooting

### Check Ingress Status

```bash
# List all ingresses
kubectl get ingress

# Detailed information
kubectl describe ingress airflow-ingress
kubectl describe ingress trino-ingress

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Common Issues

#### 1. 401 Unauthorized with Basic Auth

```bash
# Verify secret exists
kubectl get secret airflow-basic-auth -o yaml

# Check the auth data
kubectl get secret airflow-basic-auth -o jsonpath='{.data.auth}' | base64 -d

# Regenerate if needed
echo -n "admin:$(openssl passwd -apr1 newpassword)" | base64
```

#### 2. 502 Bad Gateway

```bash
# Check if backend service is running
kubectl get pods -l app=airflow
kubectl get svc airflow

# Check service endpoints
kubectl get endpoints airflow

# Test service directly
kubectl port-forward svc/airflow 8080:8080
curl http://localhost:8080
```

#### 3. OAuth2 Redirect Loop

```bash
# Check OAuth2 Proxy logs
kubectl logs -l app=oauth2-proxy

# Verify configuration
kubectl get configmap oauth2-proxy-config -o yaml

# Common issues:
# - Incorrect redirect_url
# - Wrong client_id or client_secret
# - Email domain restrictions
# - Cookie settings
```

#### 4. DNS Resolution

```bash
# Check /etc/hosts (local)
cat /etc/hosts | grep datalake

# Check DNS (production)
nslookup airflow.yourdomain.com
dig trino.yourdomain.com

# Test from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup airflow.datalake.local
```

#### 5. TLS Certificate Issues

```bash
# Check cert-manager certificates
kubectl get certificate
kubectl describe certificate airflow-tls

# Check certificate secret
kubectl get secret airflow-tls-cert -o yaml

# View certificate details
kubectl get secret airflow-tls-cert -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

### Testing Access

```bash
# Basic Auth
curl -k -u admin:password https://airflow.datalake.local

# Check headers
curl -I -k https://airflow.datalake.local

# Follow redirects (OAuth2)
curl -L -k https://airflow.datalake.local

# Verbose debugging
curl -v -k -u admin:password https://airflow.datalake.local
```

## 🛡️ Security Best Practices

1. **Always use TLS in production**
   - Use cert-manager for automatic certificate management
   - Force HTTPS redirects

2. **Strong passwords for basic auth**
   - Use password managers
   - Rotate regularly
   - Never commit secrets to git

3. **Restrict access by IP when possible**
   - Use VPN + IP whitelist
   - Limit to office/datacenter IPs

4. **Enable rate limiting**
   - Prevents brute force attacks
   - Protects against DDoS

5. **Use OAuth2 for production**
   - Centralized authentication
   - MFA support
   - Audit trails
   - Easy user management

6. **Monitor access logs**
   ```bash
   # View nginx logs
   kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
   
   # View OAuth2 Proxy logs
   kubectl logs -l app=oauth2-proxy
   ```

7. **Network policies**
   - Included in ingress.yml
   - Restricts pod-to-pod communication
   - Only allows ingress controller access

## 📊 Monitoring

### Prometheus Metrics

OAuth2 Proxy exposes Prometheus metrics:

```bash
# Port forward to metrics endpoint
kubectl port-forward svc/oauth2-proxy 4180:4180

# Scrape metrics
curl http://localhost:4180/metrics
```

### Access Logs

```bash
# Real-time nginx access logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f

# OAuth2 Proxy access logs
kubectl logs -l app=oauth2-proxy -f

# Filter for authentication failures
kubectl logs -l app=oauth2-proxy | grep "authentication failed"
```

## 🔄 Updating Configuration

### Update Basic Auth Password

```bash
# Generate new hash
NEW_PASS=$(echo -n "admin:$(openssl passwd -apr1 newpassword)" | base64)

# Update secret
kubectl patch secret airflow-basic-auth -p "{\"data\":{\"auth\":\"$NEW_PASS\"}}"

# Verify
kubectl get secret airflow-basic-auth -o jsonpath='{.data.auth}' | base64 -d
```

### Update OAuth2 Configuration

```bash
# Edit the config
kubectl edit configmap oauth2-proxy-config

# Restart OAuth2 Proxy to apply changes
kubectl rollout restart deployment oauth2-proxy

# Check status
kubectl rollout status deployment oauth2-proxy
```

## 📚 Additional Resources

- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [OAuth2 Proxy](https://oauth2-proxy.github.io/oauth2-proxy/)
- [cert-manager](https://cert-manager.io/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

## 🆘 Support

For issues or questions:
1. Check ingress controller logs
2. Verify service and pod status
3. Test backend services directly
4. Check this documentation
5. Create an issue with logs and configuration

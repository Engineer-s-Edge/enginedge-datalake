# GitHub Secrets Setup Guide

This guide helps you set up the required secrets for the CI/CD pipeline.

## Required Secrets

### 1. Container Registry (Automatic)
- **GITHUB_TOKEN**: Automatically provided by GitHub Actions
  - No setup needed
  - Used for pushing to GitHub Container Registry

### 2. Kubernetes Deployment

#### KUBE_CONFIG
Your Kubernetes cluster configuration.

**How to get it:**
```bash
# Export your kubectl config
cat ~/.kube/config | base64 -w 0
```

**Add to GitHub:**
1. Go to Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `KUBE_CONFIG`
4. Value: Paste the base64 encoded config
5. Click "Add secret"

### 3. SSH Deployment (for Docker Compose)

#### DEPLOY_HOST
Hostname or IP of your deployment server.

**Example:**
```
deploy.example.com
```
or
```
192.168.1.100
```

#### DEPLOY_USER
SSH username for the deployment server.

**Example:**
```
ubuntu
```

#### DEPLOY_SSH_KEY
Private SSH key for server access.

**How to generate:**
```bash
# Generate new SSH key
ssh-keygen -t ed25519 -C "github-actions@enginedge-datalake" -f ~/.ssh/deploy_key

# Copy public key to server
ssh-copy-id -i ~/.ssh/deploy_key.pub user@your-server

# Get private key
cat ~/.ssh/deploy_key
```

**Add to GitHub:**
1. Copy the ENTIRE private key (including `-----BEGIN` and `-----END` lines)
2. Go to Settings → Secrets and variables → Actions
3. Name: `DEPLOY_SSH_KEY`
4. Paste the private key
5. Click "Add secret"

### 4. Service Endpoints (for smoke tests)

#### MINIO_ENDPOINT
MinIO endpoint URL for health checks.

**Examples:**
- Development: `http://localhost:9000`
- Production: `https://minio.example.com`

#### API_ENDPOINT
Observability API endpoint.

**Examples:**
- Development: `http://localhost:3010`
- Production: `https://api.datalake.example.com`

### 5. Code Coverage (Optional)

#### CODECOV_TOKEN
Token for uploading coverage reports to Codecov.

**How to get it:**
1. Go to [codecov.io](https://codecov.io)
2. Sign in with GitHub
3. Add your repository
4. Copy the token

## Environment Setup

### Development Environment

Create a GitHub Environment called `development`:
1. Go to Settings → Environments
2. Click "New environment"
3. Name: `development`
4. Configure environment secrets:
   - `MINIO_ENDPOINT`: Development MinIO URL
   - `API_ENDPOINT`: Development API URL
5. (Optional) Add protection rules

### Staging Environment

Create a GitHub Environment called `staging`:
1. Go to Settings → Environments
2. Click "New environment"
3. Name: `staging`
4. Configure environment secrets:
   - `MINIO_ENDPOINT`: Staging MinIO URL
   - `API_ENDPOINT`: Staging API URL
5. Enable "Required reviewers" (recommended)
6. Add team members who can approve deployments

### Production Environment

Create a GitHub Environment called `production`:
1. Go to Settings → Environments
2. Click "New environment"
3. Name: `production`
4. Configure environment secrets:
   - `MINIO_ENDPOINT`: Production MinIO URL
   - `API_ENDPOINT`: Production API URL
   - `KUBE_CONFIG`: Production Kubernetes config (if different from default)
5. **Enable "Required reviewers"** - Add at least 2 reviewers
6. **Enable "Wait timer"** - Set to 5-10 minutes
7. (Optional) Restrict to protected branches only

## Quick Setup Script

Save this as `setup-secrets.sh` and run locally:

```bash
#!/bin/bash

echo "GitHub Repository Secrets Setup"
echo "================================"
echo ""

# Install GitHub CLI if not present
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI not found. Install from: https://cli.github.com/"
    exit 1
fi

# Authenticate
gh auth login

# Set repository (change to your repo)
REPO="Chris-Alexander-Pop/enginedge-datalake"

echo "Setting up secrets for $REPO"
echo ""

# Container Registry (info only)
echo "✓ GITHUB_TOKEN is automatically provided"

# Kubernetes
if [ -f ~/.kube/config ]; then
    echo "Setting KUBE_CONFIG..."
    cat ~/.kube/config | base64 -w 0 | gh secret set KUBE_CONFIG --repo $REPO
    echo "✓ KUBE_CONFIG set"
else
    echo "⚠ ~/.kube/config not found - skipping KUBE_CONFIG"
fi

# SSH Deployment
read -p "Enter deployment host (e.g., deploy.example.com): " DEPLOY_HOST
if [ ! -z "$DEPLOY_HOST" ]; then
    echo "$DEPLOY_HOST" | gh secret set DEPLOY_HOST --repo $REPO
    echo "✓ DEPLOY_HOST set"
fi

read -p "Enter deployment user (e.g., ubuntu): " DEPLOY_USER
if [ ! -z "$DEPLOY_USER" ]; then
    echo "$DEPLOY_USER" | gh secret set DEPLOY_USER --repo $REPO
    echo "✓ DEPLOY_USER set"
fi

read -p "Enter path to SSH private key (e.g., ~/.ssh/deploy_key): " SSH_KEY_PATH
if [ -f "$SSH_KEY_PATH" ]; then
    cat "$SSH_KEY_PATH" | gh secret set DEPLOY_SSH_KEY --repo $REPO
    echo "✓ DEPLOY_SSH_KEY set"
else
    echo "⚠ SSH key not found - skipping DEPLOY_SSH_KEY"
fi

# Service Endpoints
read -p "Enter MinIO endpoint (e.g., https://minio.example.com): " MINIO_ENDPOINT
if [ ! -z "$MINIO_ENDPOINT" ]; then
    echo "$MINIO_ENDPOINT" | gh secret set MINIO_ENDPOINT --repo $REPO --env production
    echo "✓ MINIO_ENDPOINT set for production"
fi

read -p "Enter API endpoint (e.g., https://api.example.com): " API_ENDPOINT
if [ ! -z "$API_ENDPOINT" ]; then
    echo "$API_ENDPOINT" | gh secret set API_ENDPOINT --repo $REPO --env production
    echo "✓ API_ENDPOINT set for production"
fi

# Codecov
read -p "Enter Codecov token (optional, press Enter to skip): " CODECOV_TOKEN
if [ ! -z "$CODECOV_TOKEN" ]; then
    echo "$CODECOV_TOKEN" | gh secret set CODECOV_TOKEN --repo $REPO
    echo "✓ CODECOV_TOKEN set"
fi

echo ""
echo "================================"
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Create GitHub Environments (development, staging, production)"
echo "2. Configure environment-specific secrets"
echo "3. Set up required reviewers for production"
echo "4. Test the CI/CD pipeline"
```

## PowerShell Setup Script (Windows)

Save this as `setup-secrets.ps1`:

```powershell
# GitHub Repository Secrets Setup for Windows
Write-Host "GitHub Repository Secrets Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check for GitHub CLI
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "GitHub CLI not found. Install from: https://cli.github.com/" -ForegroundColor Red
    exit 1
}

# Authenticate
gh auth login

# Set repository
$REPO = "Chris-Alexander-Pop/enginedge-datalake"

Write-Host "Setting up secrets for $REPO" -ForegroundColor Green
Write-Host ""

# Kubernetes
$KubeConfig = "$env:USERPROFILE\.kube\config"
if (Test-Path $KubeConfig) {
    Write-Host "Setting KUBE_CONFIG..." -ForegroundColor Yellow
    $KubeConfigBase64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($KubeConfig))
    $KubeConfigBase64 | gh secret set KUBE_CONFIG --repo $REPO
    Write-Host "✓ KUBE_CONFIG set" -ForegroundColor Green
} else {
    Write-Host "⚠ Kube config not found - skipping KUBE_CONFIG" -ForegroundColor Yellow
}

# SSH Deployment
$DEPLOY_HOST = Read-Host "Enter deployment host (e.g., deploy.example.com)"
if ($DEPLOY_HOST) {
    $DEPLOY_HOST | gh secret set DEPLOY_HOST --repo $REPO
    Write-Host "✓ DEPLOY_HOST set" -ForegroundColor Green
}

$DEPLOY_USER = Read-Host "Enter deployment user (e.g., ubuntu)"
if ($DEPLOY_USER) {
    $DEPLOY_USER | gh secret set DEPLOY_USER --repo $REPO
    Write-Host "✓ DEPLOY_USER set" -ForegroundColor Green
}

# Service Endpoints
$MINIO_ENDPOINT = Read-Host "Enter MinIO endpoint"
if ($MINIO_ENDPOINT) {
    $MINIO_ENDPOINT | gh secret set MINIO_ENDPOINT --repo $REPO --env production
    Write-Host "✓ MINIO_ENDPOINT set" -ForegroundColor Green
}

$API_ENDPOINT = Read-Host "Enter API endpoint"
if ($API_ENDPOINT) {
    $API_ENDPOINT | gh secret set API_ENDPOINT --repo $REPO --env production
    Write-Host "✓ API_ENDPOINT set" -ForegroundColor Green
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Setup complete!" -ForegroundColor Green
```

## Verification

After setting up secrets, verify they're configured correctly:

```bash
# List all secrets (values are hidden)
gh secret list --repo Chris-Alexander-Pop/enginedge-datalake

# List environment secrets
gh secret list --repo Chris-Alexander-Pop/enginedge-datalake --env production
```

## Security Best Practices

1. **Rotate Secrets Regularly**: Update SSH keys and tokens every 90 days
2. **Limit Access**: Only add secrets that are actually needed
3. **Use Environment Secrets**: Environment-specific secrets should be in environments, not repository-level
4. **Audit Access**: Regularly review who has access to secrets
5. **Never Commit Secrets**: Use `.gitignore` to exclude sensitive files
6. **Use Strong Keys**: Generate SSH keys with ed25519 algorithm
7. **Enable 2FA**: Require two-factor authentication for all team members

## Troubleshooting

### "Permission denied" during deployment
- Verify SSH key is correct
- Check that public key is in `~/.ssh/authorized_keys` on server
- Ensure private key doesn't have a passphrase (or use ssh-agent)

### "Invalid kubeconfig" error
- Ensure base64 encoding doesn't have line breaks
- Verify cluster endpoint is accessible from GitHub Actions
- Check that service account has proper permissions

### Secrets not found in workflow
- Verify secret names match exactly (case-sensitive)
- Check that secrets are set in the correct environment
- Ensure environment name in workflow matches GitHub Environment name

## Support

For issues with secrets setup:
1. Check GitHub Actions logs for specific error messages
2. Verify secrets are set: Settings → Secrets and variables → Actions
3. Test SSH connection manually before using in CI/CD
4. Review GitHub's [Encrypted Secrets documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

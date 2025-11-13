#!/usr/bin/env pwsh
# Deploy Ingress Configuration for Airflow and Trino
# This script helps you deploy and configure ingress with authentication

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "oauth2", "both")]
    [string]$AuthType = "basic",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "default",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$UpdatePasswords,
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

function Show-Help {
    Write-Host @"
Deploy Ingress Configuration for Airflow and Trino

USAGE:
    .\deploy-ingress.ps1 [OPTIONS]

OPTIONS:
    -AuthType <basic|oauth2|both>   Authentication method to deploy (default: basic)
    -Namespace <namespace>          Kubernetes namespace (default: default)
    -DryRun                         Show what would be deployed without applying
    -UpdatePasswords                Generate new passwords for basic auth
    -Help                           Show this help message

EXAMPLES:
    # Deploy basic authentication
    .\deploy-ingress.ps1 -AuthType basic

    # Deploy OAuth2 authentication
    .\deploy-ingress.ps1 -AuthType oauth2

    # Deploy both (useful for migration)
    .\deploy-ingress.ps1 -AuthType both

    # Dry run to see what would be applied
    .\deploy-ingress.ps1 -AuthType basic -DryRun

    # Update basic auth passwords
    .\deploy-ingress.ps1 -UpdatePasswords

BEFORE RUNNING:
    1. Ensure kubectl is configured and pointing to correct cluster
    2. Install NGINX Ingress Controller if not already installed
    3. For OAuth2, configure client credentials in ingress-oauth2.yml
    4. Update domain names in ingress files
    5. Configure DNS or /etc/hosts

"@
    exit 0
}

if ($Help) {
    Show-Help
}

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Cyan

# Check kubectl
try {
    kubectl version --client | Out-Null
    Write-Host "✓ kubectl found" -ForegroundColor Green
} catch {
    Write-Host "✗ kubectl not found. Please install kubectl." -ForegroundColor Red
    exit 1
}

# Check cluster connection
try {
    kubectl cluster-info | Out-Null
    Write-Host "✓ Connected to Kubernetes cluster" -ForegroundColor Green
} catch {
    Write-Host "✗ Cannot connect to Kubernetes cluster" -ForegroundColor Red
    exit 1
}

# Check if ingress controller is installed
$ingressController = kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx 2>$null
if (-not $ingressController) {
    Write-Host "⚠ NGINX Ingress Controller not found" -ForegroundColor Yellow
    Write-Host "To install: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml" -ForegroundColor Yellow
    
    $install = Read-Host "Install NGINX Ingress Controller now? (y/n)"
    if ($install -eq "y") {
        Write-Host "Installing NGINX Ingress Controller..." -ForegroundColor Cyan
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
        Write-Host "Waiting for ingress controller to be ready..." -ForegroundColor Cyan
        kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
        Write-Host "✓ NGINX Ingress Controller installed" -ForegroundColor Green
    }
} else {
    Write-Host "✓ NGINX Ingress Controller found" -ForegroundColor Green
}

# Function to generate password hash
function New-PasswordHash {
    param(
        [string]$Username,
        [string]$Password
    )
    
    # Use docker to run htpasswd (most reliable cross-platform method)
    $hash = docker run --rm httpd:2.4-alpine htpasswd -nbB $Username $Password 2>$null
    if ($hash) {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($hash.Trim()))
        return $encoded
    }
    
    # Fallback to openssl (if docker not available)
    try {
        $opensslHash = openssl passwd -apr1 $Password 2>$null
        $fullHash = "${Username}:${opensslHash}"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($fullHash))
        return $encoded
    } catch {
        Write-Host "✗ Cannot generate password hash. Install Docker or OpenSSL." -ForegroundColor Red
        return $null
    }
}

# Update passwords if requested
if ($UpdatePasswords) {
    Write-Host "`nGenerating new passwords for Basic Auth..." -ForegroundColor Cyan
    
    # Airflow password
    $airflowUser = Read-Host "Enter Airflow username (default: admin)"
    if ([string]::IsNullOrEmpty($airflowUser)) { $airflowUser = "admin" }
    $airflowPass = Read-Host "Enter Airflow password" -AsSecureString
    $airflowPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($airflowPass))
    
    $airflowHash = New-PasswordHash -Username $airflowUser -Password $airflowPassPlain
    if ($airflowHash) {
        Write-Host "✓ Airflow password hash generated" -ForegroundColor Green
        Write-Host "Hash: $airflowHash" -ForegroundColor Gray
    }
    
    # Trino password
    $trinoUser = Read-Host "`nEnter Trino username (default: admin)"
    if ([string]::IsNullOrEmpty($trinoUser)) { $trinoUser = "admin" }
    $trinoPass = Read-Host "Enter Trino password" -AsSecureString
    $trinoPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($trinoPass))
    
    $trinoHash = New-PasswordHash -Username $trinoUser -Password $trinoPassPlain
    if ($trinoHash) {
        Write-Host "✓ Trino password hash generated" -ForegroundColor Green
        Write-Host "Hash: $trinoHash" -ForegroundColor Gray
    }
    
    Write-Host "`nUpdate these hashes in kubernetes/ingress.yml before deploying." -ForegroundColor Yellow
    exit 0
}

# Deploy based on auth type
$kubernetesDir = Join-Path $PSScriptRoot ".." "kubernetes"

Write-Host "`nDeploying ingress configuration..." -ForegroundColor Cyan
Write-Host "Auth Type: $AuthType" -ForegroundColor Gray
Write-Host "Namespace: $Namespace" -ForegroundColor Gray
Write-Host "Dry Run: $DryRun" -ForegroundColor Gray

$dryRunFlag = if ($DryRun) { "--dry-run=client" } else { "" }

# Deploy Basic Auth
if ($AuthType -eq "basic" -or $AuthType -eq "both") {
    Write-Host "`nDeploying Basic Authentication..." -ForegroundColor Cyan
    $ingressFile = Join-Path $kubernetesDir "ingress.yml"
    
    if (Test-Path $ingressFile) {
        if ($DryRun) {
            kubectl apply -f $ingressFile -n $Namespace --dry-run=client
        } else {
            kubectl apply -f $ingressFile -n $Namespace
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Basic auth ingress deployed" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to deploy basic auth ingress" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ ingress.yml not found at $ingressFile" -ForegroundColor Red
    }
}

# Deploy OAuth2
if ($AuthType -eq "oauth2" -or $AuthType -eq "both") {
    Write-Host "`nDeploying OAuth2 Authentication..." -ForegroundColor Cyan
    $oauth2File = Join-Path $kubernetesDir "ingress-oauth2.yml"
    
    if (Test-Path $oauth2File) {
        # Check if OAuth credentials are configured
        $fileContent = Get-Content $oauth2File -Raw
        if ($fileContent -match "YOUR_CLIENT_ID" -or $fileContent -match "YOUR_CLIENT_SECRET") {
            Write-Host "⚠ OAuth2 credentials not configured in ingress-oauth2.yml" -ForegroundColor Yellow
            Write-Host "Please update client-id and client-secret before deploying." -ForegroundColor Yellow
            
            $continue = Read-Host "Continue anyway? (y/n)"
            if ($continue -ne "y") {
                Write-Host "Skipping OAuth2 deployment" -ForegroundColor Yellow
                exit 0
            }
        }
        
        if ($DryRun) {
            kubectl apply -f $oauth2File -n $Namespace --dry-run=client
        } else {
            kubectl apply -f $oauth2File -n $Namespace
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ OAuth2 ingress deployed" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to deploy OAuth2 ingress" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ ingress-oauth2.yml not found at $oauth2File" -ForegroundColor Red
    }
}

# Show status
if (-not $DryRun) {
    Write-Host "`nChecking deployment status..." -ForegroundColor Cyan
    
    Start-Sleep -Seconds 2
    
    Write-Host "`nIngresses:" -ForegroundColor Cyan
    kubectl get ingress -n $Namespace
    
    if ($AuthType -eq "oauth2" -or $AuthType -eq "both") {
        Write-Host "`nOAuth2 Proxy Pods:" -ForegroundColor Cyan
        kubectl get pods -n $Namespace -l app=oauth2-proxy
    }
    
    Write-Host "`nServices:" -ForegroundColor Cyan
    kubectl get svc -n $Namespace | Select-String -Pattern "airflow|trino|oauth2"
    
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "1. Update /etc/hosts or DNS with ingress hostnames" -ForegroundColor White
    Write-Host "2. Configure TLS certificates (recommended)" -ForegroundColor White
    Write-Host "3. Test access to Airflow and Trino UIs" -ForegroundColor White
    Write-Host "4. Review logs if any issues: kubectl logs -n $Namespace <pod-name>" -ForegroundColor White
    
    Write-Host "`nTest URLs:" -ForegroundColor Yellow
    Write-Host "  Airflow: http://airflow.datalake.local" -ForegroundColor White
    Write-Host "  Trino:   http://trino.datalake.local" -ForegroundColor White
    if ($AuthType -eq "oauth2" -or $AuthType -eq "both") {
        Write-Host "  OAuth:   http://auth.datalake.local/oauth2" -ForegroundColor White
    }
}

Write-Host "`n✓ Deployment complete!" -ForegroundColor Green

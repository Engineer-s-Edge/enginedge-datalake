#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy EnginEdge Data Lake components using Helm

.DESCRIPTION
    This script deploys the data lake infrastructure components (MinIO, PostgreSQL)
    using Helm charts.

.PARAMETER Namespace
    Kubernetes namespace to deploy to (default: datalake)

.PARAMETER SkipRepoUpdate
    Skip updating Helm repositories

.EXAMPLE
    .\deploy-datalake.ps1
    .\deploy-datalake.ps1 -Namespace production
#>

param(
    [string]$Namespace = "datalake",
    [switch]$SkipRepoUpdate
)

$ErrorActionPreference = "Stop"

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  EnginEdge Data Lake - Helm Deployment" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# Check if kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] kubectl not found. Please install kubectl first." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] kubectl is available" -ForegroundColor Green

# Check if helm is available
if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Helm not found. Please install Helm first." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Helm is available" -ForegroundColor Green

# Check if cluster is accessible
$clusterInfo = kubectl cluster-info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Cannot connect to Kubernetes cluster." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Kubernetes cluster is accessible" -ForegroundColor Green

Write-Host ""

# Add Helm repositories
if (-not $SkipRepoUpdate) {
    Write-Host "Adding Helm repositories..." -ForegroundColor Yellow
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>$null
    helm repo add minio https://charts.min.io/ 2>$null
    
    Write-Host "Updating Helm repositories..." -ForegroundColor Yellow
    helm repo update
    Write-Host "[OK] Helm repositories updated" -ForegroundColor Green
    Write-Host ""
}

# Create namespace
Write-Host "Creating namespace: $Namespace" -ForegroundColor Yellow
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - | Out-Null
Write-Host "[OK] Namespace ready: $Namespace" -ForegroundColor Green
Write-Host ""

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Deploy PostgreSQL
Write-Host "-------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Deploying PostgreSQL..." -ForegroundColor Yellow
Write-Host "-------------------------------------------------------" -ForegroundColor Cyan

$postgresValuesFile = Join-Path $scriptDir "postgres-values.yaml"
if (-not (Test-Path $postgresValuesFile)) {
    Write-Host "[ERROR] Values file not found: $postgresValuesFile" -ForegroundColor Red
    exit 1
}

helm upgrade --install postgres bitnami/postgresql `
    --namespace $Namespace `
    --values $postgresValuesFile `
    --wait `
    --timeout 5m

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] PostgreSQL deployed successfully" -ForegroundColor Green
} else {
    Write-Host "[ERROR] PostgreSQL deployment failed" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Deploy MinIO
Write-Host "-------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Deploying MinIO..." -ForegroundColor Yellow
Write-Host "-------------------------------------------------------" -ForegroundColor Cyan

$minioValuesFile = Join-Path $scriptDir "minio-values.yaml"
if (-not (Test-Path $minioValuesFile)) {
    Write-Host "[ERROR] Values file not found: $minioValuesFile" -ForegroundColor Red
    exit 1
}

helm upgrade --install minio minio/minio `
    --namespace $Namespace `
    --values $minioValuesFile `
    --wait `
    --timeout 5m

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] MinIO deployed successfully" -ForegroundColor Green
} else {
    Write-Host "[ERROR] MinIO deployment failed" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Summary
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Deployed components:" -ForegroundColor Yellow
Write-Host "  - PostgreSQL (metastore)" -ForegroundColor White
Write-Host "  - MinIO (object storage)" -ForegroundColor White
Write-Host ""
Write-Host "Check deployment status:" -ForegroundColor Yellow
Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor White
Write-Host ""
Write-Host "Access services (port-forward):" -ForegroundColor Yellow
Write-Host "  kubectl port-forward -n $Namespace svc/minio 9000:9000 9001:9001" -ForegroundColor White
Write-Host "  kubectl port-forward -n $Namespace svc/postgres-postgresql 5432:5432" -ForegroundColor White
Write-Host ""

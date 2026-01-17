#!/usr/bin/env pwsh
# Deploy EnginEdge Data Lake using Helm

param(
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "datalake",
    
    [Parameter(Mandatory=$false)]
    [string]$ReleaseName = "datalake",
    
    [Parameter(Mandatory=$false)]
    [string]$ValuesFile = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateNamespace = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$Upgrade = $false
)

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "EnginEdge Data Lake Helm Deployment" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if helm is installed
$helmVersion = helm version --short 2>$null
if (-not $helmVersion) {
    Write-Host "❌ Error: Helm is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Helm: https://helm.sh/docs/intro/install/" -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ Helm version: $helmVersion" -ForegroundColor Green

# Check if kubectl is available
$kubectlVersion = kubectl version --client --short 2>$null
if (-not $kubectlVersion) {
    Write-Host "❌ Error: kubectl is not installed or not in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "✓ kubectl is available" -ForegroundColor Green

# Check cluster connectivity
$clusterInfo = kubectl cluster-info 2>$null
if (-not $clusterInfo) {
    Write-Host "❌ Error: Cannot connect to Kubernetes cluster" -ForegroundColor Red
    Write-Host "Please ensure your kubeconfig is configured correctly" -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ Connected to Kubernetes cluster" -ForegroundColor Green
Write-Host ""

# Create namespace if it doesn't exist and CreateNamespace is true
if ($CreateNamespace) {
    $namespaceExists = kubectl get namespace $Namespace 2>$null
    if (-not $namespaceExists) {
        Write-Host "Creating namespace: $Namespace" -ForegroundColor Yellow
        kubectl create namespace $Namespace
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Namespace created" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to create namespace" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "✓ Namespace '$Namespace' already exists" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Deployment Configuration:" -ForegroundColor Cyan
Write-Host "  Namespace: $Namespace"
Write-Host "  Release Name: $ReleaseName"
Write-Host "  Chart: ./datalake"
if ($ValuesFile) {
    Write-Host "  Values File: $ValuesFile"
}
Write-Host ""

# Build helm command
$helmArgs = @()
if ($Upgrade) {
    $helmArgs += "upgrade", "--install"
} else {
    $helmArgs += "install"
}

$helmArgs += $ReleaseName, "./datalake"
$helmArgs += "--namespace", $Namespace

if ($ValuesFile) {
    if (Test-Path $ValuesFile) {
        $helmArgs += "--values", $ValuesFile
    } else {
        Write-Host "❌ Error: Values file not found: $ValuesFile" -ForegroundColor Red
        exit 1
    }
}

if ($DryRun) {
    $helmArgs += "--dry-run", "--debug"
    Write-Host "🔍 Running in dry-run mode (no changes will be made)" -ForegroundColor Yellow
    Write-Host ""
}

# Execute helm command
Write-Host "Executing Helm deployment..." -ForegroundColor Yellow
Write-Host "Command: helm $($helmArgs -join ' ')" -ForegroundColor Gray
Write-Host ""

& helm @helmArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
    
    if (-not $DryRun) {
        Write-Host "To check the status of your deployment:" -ForegroundColor Cyan
        Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor White
        Write-Host ""
        Write-Host "To view the release notes:" -ForegroundColor Cyan
        Write-Host "  helm get notes $ReleaseName -n $Namespace" -ForegroundColor White
        Write-Host ""
        Write-Host "To port-forward services:" -ForegroundColor Cyan
        Write-Host "  kubectl port-forward -n $Namespace svc/trino 8080:8080" -ForegroundColor White
        Write-Host "  kubectl port-forward -n $Namespace svc/airflow 8082:8080" -ForegroundColor White
        Write-Host "  kubectl port-forward -n $Namespace svc/spark-master 8083:8080" -ForegroundColor White
        Write-Host "  kubectl port-forward -n $Namespace svc/minio 9001:9001" -ForegroundColor White
    }
} else {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Red
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host "=====================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "To troubleshoot:" -ForegroundColor Cyan
    Write-Host "  helm list -n $Namespace" -ForegroundColor White
    Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor White
    Write-Host "  kubectl describe pod <pod-name> -n $Namespace" -ForegroundColor White
    exit 1
}

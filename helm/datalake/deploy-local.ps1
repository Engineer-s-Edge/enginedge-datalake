# Deploy Datalake to Local Kubernetes Cluster
# Supports: kind, k3d, Docker Desktop, Minikube

param(
    [Parameter(HelpMessage="Deployment environment (local, dev, prod)")]
    [ValidateSet("local", "dev", "prod")]
    [string]$Environment = "local",
    
    [Parameter(HelpMessage="Release name for Helm")]
    [string]$ReleaseName = "datalake",
    
    [Parameter(HelpMessage="Kubernetes namespace")]
    [string]$Namespace = "datalake",
    
    [Parameter(HelpMessage="Enable minimal installation (core services only)")]
    [switch]$Minimal,
    
    [Parameter(HelpMessage="Disable persistence (use emptyDir)")]
    [switch]$NoPersistence,
    
    [Parameter(HelpMessage="Enable debug mode")]
    [switch]$Debug,
    
    [Parameter(HelpMessage="Dry run (template only)")]
    [switch]$DryRun,
    
    [Parameter(HelpMessage="Wait for all pods to be ready")]
    [switch]$Wait,
    
    [Parameter(HelpMessage="Timeout for wait (default: 10m)")]
    [string]$Timeout = "10m"
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "EnginEdge Datalake - Local Deployment" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check if kubectl is available
Write-Host "[1/8] Checking prerequisites..." -ForegroundColor Yellow
try {
    $null = kubectl version --client --output=json 2>$null
    Write-Host "  ✓ kubectl is installed" -ForegroundColor Green
} catch {
    Write-Host "  ✗ kubectl is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check if Helm is available
try {
    $null = helm version --short 2>$null
    Write-Host "  ✓ Helm is installed" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Helm is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check if cluster is accessible
Write-Host "[2/8] Checking cluster connectivity..." -ForegroundColor Yellow
try {
    $clusterInfo = kubectl cluster-info 2>&1
    Write-Host "  ✓ Cluster is accessible" -ForegroundColor Green
    
    # Detect cluster type
    $context = kubectl config current-context
    if ($context -match "kind") {
        Write-Host "  Detected: kind cluster" -ForegroundColor Cyan
    } elseif ($context -match "k3d") {
        Write-Host "  Detected: k3d cluster" -ForegroundColor Cyan
    } elseif ($context -match "docker-desktop") {
        Write-Host "  Detected: Docker Desktop cluster" -ForegroundColor Cyan
    } elseif ($context -match "minikube") {
        Write-Host "  Detected: Minikube cluster" -ForegroundColor Cyan
    } else {
        Write-Host "  Detected: $context" -ForegroundColor Cyan
    }
} catch {
    Write-Host "  ✗ Cannot connect to cluster" -ForegroundColor Red
    Write-Host "    Make sure your cluster is running and kubectl is configured" -ForegroundColor Red
    exit 1
}

# Check default StorageClass
Write-Host "[3/8] Checking storage configuration..." -ForegroundColor Yellow
$defaultSC = kubectl get storageclass -o json | ConvertFrom-Json | 
    Select-Object -ExpandProperty items | 
    Where-Object { $_.metadata.annotations.'storageclass.kubernetes.io/is-default-class' -eq 'true' } |
    Select-Object -First 1

if ($defaultSC) {
    Write-Host "  ✓ Default StorageClass: $($defaultSC.metadata.name)" -ForegroundColor Green
} else {
    Write-Host "  ⚠ No default StorageClass found" -ForegroundColor Yellow
    Write-Host "    Creating local-path StorageClass..." -ForegroundColor Yellow
    
    @"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
"@ | kubectl apply -f - 2>&1 | Out-Null
    
    Write-Host "  ✓ StorageClass created" -ForegroundColor Green
}

# Create namespace if it doesn't exist
Write-Host "[4/8] Setting up namespace..." -ForegroundColor Yellow
$namespaceExists = kubectl get namespace $Namespace 2>$null
if ($LASTEXITCODE -ne 0) {
    kubectl create namespace $Namespace | Out-Null
    Write-Host "  ✓ Namespace '$Namespace' created" -ForegroundColor Green
} else {
    Write-Host "  ✓ Namespace '$Namespace' already exists" -ForegroundColor Green
}

# Build Helm command
Write-Host "[5/8] Preparing Helm installation..." -ForegroundColor Yellow

$valuesFile = "values-$Environment.yaml"
if (-not (Test-Path $valuesFile)) {
    Write-Host "  ✗ Values file not found: $valuesFile" -ForegroundColor Red
    exit 1
}
Write-Host "  Using values file: $valuesFile" -ForegroundColor Cyan

$helmArgs = @(
    "upgrade",
    "--install",
    $ReleaseName,
    ".",
    "--namespace", $Namespace,
    "--values", $valuesFile
)

# Add minimal configuration
if ($Minimal) {
    Write-Host "  Enabling minimal installation (core services only)" -ForegroundColor Cyan
    $helmArgs += @(
        "--set", "jupyter.enabled=false",
        "--set", "greatExpectations.enabled=false",
        "--set", "marquez.enabled=false",
        "--set", "tokern.enabled=false"
    )
}

# Disable persistence
if ($NoPersistence) {
    Write-Host "  Disabling persistence (using emptyDir)" -ForegroundColor Cyan
    $helmArgs += @(
        "--set", "minio.persistence.enabled=false",
        "--set", "postgres.persistence.enabled=false",
        "--set", "airflow.persistence.logs.enabled=false",
        "--set", "airflow.persistence.plugins.enabled=false",
        "--set", "marquez.db.persistence.enabled=false",
        "--set", "jupyter.persistence.enabled=false",
        "--set", "greatExpectations.persistence.enabled=false"
    )
}

# Wait for resources
if ($Wait) {
    Write-Host "  Will wait for resources to be ready (timeout: $Timeout)" -ForegroundColor Cyan
    $helmArgs += @("--wait", "--timeout", $Timeout)
}

# Dry run
if ($DryRun) {
    Write-Host "  Dry run mode enabled" -ForegroundColor Cyan
    $helmArgs += "--dry-run"
}

# Debug mode
if ($Debug) {
    Write-Host "  Debug mode enabled" -ForegroundColor Cyan
    $helmArgs += "--debug"
}

# Deploy with Helm
Write-Host "[6/8] Deploying with Helm..." -ForegroundColor Yellow
Write-Host "  Command: helm $($helmArgs -join ' ')" -ForegroundColor DarkGray

try {
    & helm $helmArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Helm deployment successful" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Helm deployment failed" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "  ✗ Helm deployment failed: $_" -ForegroundColor Red
    exit 1
}

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry run completed successfully!" -ForegroundColor Green
    exit 0
}

# Wait for pods to be ready
Write-Host "[7/8] Waiting for pods to be ready..." -ForegroundColor Yellow
Write-Host "  This may take a few minutes..." -ForegroundColor DarkGray

$maxAttempts = 60
$attempt = 0
$allReady = $false

while ($attempt -lt $maxAttempts -and -not $allReady) {
    Start-Sleep -Seconds 5
    $attempt++
    
    $pods = kubectl get pods -n $Namespace -o json | ConvertFrom-Json | Select-Object -ExpandProperty items
    
    if ($pods.Count -eq 0) {
        Write-Host "  Waiting for pods to be created... ($attempt/$maxAttempts)" -ForegroundColor DarkGray
        continue
    }
    
    $totalPods = $pods.Count
    $readyPods = ($pods | Where-Object { 
        $_.status.phase -eq "Running" -and 
        $_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" }
    }).Count
    
    Write-Host "  Ready: $readyPods/$totalPods ($attempt/$maxAttempts)" -ForegroundColor DarkGray
    
    if ($readyPods -eq $totalPods) {
        $allReady = $true
    }
}

if ($allReady) {
    Write-Host "  ✓ All pods are ready" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Some pods are not ready yet. Check status with: kubectl get pods -n $Namespace" -ForegroundColor Yellow
}

# Display access information
Write-Host "[8/8] Deployment complete!" -ForegroundColor Yellow
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Access Information" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Use port-forward to access services:" -ForegroundColor White
Write-Host ""
Write-Host "  MinIO Console:" -ForegroundColor Yellow
Write-Host "    kubectl port-forward -n $Namespace svc/minio 9001:9001" -ForegroundColor DarkGray
Write-Host "    http://localhost:9001 (minioadmin/minioadmin123)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Airflow Web UI:" -ForegroundColor Yellow
Write-Host "    kubectl port-forward -n $Namespace svc/airflow 8080:8080" -ForegroundColor DarkGray
Write-Host "    http://localhost:8080 (admin/admin123)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Trino:" -ForegroundColor Yellow
Write-Host "    kubectl port-forward -n $Namespace svc/trino 8080:8080" -ForegroundColor DarkGray
Write-Host "    http://localhost:8080" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Spark Master UI:" -ForegroundColor Yellow
Write-Host "    kubectl port-forward -n $Namespace svc/spark-master 8080:8080" -ForegroundColor DarkGray
Write-Host "    http://localhost:8080" -ForegroundColor Cyan
Write-Host ""

if (-not $Minimal) {
    Write-Host "  Jupyter Notebook:" -ForegroundColor Yellow
    Write-Host "    kubectl port-forward -n $Namespace svc/jupyter 8888:8888" -ForegroundColor DarkGray
    Write-Host "    http://localhost:8888 (token: jupyter123)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Marquez Web UI:" -ForegroundColor Yellow
    Write-Host "    kubectl port-forward -n $Namespace svc/marquez-web 3000:3000" -ForegroundColor DarkGray
    Write-Host "    http://localhost:3000" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "Useful commands:" -ForegroundColor White
Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor DarkGray
Write-Host "  kubectl get svc -n $Namespace" -ForegroundColor DarkGray
Write-Host "  kubectl logs -n $Namespace <pod-name>" -ForegroundColor DarkGray
Write-Host "  helm status $ReleaseName -n $Namespace" -ForegroundColor DarkGray
Write-Host ""
Write-Host "To uninstall:" -ForegroundColor White
Write-Host "  helm uninstall $ReleaseName -n $Namespace" -ForegroundColor DarkGray
Write-Host "  kubectl delete pvc -n $Namespace --all" -ForegroundColor DarkGray
Write-Host ""

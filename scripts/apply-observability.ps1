#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Apply ServiceMonitors and Grafana Dashboards for EnginEdge Datalake
.DESCRIPTION
    This script applies Prometheus ServiceMonitors and Grafana dashboards for monitoring
    the datalake components (Trino, Spark, Airflow, MinIO, PostgreSQL).
.PARAMETER Namespace
    Kubernetes namespace where datalake is deployed (default: datalake)
.PARAMETER SkipValidation
    Skip validation of Prometheus targets after applying
.PARAMETER DryRun
    Show what would be applied without actually applying
.EXAMPLE
    .\apply-observability.ps1
.EXAMPLE
    .\apply-observability.ps1 -Namespace enginedge -DryRun
#>

param(
    [string]$Namespace = "datalake",
    [switch]$SkipValidation,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Write-Error-Custom { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }

Write-Info "Starting Datalake Observability Setup..."
Write-Info "Namespace: $Namespace"

# Check if kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error-Custom "kubectl not found. Please install kubectl first."
    exit 1
}

# Check if namespace exists
$namespaceExists = kubectl get namespace $Namespace -o jsonpath='{.metadata.name}' 2>$null
if (-not $namespaceExists) {
    Write-Error-Custom "Namespace '$Namespace' does not exist. Please create it first or deploy the datalake."
    exit 1
}

# Define observability resources directory (relative to script location)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$datalakeRoot = Split-Path -Parent $scriptDir
$observabilityDir = Join-Path $datalakeRoot "k8s\observability"

# Create observability directory structure if it doesn't exist
if (-not (Test-Path $observabilityDir)) {
    Write-Info "Creating observability directory structure..."
    New-Item -ItemType Directory -Path "$observabilityDir\servicemonitors" -Force | Out-Null
    New-Item -ItemType Directory -Path "$observabilityDir\dashboards" -Force | Out-Null
}

# ServiceMonitor definitions
$serviceMonitors = @(
    @{
        name = "trino"
        file = "trino-servicemonitor.yaml"
        content = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: datalake-trino
  namespace: $Namespace
  labels:
    app: enginedge
    component: datalake
    service: trino
spec:
  selector:
    matchLabels:
      app: enginedge
      component: trino
  endpoints:
    - port: http
      path: /v1/metrics
      interval: 30s
      scrapeTimeout: 10s
      scheme: http
"@
    },
    @{
        name = "minio"
        file = "minio-servicemonitor.yaml"
        content = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: datalake-minio
  namespace: $Namespace
  labels:
    app: enginedge
    component: datalake
    service: minio
spec:
  selector:
    matchLabels:
      app: enginedge
      component: minio
  endpoints:
    - port: api
      path: /minio/v2/metrics/cluster
      interval: 30s
      scrapeTimeout: 10s
      scheme: http
"@
    },
    @{
        name = "spark-master"
        file = "spark-servicemonitor.yaml"
        content = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: datalake-spark
  namespace: $Namespace
  labels:
    app: enginedge
    component: datalake
    service: spark
spec:
  selector:
    matchLabels:
      app: enginedge
      component: spark-master
  endpoints:
    - port: metrics
      interval: 30s
      scrapeTimeout: 10s
      scheme: http
"@
    },
    @{
        name = "postgres"
        file = "postgres-servicemonitor.yaml"
        content = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: datalake-postgres
  namespace: $Namespace
  labels:
    app: enginedge
    component: datalake
    service: postgres
spec:
  selector:
    matchLabels:
      app: enginedge
      component: postgres
  endpoints:
    - port: metrics
      interval: 30s
      scrapeTimeout: 10s
      scheme: http
"@
    },
    @{
        name = "airflow"
        file = "airflow-servicemonitor.yaml"
        content = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: datalake-airflow
  namespace: $Namespace
  labels:
    app: enginedge
    component: datalake
    service: airflow
spec:
  selector:
    matchLabels:
      app: enginedge
      component: airflow
  endpoints:
    - port: http
      path: /health
      interval: 30s
      scrapeTimeout: 10s
      scheme: http
"@
    }
)

Write-Info "`nApplying ServiceMonitors..."
$appliedCount = 0

foreach ($sm in $serviceMonitors) {
    $filePath = Join-Path "$observabilityDir\servicemonitors" $sm.file
    
    # Save ServiceMonitor to file
    $sm.content | Out-File -FilePath $filePath -Encoding UTF8
    
    if ($DryRun) {
        Write-Info "Would apply: $($sm.name)"
        kubectl apply -f $filePath --dry-run=client
    } else {
        try {
            Write-Info "Applying ServiceMonitor: $($sm.name)"
            kubectl apply -f $filePath
            $appliedCount++
            Write-Success "Applied ServiceMonitor: $($sm.name)"
        } catch {
            Write-Warning "Failed to apply ServiceMonitor: $($sm.name) - $_"
        }
    }
}

if (-not $DryRun) {
    Write-Success "`n$appliedCount ServiceMonitors applied successfully"
}

# Apply Grafana Dashboards
Write-Info "`nApplying Grafana Dashboards..."

$dashboardConfigMap = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: datalake-grafana-dashboards
  namespace: $Namespace
  labels:
    app: enginedge
    component: datalake
    grafana_dashboard: "1"
data:
  datalake-overview.json: |
    {
      "dashboard": {
        "title": "EnginEdge Datalake Overview",
        "tags": ["datalake", "enginedge"],
        "timezone": "browser",
        "schemaVersion": 16,
        "version": 1,
        "refresh": "30s",
        "panels": [
          {
            "id": 1,
            "title": "Service Health Status",
            "type": "stat",
            "targets": [
              {
                "expr": "up{namespace=\"$Namespace\"}",
                "legendFormat": "{{job}}"
              }
            ],
            "gridPos": {"h": 6, "w": 24, "x": 0, "y": 0}
          },
          {
            "id": 2,
            "title": "MinIO Storage Capacity",
            "type": "graph",
            "targets": [
              {
                "expr": "minio_cluster_capacity_usable_total_bytes",
                "legendFormat": "Total Capacity"
              },
              {
                "expr": "minio_cluster_capacity_usable_free_bytes",
                "legendFormat": "Free Space"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 6}
          },
          {
            "id": 3,
            "title": "Trino Active Queries",
            "type": "graph",
            "targets": [
              {
                "expr": "trino_execution_QueryManager_RunningQueries",
                "legendFormat": "Running Queries"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 6}
          },
          {
            "id": 4,
            "title": "Spark Master Status",
            "type": "stat",
            "targets": [
              {
                "expr": "spark_master_aliveWorkers_Value",
                "legendFormat": "Alive Workers"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 14}
          },
          {
            "id": 5,
            "title": "PostgreSQL Connections",
            "type": "graph",
            "targets": [
              {
                "expr": "pg_stat_database_numbackends",
                "legendFormat": "{{datname}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 14}
          }
        ]
      }
    }
"@

$dashboardPath = Join-Path "$observabilityDir\dashboards" "datalake-dashboards.yaml"
$dashboardConfigMap | Out-File -FilePath $dashboardPath -Encoding UTF8

if ($DryRun) {
    Write-Info "Would apply Grafana dashboards"
    kubectl apply -f $dashboardPath --dry-run=client
} else {
    try {
        Write-Info "Applying Grafana dashboard ConfigMap..."
        kubectl apply -f $dashboardPath
        Write-Success "Grafana dashboards applied successfully"
    } catch {
        Write-Warning "Failed to apply dashboards: $_"
    }
}

# Validation
if (-not $SkipValidation -and -not $DryRun) {
    Write-Info "`nValidating ServiceMonitors..."
    
    Start-Sleep -Seconds 5
    
    $serviceMonitorList = kubectl get servicemonitor -n $Namespace -l component=datalake -o jsonpath='{.items[*].metadata.name}'
    
    if ($serviceMonitorList) {
        Write-Success "Found ServiceMonitors: $serviceMonitorList"
        
        # Check if Prometheus is scraping
        Write-Info "`nChecking Prometheus targets..."
        Write-Info "To verify targets, access Prometheus UI and check Status > Targets"
        Write-Info "Expected targets: datalake-trino, datalake-minio, datalake-spark, datalake-postgres, datalake-airflow"
        
        # Try to check Prometheus targets if port-forward is available
        $prometheusRunning = kubectl get pods -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>$null
        if ($prometheusRunning) {
            Write-Info "`nPrometheus pod found: $prometheusRunning"
            Write-Info "You can port-forward to Prometheus to check targets:"
            Write-Info "kubectl port-forward -n monitoring $prometheusRunning 9090:9090"
            Write-Info "Then visit: http://localhost:9090/targets"
        }
    } else {
        Write-Warning "No ServiceMonitors found in namespace $Namespace"
    }
    
    # Check dashboards
    $dashboards = kubectl get configmap -n $Namespace -l grafana_dashboard=1 -o jsonpath='{.items[*].metadata.name}'
    if ($dashboards) {
        Write-Success "Found Grafana dashboards: $dashboards"
        Write-Info "`nTo access dashboards, ensure Grafana has the dashboard sidecar enabled and configured"
        Write-Info "The dashboards should appear automatically in Grafana under the 'EnginEdge' folder"
    }
}

Write-Success "`n✨ Observability setup complete!"
Write-Info "`nNext steps:"
Write-Info "1. Verify Prometheus is scraping the targets"
Write-Info "2. Check Grafana for the new dashboards"
Write-Info "3. Run validation queries on Trino and Spark"
Write-Info "4. Monitor the dashboards for any issues"

if ($DryRun) {
    Write-Warning "`n⚠️  This was a dry-run. No changes were made."
    Write-Info "Run without -DryRun to apply the changes."
}

#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validate Datalake Observability Setup
.DESCRIPTION
    This script validates that ServiceMonitors are deployed correctly and Prometheus
    is scraping metrics from all datalake components.
.PARAMETER Namespace
    Kubernetes namespace where datalake is deployed (default: datalake)
.PARAMETER PrometheusNamespace
    Kubernetes namespace where Prometheus is deployed (default: monitoring)
.EXAMPLE
    .\validate-observability.ps1
.EXAMPLE
    .\validate-observability.ps1 -Namespace datalake -PrometheusNamespace monitoring
#>

param(
    [string]$Namespace = "datalake",
    [string]$PrometheusNamespace = "monitoring"
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Warning-Custom { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Write-Error-Custom { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }

Write-Info "Starting Datalake Observability Validation..."
Write-Info "Datalake Namespace: $Namespace"
Write-Info "Prometheus Namespace: $PrometheusNamespace"
Write-Host ""

$validationResults = @{
    ServiceMonitors = $false
    Dashboards = $false
    PrometheusTargets = $false
    Services = $false
}

# Check if kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error-Custom "kubectl not found. Please install kubectl first."
    exit 1
}

# Check if namespaces exist
Write-Info "Validating namespaces..."
$datalakeNs = kubectl get namespace $Namespace -o jsonpath='{.metadata.name}' 2>$null
if (-not $datalakeNs) {
    Write-Error-Custom "Namespace '$Namespace' does not exist."
    exit 1
}
Write-Success "Datalake namespace exists"

$prometheusNs = kubectl get namespace $PrometheusNamespace -o jsonpath='{.metadata.name}' 2>$null
if (-not $prometheusNs) {
    Write-Warning-Custom "Prometheus namespace '$PrometheusNamespace' does not exist. Skipping Prometheus checks."
} else {
    Write-Success "Prometheus namespace exists"
}

# Validate ServiceMonitors
Write-Host ""
Write-Info "Checking ServiceMonitors..."
$serviceMonitors = kubectl get servicemonitor -n $Namespace -l component=datalake -o json 2>$null | ConvertFrom-Json

if ($serviceMonitors.items.Count -gt 0) {
    Write-Success "Found $($serviceMonitors.items.Count) ServiceMonitor(s)"
    $validationResults.ServiceMonitors = $true
    
    foreach ($sm in $serviceMonitors.items) {
        $name = $sm.metadata.name
        $service = $sm.metadata.labels.service
        Write-Info "  - $name (service: $service)"
    }
} else {
    Write-Error-Custom "No ServiceMonitors found in namespace $Namespace with label component=datalake"
    Write-Info "Run apply-observability.ps1 to create ServiceMonitors"
}

# Validate Services
Write-Host ""
Write-Info "Checking Datalake Services..."
$expectedServices = @("trino", "minio", "spark-master", "postgres", "airflow")
$servicesFound = 0

foreach ($svc in $expectedServices) {
    $service = kubectl get service $svc -n $Namespace -o jsonpath='{.metadata.name}' 2>$null
    if ($service) {
        Write-Success "  ✓ Service '$svc' exists"
        $servicesFound++
        
        # Check if service has required labels
        $labels = kubectl get service $svc -n $Namespace -o jsonpath='{.metadata.labels}' 2>$null | ConvertFrom-Json
        if ($labels.app -eq "enginedge") {
            Write-Success "    - Has required label: app=enginedge"
        } else {
            Write-Warning-Custom "    - Missing label: app=enginedge"
        }
    } else {
        Write-Warning-Custom "  ✗ Service '$svc' not found"
    }
}

if ($servicesFound -eq $expectedServices.Count) {
    $validationResults.Services = $true
    Write-Success "All expected services are deployed"
} else {
    Write-Warning-Custom "Only $servicesFound/$($expectedServices.Count) services found"
}

# Validate Grafana Dashboards
Write-Host ""
Write-Info "Checking Grafana Dashboards..."
$dashboards = kubectl get configmap -n $Namespace -l grafana_dashboard=1 -o json 2>$null | ConvertFrom-Json

if ($dashboards.items.Count -gt 0) {
    Write-Success "Found $($dashboards.items.Count) dashboard ConfigMap(s)"
    $validationResults.Dashboards = $true
    
    foreach ($dashboard in $dashboards.items) {
        $name = $dashboard.metadata.name
        Write-Info "  - $name"
    }
} else {
    Write-Warning-Custom "No Grafana dashboards found in namespace $Namespace"
    Write-Info "Run apply-observability.ps1 to create dashboards"
}

# Check Prometheus Pods
if ($prometheusNs) {
    Write-Host ""
    Write-Info "Checking Prometheus..."
    $prometheusPods = kubectl get pods -n $PrometheusNamespace -l app.kubernetes.io/name=prometheus -o json 2>$null | ConvertFrom-Json
    
    if ($prometheusPods.items.Count -gt 0) {
        $runningPods = ($prometheusPods.items | Where-Object { $_.status.phase -eq "Running" }).Count
        Write-Success "Found $runningPods/$($prometheusPods.items.Count) Prometheus pod(s) running"
        
        # Try to check Prometheus targets
        Write-Host ""
        Write-Info "Checking Prometheus targets..."
        Write-Info "To manually verify targets:"
        $promPod = $prometheusPods.items[0].metadata.name
        Write-Info "  kubectl port-forward -n $PrometheusNamespace $promPod 9090:9090"
        Write-Info "  Then visit: http://localhost:9090/targets"
        
        # Query Prometheus API if possible
        try {
            $portForwardJob = Start-Job -ScriptBlock {
                param($ns, $pod)
                kubectl port-forward -n $ns $pod 9091:9090 2>$null
            } -ArgumentList $PrometheusNamespace, $promPod
            
            Start-Sleep -Seconds 3
            
            $targets = Invoke-RestMethod -Uri "http://localhost:9091/api/v1/targets" -TimeoutSec 5
            
            if ($targets.status -eq "success") {
                $datalakeTargets = $targets.data.activeTargets | Where-Object { $_.labels.namespace -eq $Namespace }
                
                if ($datalakeTargets) {
                    Write-Success "Found $($datalakeTargets.Count) datalake target(s) in Prometheus"
                    $validationResults.PrometheusTargets = $true
                    
                    foreach ($target in $datalakeTargets) {
                        $health = $target.health
                        $job = $target.labels.job
                        $emoji = if ($health -eq "up") { "✓" } else { "✗" }
                        $color = if ($health -eq "up") { "Green" } else { "Red" }
                        Write-Host "  $emoji $job - $health" -ForegroundColor $color
                    }
                } else {
                    Write-Warning-Custom "No datalake targets found in Prometheus"
                    Write-Info "ServiceMonitors may need time to be discovered by Prometheus"
                }
            }
            
            Stop-Job -Job $portForwardJob
            Remove-Job -Job $portForwardJob
        } catch {
            Write-Warning-Custom "Could not query Prometheus API: $_"
            Write-Info "Manually verify targets using port-forward"
        }
    } else {
        Write-Warning-Custom "No Prometheus pods found in namespace $PrometheusNamespace"
    }
}

# Check Grafana
if ($prometheusNs) {
    Write-Host ""
    Write-Info "Checking Grafana..."
    $grafanaPods = kubectl get pods -n $PrometheusNamespace -l app.kubernetes.io/name=grafana -o json 2>$null | ConvertFrom-Json
    
    if ($grafanaPods.items.Count -gt 0) {
        $runningPods = ($grafanaPods.items | Where-Object { $_.status.phase -eq "Running" }).Count
        Write-Success "Found $runningPods/$($grafanaPods.items.Count) Grafana pod(s) running"
        Write-Info "To access Grafana:"
        $grafanaPod = $grafanaPods.items[0].metadata.name
        Write-Info "  kubectl port-forward -n $PrometheusNamespace $grafanaPod 3000:3000"
        Write-Info "  Then visit: http://localhost:3000"
    } else {
        Write-Warning-Custom "No Grafana pods found in namespace $PrometheusNamespace"
    }
}

# Summary
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Info "Validation Summary"
Write-Host "=" * 60 -ForegroundColor Cyan

$passedChecks = ($validationResults.Values | Where-Object { $_ -eq $true }).Count
$totalChecks = $validationResults.Count

Write-Host ""
foreach ($check in $validationResults.GetEnumerator()) {
    $status = if ($check.Value) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($check.Value) { "Green" } else { "Red" }
    Write-Host "  $status - $($check.Key)" -ForegroundColor $color
}

Write-Host ""
if ($passedChecks -eq $totalChecks) {
    Write-Success "All validation checks passed! ($passedChecks/$totalChecks)"
    Write-Host ""
    Write-Info "Next Steps:"
    Write-Info "1. Access Grafana and verify dashboards are visible"
    Write-Info "2. Run smoke tests on Trino and Spark"
    Write-Info "3. Monitor the dashboards for any issues"
    exit 0
} else {
    Write-Warning-Custom "Some validation checks failed ($passedChecks/$totalChecks passed)"
    Write-Host ""
    Write-Info "Troubleshooting:"
    Write-Info "1. Ensure all datalake services are deployed: helm list -n $Namespace"
    Write-Info "2. Check pod status: kubectl get pods -n $Namespace"
    Write-Info "3. Run apply-observability.ps1 to create/update observability resources"
    Write-Info "4. Wait a few minutes for Prometheus to discover new targets"
    exit 1
}

# Quick Start: Datalake Observability

This guide will help you quickly deploy and validate the observability setup for the EnginEdge Datalake.

## Prerequisites

- Kubernetes cluster with datalake deployed
- Prometheus Operator installed
- Grafana installed (with dashboard sidecar enabled)
- kubectl configured

## Step 1: Deploy ServiceMonitors and Dashboards

```powershell
# Navigate to the datalake directory
cd enginedge-splitrepos\enginedge-datalake

# Apply observability resources
.\scripts\apply-observability.ps1

# Expected output:
# ℹ️  Starting Datalake Observability Setup...
# ℹ️  Namespace: datalake
# ℹ️  Applying ServiceMonitors...
# ✅ Applied ServiceMonitor: trino
# ✅ Applied ServiceMonitor: minio
# ✅ Applied ServiceMonitor: spark-master
# ✅ Applied ServiceMonitor: postgres
# ✅ Applied ServiceMonitor: airflow
# ✅ 5 ServiceMonitors applied successfully
# ✅ Grafana dashboards applied successfully
```

## Step 2: Validate the Setup

```powershell
# Run validation script
.\scripts\validate-observability.ps1

# Expected output:
# ✅ All validation checks passed! (4/4)
```

## Step 3: Access Grafana Dashboards

```powershell
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Open your browser to: http://localhost:3000
# Login with your Grafana credentials
# Navigate to Dashboards > Browse
# Look for "EnginEdge Datalake" dashboards
```

### Available Dashboards

1. **EnginEdge Datalake - Trino**
   - Query execution metrics
   - Memory usage
   - Query rates and latencies

2. **EnginEdge Datalake - MinIO**
   - Storage capacity
   - S3 API metrics
   - Network throughput

3. **EnginEdge Datalake - Spark**
   - Worker status
   - CPU and memory
   - Task execution

4. **EnginEdge Datalake - PostgreSQL**
   - Connections
   - Transactions
   - Cache hit ratio

5. **EnginEdge Datalake - Airflow**
   - DAG status
   - Task completion
   - Scheduler health

## Step 4: Verify Prometheus Targets

```powershell
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Open your browser to: http://localhost:9090/targets
# Search for "datalake" to see all targets
# All targets should show status: UP
```

### Expected Targets

- `datalake-trino` - Status: UP
- `datalake-minio` - Status: UP
- `datalake-spark` - Status: UP
- `datalake-postgres` - Status: UP
- `datalake-airflow` - Status: UP

## Step 5: Test Metrics

Test individual service metrics endpoints:

### Trino Metrics
```powershell
kubectl port-forward -n datalake svc/trino 8080:8080
curl http://localhost:8080/v1/metrics
```

### MinIO Metrics
```powershell
kubectl port-forward -n datalake svc/minio 9000:9000
curl http://localhost:9000/minio/v2/metrics/cluster
```

### PostgreSQL Metrics
```powershell
kubectl port-forward -n datalake svc/postgres 9187:9187
curl http://localhost:9187/metrics
```

## Troubleshooting

### ServiceMonitors not discovered

**Problem**: Prometheus doesn't show datalake targets

**Solution**:
```powershell
# Check if ServiceMonitors exist
kubectl get servicemonitor -n datalake

# Check Prometheus configuration
kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorSelector

# Ensure labels match
kubectl get servicemonitor -n datalake --show-labels
```

### Dashboards not showing in Grafana

**Problem**: Grafana doesn't show new dashboards

**Solution**:
```powershell
# Check if ConfigMaps exist
kubectl get configmap -n datalake -l grafana_dashboard=1

# Verify Grafana sidecar is enabled
kubectl get deployment -n monitoring grafana -o yaml | grep -A 5 sidecar

# Restart Grafana
kubectl rollout restart -n monitoring deployment/grafana
```

### Metrics showing "N/A" or no data

**Problem**: Dashboards show no data

**Solution**:
```powershell
# Check if services are running
kubectl get pods -n datalake

# Check service logs
kubectl logs -n datalake deployment/trino
kubectl logs -n datalake deployment/minio
kubectl logs -n datalake deployment/spark-master

# Verify metrics endpoints are accessible
kubectl exec -n datalake deployment/trino -- curl localhost:8080/v1/metrics
```

## Integration with Helm

If you're using the Helm chart, enable ServiceMonitors in your `values.yaml`:

```yaml
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s

trino:
  metrics:
    enabled: true

minio:
  metrics:
    enabled: true

spark:
  metrics:
    enabled: true

postgres:
  metrics:
    enabled: true

airflow:
  metrics:
    enabled: true
```

Then upgrade your release:

```powershell
helm upgrade datalake ./helm/datalake -n datalake -f values.yaml
```

## Next Steps

After validating observability:

1. ✅ ServiceMonitors applied and Prometheus scraping
2. ✅ Dashboards visible in Grafana
3. ⏭️ Run smoke tests (Trino queries, Spark jobs)
4. ⏭️ Set up alerts for critical metrics
5. ⏭️ Configure retention policies

## Useful Commands

```powershell
# List all ServiceMonitors
kubectl get servicemonitor -n datalake

# Describe a specific ServiceMonitor
kubectl describe servicemonitor datalake-trino -n datalake

# View dashboard ConfigMaps
kubectl get configmap -n datalake -l grafana_dashboard=1

# Check Prometheus scrape config
kubectl get prometheus -n monitoring -o yaml

# View Prometheus targets via API
kubectl port-forward -n monitoring svc/prometheus 9090:9090
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.namespace=="datalake")'
```

## Additional Resources

- Full documentation: `k8s/observability/README.md`
- Apply script: `scripts/apply-observability.ps1`
- Validation script: `scripts/validate-observability.ps1`
- Dashboard YAMLs: `k8s/observability/dashboards/`

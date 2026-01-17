# EnginEdge Datalake Observability

This directory contains observability resources for monitoring the EnginEdge Datalake components.

## Contents

### ServiceMonitors
ServiceMonitors are created automatically by the `apply-observability.ps1` script for:
- **Trino**: Query engine metrics (`/v1/metrics`)
- **MinIO**: S3-compatible storage metrics (`/minio/v2/metrics/cluster`)
- **Spark**: Master and worker metrics (JMX exporter)
- **PostgreSQL**: Database metrics (postgres_exporter)
- **Airflow**: Workflow orchestration health (`/health`)

### Dashboards
Grafana dashboards are provided for comprehensive monitoring:

1. **Trino Dashboard** (`trino-dashboard.yaml`)
   - Query execution status
   - Memory usage
   - Query submission rate
   - P95 execution time

2. **MinIO Dashboard** (`minio-dashboard.yaml`)
   - Storage capacity and utilization
   - S3 API request rate
   - Network throughput
   - API errors

3. **Spark Dashboard** (`spark-dashboard.yaml`)
   - Worker status
   - CPU cores and memory usage
   - Driver event bus
   - Executor tasks and spill

4. **PostgreSQL Dashboard** (`postgres-dashboard.yaml`)
   - Connection status
   - Transaction rate
   - Tuple operations
   - Cache hit ratio
   - Deadlocks and conflicts
   - Database size

5. **Airflow Dashboard** (`airflow-dashboard.yaml`)
   - DAG status
   - Task execution
   - Scheduler health
   - Pool slot usage

## Usage

### Deploy Observability Resources

```powershell
# Apply ServiceMonitors and dashboards
.\scripts\apply-observability.ps1

# Dry-run to see what would be applied
.\scripts\apply-observability.ps1 -DryRun

# Apply to a different namespace
.\scripts\apply-observability.ps1 -Namespace my-datalake
```

### Validate Setup

```powershell
# Validate that everything is configured correctly
.\scripts\validate-observability.ps1

# Validate with custom namespaces
.\scripts\validate-observability.ps1 -Namespace datalake -PrometheusNamespace monitoring
```

### Access Dashboards

1. **Port-forward to Grafana**:
   ```powershell
   kubectl port-forward -n monitoring svc/grafana 3000:3000
   ```

2. **Open Grafana**: http://localhost:3000

3. **Find Dashboards**: Look for dashboards with "EnginEdge Datalake" prefix

### Check Prometheus Targets

1. **Port-forward to Prometheus**:
   ```powershell
   kubectl port-forward -n monitoring svc/prometheus 9090:9090
   ```

2. **Open Prometheus**: http://localhost:9090/targets

3. **Verify Targets**: Look for `datalake-*` targets showing "UP" status

## Metrics Endpoints

Each service exposes metrics on specific paths:

| Service    | Port | Path                         | Format     |
|------------|------|------------------------------|------------|
| Trino      | 8080 | `/v1/metrics`                | Prometheus |
| MinIO      | 9000 | `/minio/v2/metrics/cluster`  | Prometheus |
| Spark      | 9090 | `/metrics` (JMX)             | Prometheus |
| PostgreSQL | 9187 | `/metrics` (exporter)        | Prometheus |
| Airflow    | 8080 | `/health`                    | JSON       |

## Troubleshooting

### ServiceMonitors Not Discovered

1. Check that Prometheus Operator is installed:
   ```powershell
   kubectl get crd servicemonitors.monitoring.coreos.com
   ```

2. Verify ServiceMonitor labels match Prometheus selector:
   ```powershell
   kubectl get prometheus -n monitoring -o yaml
   ```

3. Check Prometheus logs:
   ```powershell
   kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
   ```

### Dashboards Not Appearing in Grafana

1. Ensure Grafana has sidecar enabled for dashboard discovery:
   ```yaml
   sidecar:
     dashboards:
       enabled: true
       label: grafana_dashboard
   ```

2. Check dashboard ConfigMaps:
   ```powershell
   kubectl get configmap -n datalake -l grafana_dashboard=1
   ```

3. Restart Grafana to force dashboard reload:
   ```powershell
   kubectl rollout restart -n monitoring deployment/grafana
   ```

### Metrics Not Showing

1. Verify services are running:
   ```powershell
   kubectl get pods -n datalake
   ```

2. Test metrics endpoint directly:
   ```powershell
   kubectl port-forward -n datalake svc/trino 8080:8080
   curl http://localhost:8080/v1/metrics
   ```

3. Check service labels:
   ```powershell
   kubectl get svc -n datalake --show-labels
   ```

## Integration with Helm Chart

The datalake Helm chart includes ServiceMonitor templates that can be enabled:

```yaml
# values.yaml
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
  labels:
    prometheus: kube-prometheus

# Enable metrics for each service
trino:
  metrics:
    enabled: true
    path: /v1/metrics

minio:
  metrics:
    enabled: true
    path: /minio/v2/metrics/cluster

spark:
  metrics:
    enabled: true
    jmxExporter:
      image: bitnami/jmx-exporter:0.17.2

postgres:
  metrics:
    enabled: true
    exporter:
      image: prometheuscommunity/postgres-exporter:v0.11.1

airflow:
  metrics:
    enabled: true
    path: /health
```

## Custom Metrics

To add custom metrics or modify existing dashboards:

1. Edit the dashboard YAML files in `k8s/observability/dashboards/`
2. Apply changes: `kubectl apply -f k8s/observability/dashboards/`
3. Reload Grafana or wait for sidecar to sync

## References

- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Dashboard JSON Model](https://grafana.com/docs/grafana/latest/dashboards/json-model/)
- [Trino Metrics](https://trino.io/docs/current/admin/jmx.html)
- [MinIO Metrics](https://min.io/docs/minio/linux/operations/monitoring/collect-minio-metrics-using-prometheus.html)
- [Spark Monitoring](https://spark.apache.org/docs/latest/monitoring.html)

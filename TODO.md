# Datalake TODO (K8s, Observability, CI/CD)

## K8s Manifests / Helm
- Create Helm chart(s) or manifests for core services (Trino, Spark, Airflow, Postgres, MinIO) matching compose config
- Add Services with labels (app: enginedge, component: <svc>) and expose health/metrics where available
- Add values files for local cluster (storage classes / PVs)

## Observability
- Expose Prometheus metrics endpoints (where supported) for ServiceMonitors:
  - Trino: /v1/metrics (configure Prometheus JMX exporter if needed)
  - Spark: JMX exporter sidecar for driver/executors
  - Airflow: /health (/metrics via exporter if desired)
  - MinIO: /minio/v2/metrics/cluster
  - Postgres: postgres_exporter sidecar
- Create ServiceMonitors under enginedge-core/platform/k8s/observability/servicemonitors/
- Add Grafana dashboards (ConfigMaps) for Trino/Spark/MinIO/Postgres

## Storage & Secrets
- Define PVCs/SCs for Postgres, MinIO buckets
- Kubernetes Secrets for database creds, MinIO keys (reuse minio-secret if shared)

## Networking
- Optional Ingress for Airflow/Trino UIs (auth-protect if exposed)

## CI/CD
- Add GitHub Actions deploy job: build/push images (if custom) and helm upgrade --install for datalake chart(s)
- Add docker compose config validation (already present)

## Integration with Core
- Ensure data-processing-worker and scheduling-model envs point to Trino/S3 endpoints when applicable
- Ensure API Gateway does not expose datalake UIs publicly (admin-only)

## Rollout Steps
- Helm install datalake chart(s)
- Apply ServiceMonitors and dashboards
- Validate Prometheus targets up, Grafana dashboards render
- Run smoke queries (Trino) and basic Spark job

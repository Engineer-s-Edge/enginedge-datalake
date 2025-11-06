# Datalake TODO (K8s, Observability, CI/CD)

## K8s Manifests / Helm
- Create Helm chart(s) or manifests for core services (Trino, Spark, Airflow, Postgres, MinIO) matching compose config
- Add Services with labels (app: enginedge, component: <svc>) and expose health/metrics where available
- Add values files for local cluster (storage classes / PVs)

## Storage & Secrets
- Define PVCs/SCs for Postgres, MinIO buckets
- Kubernetes Secrets for database creds, MinIO keys (reuse minio-secret if shared)

## Networking
- Optional Ingress for Airflow/Trino UIs (auth-protect if exposed)

## CI/CD
- Add GitHub Actions deploy job: build/push images (if custom) and helm upgrade --install for datalake chart(s)
- Add docker compose config validation (already present)

## Rollout Steps
- Helm install datalake chart(s)
- Apply ServiceMonitors and dashboards
- Validate Prometheus targets up, Grafana dashboards render
- Run smoke queries (Trino) and basic Spark job

## Todo List

*   [ ] Add a CI/CD pipeline to the repository to automate testing and deployment.
*   [ ] Add a testing framework to the repository to test the data lake components.
*   [ ] Add a monitoring solution to the repository to monitor the data lake components.
*   [ ] Add a logging solution to the repository to log the data lake components.


## In Progress

*   [ ] Add a data lineage solution to the repository to track the lineage of the data in the data lake.


## Completed

*   [x] Create a `docker-compose.yml` file to define the services.
*   [x] Fix the launch scripts to ensure they correctly use the `docker-compose.yml` file.
*   [x] Address the hardcoded credentials by creating a `.env.example` file and updating the `README.md` and launch scripts.
*   [x] Update the `README.md` to reflect the correct directory structure and remove references to the non-existent `datalake/` directory.
*   [X] Add a `LICENSE` file to the repository.
*   [X] Add a `CONTRIBUTING.md` file to the repository.
*   [X] Add a `.dockerignore` file to the repository.
*   [X] Add a data quality solution to the repository to ensure the quality of the data in the data lake.
*   [X] Add a linter to the repository to enforce code quality.
*   [X] Convert datalake from compose based to k8 based
*   [X] Add a data discovery solution to the repository to discover the data in the data lake.
*   [X] Add a data governance solution to the repository to govern the data in the data lake.
## Observability
- [x] Expose Prometheus metrics endpoints (where supported) for ServiceMonitors:
  - [x] Trino: /v1/metrics (configure Prometheus JMX exporter if needed)
  - [x] Spark: JMX exporter sidecar for driver/executors
  - [x] Airflow: /health (/metrics via exporter if desired)
  - [x] MinIO: /minio/v2/metrics/cluster
  - [x] Postgres: postgres_exporter sidecar
- [x] Create ServiceMonitors under enginedge-core/platform/k8s/observability/servicemonitors/
- [x] Add Grafana dashboards (ConfigMaps) for Trino/Spark/MinIO/Postgres
## Integration with Core
- Ensure data-processing-worker and scheduling-model envs point to Trino/S3 endpoints when applicable
- [x] Ensure API Gateway does not expose datalake UIs publicly (admin-only)
- [x] Create observability API endpoint for datalake health/metrics monitoring
- [x] Integrate datalake into API Gateway with role-based access control
# Datalake TODO (K8s, Observability, CI/CD)

## Storage & Secrets
- Define PVCs/SCs for Postgres, MinIO buckets
- Kubernetes Secrets for database creds, MinIO keys (reuse minio-secret if shared)

## Rollout Steps
- Helm install datalake chart(s)
- Apply ServiceMonitors and dashboards
- Validate Prometheus targets up, Grafana dashboards render
- Run smoke queries (Trino) and basic Spark job

## Todo List

## In Progress

## K8s Manifests / Helm
- Add values files for local cluster (storage classes / PVs)

## Completed

  ## K8s Manifests / Helm
  - [x] Add Services with labels (app: enginedge, component: <svc>) and expose health/metrics where available
    - Updated all service manifests with explicit `app: enginedge` and `component: <service-name>` labels
    - Exposed metrics endpoints for MinIO (/minio/v2/metrics/cluster on port 9000)
    - Exposed metrics endpoints for Trino (/v1/metrics on port 8080)
    - Exposed health endpoints for Airflow (/health on port 8080)
    - Exposed metrics endpoints for Spark Master and Worker (JMX exporter on port 9090)
    - PostgreSQL metrics already configured with postgres_exporter on port 9187
    - All services now have consistent labeling for Prometheus ServiceMonitor discovery
  - [x] Create Helm chart(s) or manifests for core services (Trino, Spark, Airflow, Postgres, MinIO) matching compose config
    - Created comprehensive Helm chart in helm/datalake/
    - Includes all core services: MinIO, PostgreSQL, Hive Metastore, Trino, Spark, Airflow
    - Complete with deployments, services, configmaps, secrets, and PVCs
    - Configurable values.yaml with sensible defaults
    - Environment-specific values files (values-dev.yaml, values-prod.yaml)
    - Deployment script (deploy.ps1) for easy installation
    - ServiceMonitor templates for Prometheus integration
    - Comprehensive README.md with usage examples
    - All services labeled with app: enginedge and component-specific labels
    - Health checks and metrics endpoints configured where supported

  ## Networking
  - [x] Optional Ingress for Airflow/Trino UIs (auth-protect if exposed)
    - Created ingress.yml with Basic Auth using htpasswd
    - Created ingress-oauth2.yml with OAuth2 Proxy for enterprise SSO
    - Implemented NetworkPolicies for additional security
    - Added rate limiting and IP whitelisting support
    - Comprehensive INGRESS_README.md with setup instructions
    - Support for Google, GitHub, Azure AD, Okta authentication
    - TLS/SSL configuration with cert-manager integration
    - Security headers and timeout configurations

*   [X] Add a logging solution to the repository to log the data lake components.
    - Implemented Winston-based logging solution from EnginEdge monorepo
    - MyLogger service with pretty console output and file rotation
    - RequestContextService for request ID tracking across async operations
    - HttpLoggerMiddleware for automatic HTTP request/response logging
    - Supports multiple log levels, redaction of sensitive data, file rotation, and Sentry integration
    - Configurable via environment variables (LOG_LEVEL, LOG_DIR, LOG_ENABLE_CONSOLE, LOG_ENABLE_FILES, etc.)
    
*   [X] Add a data lineage solution to the repository to track the lineage of the data in the data lake.
    - Marquez (OpenLineage backend) for lineage storage and API
    - Tokern for data governance and lineage visualization
    - OpenLineage integration with Spark and Airflow
    - Comprehensive documentation in DATA_LINEAGE.md
    - Example Spark jobs demonstrating lineage tracking
    - Example Airflow DAG with lineage tracking
    - Jupyter notebook for querying and visualizing lineage
    - Python SDK examples for programmatic lineage tracking

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
*   [X] Add a monitoring solution to the repository to monitor the data lake components.
*   [X] Add a testing framework to the repository to test the data lake components.
*   [X] Add a CI/CD pipeline to the repository to automate testing and deployment.
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
## CI/CD
- [x] Add GitHub Actions deploy job: build/push images (if custom)
- [X] helm upgrade --install for datalake chart(s)
- [x] Add docker compose config validation (already present)

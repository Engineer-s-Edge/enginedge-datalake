# Helm Chart Validation Checklist

Use this checklist to validate the Helm chart before deployment.

## Pre-Installation Validation

### Prerequisites Check
- [ ] Kubernetes cluster is running and accessible
  ```powershell
  kubectl cluster-info
  ```
- [ ] Helm 3.x is installed
  ```powershell
  helm version
  ```
- [ ] kubectl can access the cluster
  ```powershell
  kubectl get nodes
  ```

### Chart Validation
- [ ] Validate chart syntax
  ```powershell
  cd c:\Users\pluki.DESKTOP-T55TG3J\Engineering\enginedge-splitrepos\enginedge-datalake\helm\datalake
  helm lint .
  ```
- [ ] Render templates (dry-run)
  ```powershell
  helm template datalake . --debug
  ```
- [ ] Check for required values
  ```powershell
  helm show values .
  ```

## Installation Validation

### Deploy Chart
- [ ] Install with dry-run first
  ```powershell
  .\deploy.ps1 -DryRun
  ```
- [ ] Review generated manifests
- [ ] Install chart (development)
  ```powershell
  .\deploy.ps1 -ValuesFile values-dev.yaml
  ```

### Resource Creation Check
- [ ] Verify namespace created
  ```powershell
  kubectl get namespace datalake
  ```
- [ ] Check all deployments
  ```powershell
  kubectl get deployments -n datalake
  ```
- [ ] Verify all services
  ```powershell
  kubectl get svc -n datalake
  ```
- [ ] Check secrets created
  ```powershell
  kubectl get secrets -n datalake
  ```
- [ ] Verify configmaps
  ```powershell
  kubectl get configmaps -n datalake
  ```

## Service-Specific Validation

### MinIO
- [ ] Deployment created
  ```powershell
  kubectl get deployment -n datalake -l app.kubernetes.io/component=minio
  ```
- [ ] Pod is running
  ```powershell
  kubectl get pods -n datalake -l app.kubernetes.io/component=minio
  ```
- [ ] Service accessible
  ```powershell
  kubectl get svc -n datalake minio
  ```
- [ ] PVC created (if persistence enabled)
  ```powershell
  kubectl get pvc -n datalake | grep minio
  ```
- [ ] Test access
  ```powershell
  kubectl port-forward -n datalake svc/minio 9001:9001
  # Access http://localhost:9001
  ```

### PostgreSQL
- [ ] Deployment created
- [ ] Pod is running
  ```powershell
  kubectl get pods -n datalake -l app.kubernetes.io/component=postgres
  ```
- [ ] Service accessible
- [ ] PVC created (if persistence enabled)
- [ ] Database initialized
  ```powershell
  kubectl logs -n datalake -l app.kubernetes.io/component=postgres | grep "database system is ready"
  ```
- [ ] Test connection
  ```powershell
  kubectl exec -n datalake -it deploy/datalake-postgres -- psql -U airflow -d airflow -c "\l"
  ```

### Hive Metastore
- [ ] Deployment created
- [ ] Pod is running
  ```powershell
  kubectl get pods -n datalake -l app.kubernetes.io/component=hive-metastore
  ```
- [ ] Service accessible
- [ ] Connected to PostgreSQL
  ```powershell
  kubectl logs -n datalake -l app.kubernetes.io/component=hive-metastore
  ```

### Trino
- [ ] Deployment created
- [ ] Pod is running
  ```powershell
  kubectl get pods -n datalake -l app.kubernetes.io/component=trino
  ```
- [ ] Service accessible
- [ ] Web UI accessible
  ```powershell
  kubectl port-forward -n datalake svc/trino 8080:8080
  # Access http://localhost:8080
  ```
- [ ] Test query
  ```powershell
  kubectl exec -n datalake -it deploy/datalake-trino -- trino --execute "SHOW CATALOGS;"
  ```
- [ ] Hive catalog configured
  ```powershell
  kubectl exec -n datalake -it deploy/datalake-trino -- trino --execute "SHOW SCHEMAS FROM hive;"
  ```

### Spark
- [ ] Master deployment created
- [ ] Worker deployment created
- [ ] Master pod running
  ```powershell
  kubectl get pods -n datalake -l app.kubernetes.io/component=spark-master
  ```
- [ ] Worker pods running
  ```powershell
  kubectl get pods -n datalake -l app.kubernetes.io/component=spark-worker
  ```
- [ ] Master UI accessible
  ```powershell
  kubectl port-forward -n datalake svc/spark-master 8083:8080
  # Access http://localhost:8083
  ```
- [ ] Workers connected to master
  ```powershell
  # Check Spark Master UI for registered workers
  ```

### Airflow
- [ ] Deployment created
- [ ] Pod is running
  ```powershell
  kubectl get pods -n datalake -l app.kubernetes.io/component=airflow
  ```
- [ ] Service accessible
- [ ] Database initialized
  ```powershell
  kubectl logs -n datalake -l app.kubernetes.io/component=airflow | grep "Database migrations have been executed"
  ```
- [ ] Web UI accessible
  ```powershell
  kubectl port-forward -n datalake svc/airflow 8082:8080
  # Access http://localhost:8082
  ```
- [ ] Can login with default credentials
  - Username: admin
  - Password: admin123
- [ ] PVCs created (if persistence enabled)

## Health Check Validation

### Liveness Probes
- [ ] MinIO liveness probe passing
  ```powershell
  kubectl describe pod -n datalake -l app.kubernetes.io/component=minio | grep -A 5 "Liveness"
  ```
- [ ] PostgreSQL liveness probe passing
- [ ] Trino liveness probe passing
- [ ] Spark liveness probes passing
- [ ] Airflow liveness probe passing

### Readiness Probes
- [ ] All readiness probes passing
  ```powershell
  kubectl get pods -n datalake
  # Check READY column shows correct fraction
  ```

## Configuration Validation

### Secrets
- [ ] MinIO secret has root-user and root-password
  ```powershell
  kubectl get secret -n datalake datalake-minio-secret -o jsonpath='{.data}' | ConvertFrom-Json
  ```
- [ ] PostgreSQL secret has all required keys
- [ ] Airflow secret has webserver credentials

### ConfigMaps
- [ ] PostgreSQL init scripts present
  ```powershell
  kubectl get configmap -n datalake datalake-postgres-init -o yaml
  ```
- [ ] Trino config present
  ```powershell
  kubectl get configmap -n datalake datalake-trino-config -o yaml
  ```
- [ ] Trino catalog config present
  ```powershell
  kubectl get configmap -n datalake datalake-trino-catalog -o yaml
  ```

### Labels
- [ ] All resources have `app: enginedge` label
  ```powershell
  kubectl get all -n datalake -l app=enginedge
  ```
- [ ] All resources have component labels
  ```powershell
  kubectl get all -n datalake -l app.kubernetes.io/component
  ```

## Integration Testing

### Service-to-Service Communication
- [ ] Trino can connect to Hive Metastore
  ```powershell
  kubectl logs -n datalake -l app.kubernetes.io/component=trino | grep "hive-metastore"
  ```
- [ ] Hive Metastore can connect to PostgreSQL
- [ ] Trino can access MinIO via Hive catalog
  ```powershell
  # Create test table in Trino and verify MinIO has the data
  ```
- [ ] Airflow can connect to PostgreSQL
- [ ] Spark workers can connect to master

### Data Flow Test
- [ ] Create bucket in MinIO
  ```powershell
  # Via MinIO console at http://localhost:9001
  ```
- [ ] Create table in Trino pointing to MinIO
  ```sql
  CREATE SCHEMA hive.test WITH (location = 's3a://test/');
  CREATE TABLE hive.test.example (id int, name varchar);
  INSERT INTO hive.test.example VALUES (1, 'test');
  ```
- [ ] Query table from Trino
- [ ] Submit Spark job (if applicable)

## Monitoring Validation (Optional)

### Metrics Endpoints
- [ ] MinIO metrics available
  ```powershell
  kubectl port-forward -n datalake svc/minio 9000:9000
  curl http://localhost:9000/minio/v2/metrics/cluster
  ```
- [ ] PostgreSQL exporter metrics available
- [ ] Trino metrics available

### ServiceMonitors (if enabled)
- [ ] ServiceMonitor resources created
  ```powershell
  kubectl get servicemonitors -n datalake
  ```
- [ ] Prometheus scraping targets

## Documentation Check

- [ ] README.md present and complete
- [ ] QUICKSTART.md present and clear
- [ ] NOTES.txt renders correctly
  ```powershell
  helm get notes datalake -n datalake
  ```
- [ ] All example values files present
  - [ ] values-dev.yaml
  - [ ] values-prod.yaml

## Clean Up Test

- [ ] Uninstall chart
  ```powershell
  helm uninstall datalake -n datalake
  ```
- [ ] Verify resources deleted
  ```powershell
  kubectl get all -n datalake
  ```
- [ ] PVCs handling correct
  ```powershell
  kubectl get pvc -n datalake
  # Should be deleted unless retention policy set
  ```
- [ ] Re-install works
  ```powershell
  .\deploy.ps1 -ValuesFile values-dev.yaml
  ```

## Production Readiness

### Security
- [ ] No hardcoded passwords in templates
- [ ] All credentials in Secrets
- [ ] Resource limits set
- [ ] Security contexts defined (if needed)

### High Availability
- [ ] Multiple replicas for stateless services (production values)
- [ ] Anti-affinity rules (if needed)
- [ ] PodDisruptionBudgets (optional)

### Observability
- [ ] Logging configured
- [ ] Metrics exposed
- [ ] Health checks implemented
- [ ] ServiceMonitors available

### Scalability
- [ ] Replica counts configurable
- [ ] Resource requests/limits set
- [ ] HPA ready (if needed)

## Sign-Off

| Category | Status | Notes | Validator | Date |
|----------|--------|-------|-----------|------|
| Chart Syntax | ⬜ | | | |
| Installation | ⬜ | | | |
| MinIO | ⬜ | | | |
| PostgreSQL | ⬜ | | | |
| Hive Metastore | ⬜ | | | |
| Trino | ⬜ | | | |
| Spark | ⬜ | | | |
| Airflow | ⬜ | | | |
| Health Checks | ⬜ | | | |
| Configuration | ⬜ | | | |
| Integration | ⬜ | | | |
| Documentation | ⬜ | | | |
| Production Ready | ⬜ | | | |

## Notes

- Mark items with ✅ when validated
- Document any issues found
- Create GitHub issues for any bugs
- Update this checklist based on findings

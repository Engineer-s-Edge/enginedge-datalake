# EnginEdge Datalake - API Gateway Integration

## Overview

This document describes the integration between the EnginEdge Datalake and the API Gateway, including observability endpoints and admin-only access controls.

## Architecture

```
┌─────────────────┐
│   API Gateway   │
│   (Port 3001)   │
└────────┬────────┘
         │
         ├─ /datalake/minio/*    ─────┐
         ├─ /datalake/trino/*    ─────┤ Admin-Only
         ├─ /datalake/airflow/*  ─────┤ JWT + Role Check
         ├─ /datalake/jupyter/*  ─────┤
         ├─ /datalake/spark/*    ─────┤
         └─ /datalake/marquez/*  ─────┘
                   │
         ┌─────────▼────────────┐
         │  Datalake Services   │
         │  - MinIO (Storage)   │
         │  - Trino (Query)     │
         │  - Airflow (ETL)     │
         │  - Spark (Process)   │
         │  - Jupyter (Analysis)│
         │  - Marquez (Lineage) │
         └──────────────────────┘
```

## Features

### 1. Admin-Only Access Control

All datalake UI endpoints are protected by:
- **JWT Authentication** (`JwtAuthGuard`)
- **Role-Based Authorization** (`RolesGuard`)
- **Required Role**: `admin`

```typescript
@Controller('datalake')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class DatalakeProxyController {
  // All endpoints require admin role
}
```

### 2. Observability API

The datalake exposes health and metrics endpoints for monitoring:

#### Health Endpoint
```
GET /api/observability/health
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-04T10:00:00Z",
  "services": {
    "minio": { "status": "healthy", "endpoint": "http://minio:9000" },
    "trino": { "status": "healthy", "endpoint": "http://trino:8080" },
    "airflow": { "status": "healthy", "endpoint": "http://airflow:8080" },
    "spark": { "status": "healthy", "endpoint": "http://spark-master:8080" },
    "postgres": { "status": "healthy", "endpoint": "postgres:5432" },
    "marquez": { "status": "healthy", "endpoint": "http://marquez-api:5000" }
  }
}
```

#### Metrics Endpoint
```
GET /api/observability/metrics
```

Response:
```json
{
  "datalake_services_up": 6,
  "datalake_storage_buckets": 0,
  "datalake_active_queries": 0,
  "timestamp": "2025-11-04T10:00:00Z"
}
```

### 3. Prometheus Integration

ServiceMonitors are configured for each datalake component:
- `datalake-minio-servicemonitor.yaml` - MinIO cluster metrics
- `datalake-trino-servicemonitor.yaml` - Trino query metrics
- `datalake-airflow-servicemonitor.yaml` - Airflow DAG metrics
- `datalake-spark-servicemonitor.yaml` - Spark job metrics
- `datalake-observability-servicemonitor.yaml` - Overall health metrics

### 4. Grafana Dashboard

A comprehensive Grafana dashboard is available at:
- **ConfigMap**: `datalake-overview-dashboard.yaml`
- **Panels**:
  - Datalake Services Health
  - MinIO Storage Buckets
  - Trino Active Queries
  - MinIO Cluster Metrics
  - Airflow DAG Runs
  - Spark Jobs

## API Gateway Routes

### Datalake UI Proxying (Admin-Only)

| Endpoint | Target Service | Description |
|----------|---------------|-------------|
| `/datalake/minio/*` | MinIO Console (9001) | Object storage UI |
| `/datalake/trino/*` | Trino (8080) | SQL query engine UI |
| `/datalake/airflow/*` | Airflow (8080) | Workflow orchestration UI |
| `/datalake/jupyter/*` | Jupyter (8888) | Interactive analytics |
| `/datalake/spark/*` | Spark Master (8080) | Data processing UI |
| `/datalake/marquez/*` | Marquez Web (3000) | Data lineage UI |

**Security**: All endpoints require:
1. Valid JWT token in `Authorization: Bearer <token>` header
2. User must have `admin` role in JWT payload

### Example Request

```bash
# Get JWT token with admin role
curl -X POST http://api-gateway:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Access MinIO UI (admin only)
curl http://api-gateway:3001/datalake/minio/login \
  -H "Authorization: Bearer <token>"
```

### Error Responses

```json
// Missing token
{
  "statusCode": 401,
  "message": "Missing token"
}

// Invalid token
{
  "statusCode": 401,
  "message": "Invalid token"
}

// Non-admin user
{
  "statusCode": 403,
  "message": "Insufficient permissions"
}
```

## Environment Variables

### API Gateway
```bash
# Datalake service endpoints
MINIO_CONSOLE_URL=http://minio:9001
TRINO_URL=http://trino:8080
AIRFLOW_URL=http://airflow:8080
JUPYTER_URL=http://jupyter:8888
SPARK_MASTER_URL=http://spark-master:8080
MARQUEZ_WEB_URL=http://marquez-web:3000
```

### Datalake Observability API
```bash
PORT=3010
MINIO_ENDPOINT=http://minio:9000
TRINO_URL=http://trino:8080
AIRFLOW_URL=http://airflow:8080
SPARK_MASTER_URL=http://spark-master:8080
POSTGRES_URL=postgres:5432
MARQUEZ_API_URL=http://marquez-api:5000
```

## Deployment

### Docker Compose
```yaml
datalake-observability:
  build: ./datalake
  ports:
    - "3010:3010"
  environment:
    - PORT=3010
    - MINIO_ENDPOINT=http://minio:9000
    - TRINO_URL=http://trino:8080
    - AIRFLOW_URL=http://airflow:8080
    - SPARK_MASTER_URL=http://spark-master:8080
  networks:
    - datalake-network
```

### Kubernetes
```bash
# Apply ServiceMonitors
kubectl apply -f platform/k8s/observability/servicemonitors/datalake-*.yaml

# Apply Grafana Dashboard
kubectl apply -f platform/k8s/observability/dashboards/datalake-overview-dashboard.yaml

# Deploy datalake observability API
kubectl apply -f platform/k8s/apps/datalake-observability/
```

## Testing

### Health Check
```bash
curl http://localhost:3010/api/observability/health
```

### Metrics
```bash
curl http://localhost:3010/api/observability/metrics
```

### Admin Access (via API Gateway)
```bash
# Login as admin
TOKEN=$(curl -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' \
  | jq -r '.accessToken')

# Access MinIO UI
curl http://localhost:3001/datalake/minio/ \
  -H "Authorization: Bearer $TOKEN"
```

### Non-Admin Access (should fail)
```bash
# Login as regular user
TOKEN=$(curl -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user","password":"user"}' \
  | jq -r '.accessToken')

# Try to access MinIO UI (should return 403)
curl http://localhost:3001/datalake/minio/ \
  -H "Authorization: Bearer $TOKEN"
# Response: {"statusCode":403,"message":"Insufficient permissions"}
```

## Security Considerations

1. **JWT Tokens**: Ensure JWT_SECRET is properly secured in production
2. **Role Management**: Only grant admin role to trusted users
3. **Network Policies**: Restrict direct access to datalake services
4. **TLS/HTTPS**: Enable TLS for all external-facing endpoints
5. **Rate Limiting**: API Gateway includes rate limiting for all endpoints
6. **Audit Logging**: All admin access is logged with user ID and timestamp

## Monitoring Alerts

Recommended Prometheus alerts:

```yaml
- alert: DatalakeServiceDown
  expr: datalake_services_up < 6
  for: 5m
  annotations:
    summary: "Datalake service is down"
    
- alert: DatalakeHighQueryLoad
  expr: datalake_active_queries > 100
  for: 10m
  annotations:
    summary: "High query load on Trino"
```

## Future Enhancements

- [ ] Implement actual health check requests to services
- [ ] Add query performance metrics
- [ ] Integrate data lineage tracking
- [ ] Add cost tracking for storage usage
- [ ] Implement automated data quality checks
- [ ] Add data discovery and catalog features

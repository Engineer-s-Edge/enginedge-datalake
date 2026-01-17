# CI/CD Pipeline Documentation

## Overview

This repository includes a comprehensive CI/CD pipeline that automates testing, security scanning, building, and deployment of the EnginEdge Data Lake infrastructure.

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Push/Pull Request                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   CI Pipeline Starts   │
         └───────────┬───────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
   ┌────────┐  ┌─────────┐  ┌──────────┐
   │ Lint & │  │ Python  │  │ Security │
   │ Format │  │  Tests  │  │   Scan   │
   └────┬───┘  └────┬────┘  └────┬─────┘
        │           │            │
        └───────────┼────────────┘
                    │
                    ▼
         ┌──────────────────┐
         │ Integration Tests │
         └─────────┬─────────┘
                   │
                   ▼
         ┌──────────────────┐
         │  Build & Push    │
         │  Docker Images   │
         └─────────┬─────────┘
                   │
                   ▼
         ┌──────────────────┐
         │   Deploy (CD)    │
         └─────────┬─────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
        ▼          ▼          ▼
    ┌────┐    ┌─────┐    ┌──────┐
    │Dev │    │Stag │    │ Prod │
    └────┘    └─────┘    └──────┘
```

## Workflows

### 1. CI Pipeline (`datalake-ci.yml`)

**Triggers:**
- Push to `main`, `dev`, or `staging` branches
- Pull requests to `main` or `dev`

**Jobs:**

#### a. Code Quality Checks
- TypeScript type checking
- Linting (if configured)
- Format validation

#### b. Python Tests
- Runs tests on Python 3.9, 3.10, and 3.11
- Generates code coverage reports
- Uploads coverage to Codecov

#### c. Integration Tests
- Starts Docker Compose services (MinIO, PostgreSQL)
- Runs integration tests against live services
- Ensures service health before testing

#### d. Docker Compose Validation
- Validates `docker-compose.yml` syntax
- Checks configuration correctness

#### e. Security Scanning
- Scans codebase for vulnerabilities using Trivy
- Scans Python dependencies
- Uploads results to GitHub Security tab

#### f. Build and Push Images
- Only runs on push to `main` or `dev`
- Builds Docker images with caching
- Pushes to GitHub Container Registry
- Scans built images for vulnerabilities

### 2. Deployment Pipeline (`deploy.yml`)

**Triggers:**
- Manual workflow dispatch (choose environment and version)
- Push to `main` branch → production
- Git tags (`v*`) → production

**Jobs:**

#### a. Setup
- Determines target environment
- Resolves version/tag to deploy

#### b. Kubernetes Deployment
- Deploys all services to Kubernetes:
  - MinIO (object storage)
  - PostgreSQL (metadata)
  - Hive Metastore
  - Apache Spark (master & workers)
  - Trino (query engine)
  - Apache Airflow (orchestration)
  - Observability service
- Waits for all deployments to be ready
- Verifies deployment status

#### c. Docker Compose Deployment
- Alternative deployment for dev/staging
- Copies files to remote server via SCP
- Deploys using Docker Compose via SSH

#### d. Database Migrations
- Runs PostgreSQL migrations
- Only for staging and production

#### e. Smoke Tests
- Health checks for MinIO
- API endpoint validation
- Ensures services are operational

#### f. Rollback
- Automatic rollback on failure
- Reverts to previous deployment

### 3. Dependency Updates (`dependency-update.yml`)

**Triggers:**
- Weekly schedule (Mondays at 9 AM UTC)
- Manual workflow dispatch

**Jobs:**

#### a. NPM Updates
- Checks for outdated packages
- Updates to compatible versions
- Runs `npm audit fix`
- Creates pull request with updates

#### b. Python Updates
- Scans for security vulnerabilities
- Creates issues for vulnerable dependencies

#### c. Docker Image Checks
- Checks base images for updates
- Scans for vulnerabilities

## Environment Configuration

### Required Secrets

Add these secrets in GitHub repository settings (Settings → Secrets and variables → Actions):

#### Container Registry
- `GITHUB_TOKEN` - Automatically provided by GitHub

#### Deployment
- `KUBE_CONFIG` - Kubernetes configuration for cluster access
- `DEPLOY_HOST` - Server hostname for Docker Compose deployments
- `DEPLOY_USER` - SSH username
- `DEPLOY_SSH_KEY` - SSH private key for server access

#### Service Endpoints (for smoke tests)
- `MINIO_ENDPOINT` - MinIO endpoint URL
- `API_ENDPOINT` - Observability API endpoint

#### Optional
- `CODECOV_TOKEN` - For code coverage reports

### Environment Variables

Create `.env` file for local development:

```bash
# MinIO Configuration
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123

# PostgreSQL Configuration
POSTGRES_USER=airflow
POSTGRES_PASSWORD=airflow
POSTGRES_DB=airflow
TOKERN_USER_PASSWORD=admin123

# Service Ports
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
POSTGRES_PORT=5432
SPARK_MASTER_PORT=8080
TRINO_PORT=8090
AIRFLOW_PORT=8081
```

## Local Testing

### Run CI Checks Locally

```bash
# Install dependencies
npm ci
pip install -r requirements-test.txt

# Run type checking
npm run build

# Run Python tests
pytest tests/ -v

# Validate Docker Compose
docker compose config

# Run integration tests
docker compose up -d minio postgres
pytest tests/test_minio.py tests/test_postgres.py
docker compose down -v
```

### Security Scanning

```bash
# Install Trivy
# Windows: choco install trivy
# Mac: brew install aquasecurity/trivy/trivy
# Linux: See https://aquasecurity.github.io/trivy/

# Scan repository
trivy fs .

# Scan Docker image
docker build -t datalake-test .
trivy image datalake-test
```

## Deployment Strategies

### Development Environment
- Automatic deployment on push to `dev`
- Uses Docker Compose
- No approval required

### Staging Environment
- Manual deployment or tag-based
- Requires approval
- Full Kubernetes deployment
- Runs smoke tests

### Production Environment
- Manual deployment only
- Requires approval from team lead
- Full Kubernetes deployment
- Database migrations
- Comprehensive smoke tests
- Automatic rollback on failure

## Best Practices

### Branch Strategy
```
main      ──────●────────●─────────●──────  (production)
              ╱      ╱       ╱
dev       ────●──────●───────●────────●────  (development)
           ╱    ╲      ╱
feature  ──●      ●───●                      (feature branches)
```

1. Create feature branches from `dev`
2. Open PR to merge into `dev`
3. CI runs automatically on PR
4. After review and approval, merge to `dev`
5. Periodically merge `dev` to `main` for production releases

### Version Tagging

```bash
# Create version tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# This triggers production deployment
```

### Monitoring Deployments

```bash
# Check workflow status
gh run list --workflow=datalake-ci.yml

# Watch deployment
gh run watch

# View logs
gh run view <run-id> --log
```

## Troubleshooting

### CI Failures

#### Build Failures
```bash
# Check TypeScript errors
npm run build

# Check for dependency issues
npm ci
npm audit
```

#### Test Failures
```bash
# Run tests locally with verbose output
pytest tests/ -v -s

# Check service logs
docker compose logs minio
docker compose logs postgres
```

#### Integration Test Failures
```bash
# Ensure services are healthy
docker compose ps

# Check service connectivity
docker compose exec postgres pg_isready
curl http://localhost:9000/minio/health/live
```

### Deployment Failures

#### Kubernetes Issues
```bash
# Check pod status
kubectl get pods -n datalake-production

# View pod logs
kubectl logs -n datalake-production <pod-name>

# Describe deployment
kubectl describe deployment -n datalake-production

# Check events
kubectl get events -n datalake-production --sort-by='.lastTimestamp'
```

#### Docker Compose Issues
```bash
# SSH into server
ssh user@deploy-host

# Check running containers
docker compose ps

# View logs
docker compose logs -f

# Restart services
docker compose restart
```

### Common Issues

1. **Image Pull Failures**
   - Verify GITHUB_TOKEN has package read permissions
   - Check image registry settings

2. **Permission Denied**
   - Verify SSH key is correct
   - Check file permissions on server

3. **Service Health Checks Timeout**
   - Increase timeout values
   - Check resource allocation
   - Verify network connectivity

4. **Database Migration Failures**
   - Check PostgreSQL connection
   - Verify migration scripts
   - Review database permissions

## Metrics and Monitoring

### Pipeline Metrics
- Build success rate
- Average build time
- Test coverage percentage
- Security vulnerability count
- Deployment frequency

### Service Health
- Monitor via Observability API
- Check MinIO health endpoint
- PostgreSQL connection monitoring
- Spark job status

## Continuous Improvement

### Planned Enhancements
- [ ] Add performance testing
- [ ] Implement canary deployments
- [ ] Add chaos engineering tests
- [ ] Enhance monitoring and alerting
- [ ] Implement blue-green deployments
- [ ] Add automatic changelog generation

## Support

For issues or questions:
1. Check this documentation
2. Review workflow logs in GitHub Actions
3. Check service logs using kubectl or docker compose
4. Create an issue in the repository

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Trivy Security Scanner](https://aquasecurity.github.io/trivy/)

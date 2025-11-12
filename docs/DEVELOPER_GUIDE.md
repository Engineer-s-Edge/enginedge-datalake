# Developer Quick Start Guide

Welcome to the EnginEdge Data Lake project! This guide will help you get started with development and contributing.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Development Workflow](#development-workflow)
- [Running Tests](#running-tests)
- [CI/CD Pipeline](#cicd-pipeline)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software
- **Docker Desktop** (with Docker Compose)
  - Windows: [Download Docker Desktop](https://www.docker.com/products/docker-desktop)
  - Mac: `brew install --cask docker`
  - Linux: Follow [Docker installation guide](https://docs.docker.com/engine/install/)
  
- **Node.js 20+** and npm
  - Windows: [Download Node.js](https://nodejs.org/)
  - Mac: `brew install node@20`
  - Linux: `curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs`

- **Python 3.9+**
  - Windows: [Download Python](https://www.python.org/downloads/)
  - Mac: `brew install python@3.11`
  - Linux: `sudo apt-get install python3.11 python3-pip`

- **Git**
  - Already installed on most systems
  - Windows: `winget install Git.Git`

### Recommended Tools
- **GitHub CLI**: `gh` for easier workflow management
  - Windows: `winget install GitHub.cli`
  - Mac: `brew install gh`
  - Linux: `sudo apt install gh`

- **kubectl**: For Kubernetes deployments
  - Windows: `choco install kubernetes-cli`
  - Mac: `brew install kubectl`
  - Linux: `sudo snap install kubectl --classic`

- **VS Code**: Recommended editor with extensions:
  - Docker
  - Python
  - GitLens
  - GitHub Actions

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/Chris-Alexander-Pop/enginedge-datalake.git
cd enginedge-datalake
```

### 2. Install Dependencies

#### Node.js Dependencies
```bash
npm install
```

#### Python Dependencies
```bash
pip install -r requirements-test.txt
```

#### Development Tools
```bash
# Optional: Install pre-commit hooks
pip install pre-commit
pre-commit install
```

### 3. Configure Environment

Create a `.env` file from the example:

```bash
# Windows (PowerShell)
Copy-Item .env.example .env

# Mac/Linux
cp .env.example .env
```

Edit `.env` and customize values if needed:

```env
# MinIO Configuration
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123

# PostgreSQL Configuration
POSTGRES_USER=airflow
POSTGRES_PASSWORD=airflow
POSTGRES_DB=airflow
```

### 4. Start Services Locally

```bash
# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

### 5. Verify Installation

```bash
# Check MinIO (S3 storage)
curl http://localhost:9000/minio/health/live

# Check PostgreSQL
docker compose exec postgres pg_isready

# Check Observability API (after build)
npm run build
npm start
curl http://localhost:3010/health
```

## Development Workflow

### Branch Strategy

```
main (production)
  └── dev (development)
        └── feature/your-feature (your work)
```

### Creating a Feature Branch

```bash
# Start from dev
git checkout dev
git pull origin dev

# Create your feature branch
git checkout -b feature/my-awesome-feature

# Make changes, commit often
git add .
git commit -m "feat: add awesome feature"

# Push your branch
git push origin feature/my-awesome-feature
```

### Making Changes

1. **Code Changes**: Edit files in your favorite editor
2. **Test Locally**: Run tests (see below)
3. **Commit**: Use conventional commit messages:
   - `feat:` - New feature
   - `fix:` - Bug fix
   - `docs:` - Documentation changes
   - `test:` - Adding tests
   - `chore:` - Maintenance tasks
   - `refactor:` - Code refactoring

4. **Push**: Push to your feature branch
5. **Pull Request**: Create PR from your branch to `dev`

### Pull Request Process

1. **Create PR** on GitHub
2. **CI Runs Automatically**: 
   - Code quality checks
   - Tests
   - Security scans
3. **Review**: Wait for review from maintainers
4. **Address Feedback**: Make requested changes
5. **Merge**: Once approved, PR will be merged to `dev`

## Running Tests

### Quick Test Commands

```bash
# Run all Python tests
pytest tests/ -v

# Run specific test file
pytest tests/test_minio.py -v

# Run with coverage
pytest tests/ --cov=. --cov-report=html

# View coverage report
open htmlcov/index.html  # Mac
start htmlcov/index.html  # Windows
```

### Integration Tests

Integration tests require running services:

```bash
# Start required services
docker compose up -d minio postgres

# Wait for services to be ready (30 seconds)
sleep 30

# Run integration tests
pytest tests/test_minio.py tests/test_postgres.py -v

# Cleanup
docker compose down -v
```

### TypeScript/Node.js Tests

```bash
# Build project
npm run build

# Run in development mode
npm run start:dev

# Type checking
npm run build
```

## CI/CD Pipeline

### Understanding the Pipeline

When you push code or create a PR, the CI pipeline automatically:

1. ✅ **Linting**: Checks code quality
2. 🧪 **Testing**: Runs all tests
3. 🔒 **Security**: Scans for vulnerabilities
4. 🐳 **Build**: Creates Docker images (on `main`/`dev` only)

### Viewing Pipeline Status

```bash
# Using GitHub CLI
gh run list

# Watch a specific run
gh run watch

# View logs
gh run view --log
```

Or visit: https://github.com/Chris-Alexander-Pop/enginedge-datalake/actions

### Common CI Failures

#### Build Failures
**Cause**: TypeScript errors
**Fix**: Run `npm run build` locally and fix errors

#### Test Failures
**Cause**: Tests failing
**Fix**: Run `pytest tests/ -v` locally and fix failing tests

#### Lint Errors
**Cause**: Code style issues
**Fix**: Run linter and fix issues (if configured)

#### Security Scan Failures
**Cause**: Known vulnerabilities in dependencies
**Fix**: Update vulnerable packages:
```bash
npm audit fix
pip install --upgrade <package-name>
```

## Troubleshooting

### Docker Issues

#### Services Won't Start
```bash
# Check Docker is running
docker info

# Clean up and restart
docker compose down -v
docker compose up -d
```

#### Port Already in Use
```bash
# Windows - Find process using port 9000
netstat -ano | findstr :9000
taskkill /PID <PID> /F

# Mac/Linux
lsof -ti:9000 | xargs kill -9
```

#### Out of Disk Space
```bash
# Clean up Docker
docker system prune -a --volumes
```

### Python Issues

#### ImportError or Module Not Found
```bash
# Reinstall dependencies
pip install -r requirements-test.txt --force-reinstall
```

#### Test Connection Failures
```bash
# Check services are running
docker compose ps

# Check service logs
docker compose logs minio
docker compose logs postgres
```

### Node.js Issues

#### Build Failures
```bash
# Clean and reinstall
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Git Issues

#### Merge Conflicts
```bash
# Update your branch with latest dev
git checkout dev
git pull origin dev
git checkout feature/your-branch
git merge dev

# Resolve conflicts in editor
# Then:
git add .
git commit -m "chore: resolve merge conflicts"
```

## Development Tips

### Quick Service Restart
```bash
# Restart specific service
docker compose restart minio

# Restart all services
docker compose restart
```

### View Real-time Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f minio

# Last 100 lines
docker compose logs --tail=100 postgres
```

### Database Access
```bash
# Connect to PostgreSQL
docker compose exec postgres psql -U airflow -d airflow

# Run SQL query
docker compose exec postgres psql -U airflow -d airflow -c "SELECT version();"
```

### MinIO CLI
```bash
# Install MinIO client
# Windows: choco install minio-client
# Mac: brew install minio/stable/mc
# Linux: wget https://dl.min.io/client/mc/release/linux-amd64/mc && chmod +x mc

# Configure
mc alias set local http://localhost:9000 minioadmin minioadmin123

# List buckets
mc ls local

# Upload file
mc cp myfile.txt local/mybucket/
```

## Getting Help

1. **Check Documentation**: 
   - [Main README](../README.md)
   - [CI/CD Guide](CICD.md)
   - [Secrets Setup](.github/SECRETS_SETUP.md)

2. **Search Issues**: Check if someone else had the same problem
   - https://github.com/Chris-Alexander-Pop/enginedge-datalake/issues

3. **Ask for Help**: Create a new issue with:
   - What you were trying to do
   - What happened
   - Error messages
   - Your environment (OS, Docker version, etc.)

4. **Join Discussions**: 
   - GitHub Discussions (if enabled)
   - Team chat/Slack

## Next Steps

Now that you're set up:

1. 📖 Read the [Architecture Documentation](../README.md#architecture)
2. 🎯 Pick an issue from [Good First Issues](https://github.com/Chris-Alexander-Pop/enginedge-datalake/labels/good%20first%20issue)
3. 💻 Write some code!
4. 🧪 Add tests
5. 📝 Update documentation
6. 🚀 Create a pull request

Happy coding! 🎉

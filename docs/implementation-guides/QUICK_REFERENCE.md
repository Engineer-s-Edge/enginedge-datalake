# CI/CD Quick Reference Card

## 🚀 Quick Commands

### Local Testing
```powershell
# Install dependencies
npm ci
pip install -r requirements-test.txt

# Run tests
pytest tests/ -v
npm run build

# Integration tests
docker compose up -d minio postgres
pytest tests/test_minio.py tests/test_postgres.py -v
docker compose down -v

# Coverage
pytest tests/ --cov=. --cov-report=html
```

### GitHub CLI
```powershell
# List workflow runs
gh run list --workflow=datalake-ci.yml

# Watch a run
gh run watch

# View logs
gh run view --log

# Trigger deployment
gh workflow run deploy.yml -f environment=staging -f version=main

# Check PR status
gh pr checks
```

### Git Workflow
```powershell
# Start feature
git checkout dev
git pull origin dev
git checkout -b feature/my-feature

# Commit with conventional commits
git commit -m "feat: add new feature"
git commit -m "fix: resolve bug"
git commit -m "docs: update readme"

# Push and create PR
git push origin feature/my-feature
gh pr create --fill
```

## 🔧 Configuration Checklist

### First-Time Setup
- [ ] Configure GitHub secrets
- [ ] Create environments (dev, staging, production)
- [ ] Enable branch protection (main, dev)
- [ ] Add team members as reviewers
- [ ] Test CI with sample PR

### Secrets Required
- `GITHUB_TOKEN` (automatic)
- `KUBE_CONFIG` (for Kubernetes)
- `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY` (for Docker Compose)
- `MINIO_ENDPOINT`, `API_ENDPOINT` (per environment)

## 📊 Pipeline Status

### Workflow Triggers

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `datalake-ci.yml` | Push, PR | Testing, Security, Build |
| `deploy.yml` | Manual, Tags | Deployment |
| `dependency-update.yml` | Weekly | Dependency Updates |
| `release.yml` | Tags (v*) | Release Creation |

### Environments

| Environment | Trigger | Approvals | Notes |
|------------|---------|-----------|-------|
| development | Auto (dev branch) | None | Docker Compose |
| staging | Manual | 1 | Kubernetes |
| production | Manual / Tags | 2 | Kubernetes |

## 🐛 Troubleshooting

### CI Failures

| Issue | Solution |
|-------|----------|
| Build fails | Run `npm run build` locally, fix TS errors |
| Tests fail | Run `pytest tests/ -v`, fix failing tests |
| Security scan | Run `npm audit fix`, update vulnerable packages |
| Docker build | Test `docker compose up -d` locally |

### Common Errors

```powershell
# "Port already in use"
netstat -ano | findstr :9000
taskkill /PID <PID> /F

# "Module not found"
pip install -r requirements-test.txt --force-reinstall
npm ci

# "Docker daemon not running"
# Start Docker Desktop

# "Permission denied"
# Check SSH key is correct
# Verify DEPLOY_SSH_KEY secret
```

## 📋 Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `test`: Tests
- `chore`: Maintenance
- `refactor`: Code refactoring
- `ci`: CI/CD changes

### Examples
```bash
git commit -m "feat: add MinIO bucket versioning"
git commit -m "fix: resolve PostgreSQL timeout"
git commit -m "docs: update setup guide"
git commit -m "test: add integration tests for Trino"
```

## 🔍 Viewing Results

### GitHub UI
- **Actions Tab**: All workflow runs
- **Security Tab**: Scan results
- **Pull Requests**: CI status
- **Environments**: Deployment history

### CLI
```powershell
# View workflow runs
gh run list

# Check PR CI status
gh pr checks <pr-number>

# View deployment status
gh run list --workflow=deploy.yml
```

## 📚 Documentation Links

| Document | Purpose |
|----------|---------|
| `docs/CICD.md` | Complete CI/CD guide |
| `docs/DEVELOPER_GUIDE.md` | Developer setup |
| `.github/SECRETS_SETUP.md` | Secrets configuration |
| `CONTRIBUTING.md` | Contribution guide |
| `docs/PIPELINE_COMPLETE.md` | Implementation summary |

## 🎯 Next Actions

### For Admins
1. Configure secrets: `.github/SECRETS_SETUP.md`
2. Create environments: Settings → Environments
3. Enable branch protection: Settings → Branches
4. Test pipeline: Create sample PR

### For Developers
1. Read: `docs/DEVELOPER_GUIDE.md`
2. Clone and setup repository
3. Run tests locally
4. Create feature branch and PR

## 📞 Getting Help

1. Check documentation in `docs/`
2. Search existing issues
3. Create new issue with template
4. Contact team in [your chat platform]

## 🎓 Learning Path

1. **Start Here**: `README.md`
2. **Setup**: `docs/DEVELOPER_GUIDE.md`
3. **CI/CD**: `docs/CICD.md`
4. **Contributing**: `CONTRIBUTING.md`
5. **Secrets**: `.github/SECRETS_SETUP.md`

---

**Quick Tip**: Bookmark this file for easy reference!

**Status**: ✅ Pipeline Ready | ⏳ Configuration Needed
**Version**: 1.0.0
**Last Updated**: November 2025

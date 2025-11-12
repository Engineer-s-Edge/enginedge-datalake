# CI/CD Pipeline Architecture

## Overview Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Developer Workflow                           │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                    ┌────────┴────────┐
                    │  Git Push / PR  │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   ┌─────────┐         ┌─────────┐         ┌─────────┐
   │  Main   │         │   Dev   │         │   PR    │
   │ Branch  │         │ Branch  │         │         │
   └────┬────┘         └────┬────┘         └────┬────┘
        │                   │                    │
        └────────────────┬──┴────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────────┐
        │         CI Pipeline Starts              │
        │      (.github/workflows/datalake-ci.yml)│
        └────────────────┬───────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
   ┌────────┐      ┌──────────┐    ┌──────────┐
   │  Lint  │      │  Tests   │    │ Security │
   │ & Type │      │ Python   │    │  Scans   │
   │ Check  │      │ 3.9-3.11 │    │  Trivy   │
   └────┬───┘      └─────┬────┘    └─────┬────┘
        │                │               │
        └────────────────┼───────────────┘
                         │
                         ▼
              ┌──────────────────┐
              │ Integration Tests│
              │   Docker Compose │
              └─────────┬────────┘
                        │
                        ▼
              ┌──────────────────┐
              │   Build & Push   │
              │  Docker Images   │
              │  (main/dev only) │
              └─────────┬────────┘
                        │
              ┌─────────┴─────────┐
              │                   │
              ▼                   ▼
         ┌─────────┐         ┌────────┐
         │   PR    │         │ Deploy │
         │ Review  │         │Pipeline│
         └─────────┘         └────┬───┘
                                  │
                     ┌────────────┼────────────┐
                     │            │            │
                     ▼            ▼            ▼
                ┌──────┐     ┌────────┐   ┌──────┐
                │ Dev  │     │Staging │   │ Prod │
                └──────┘     └────────┘   └──────┘
```

## CI Pipeline Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    1. Code Quality                           │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ TypeScript │  │   Linting  │  │   Build    │            │
│  │Type Check  │→ │  (if any)  │→ │  npm build │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│                                                              │
│  Duration: ~2-3 minutes                                      │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    2. Python Tests                           │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ Python 3.9 │  │Python 3.10 │  │Python 3.11 │            │
│  │   Tests    │  │   Tests    │  │   Tests    │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│                                                              │
│  Runs in Parallel | Duration: ~3-5 minutes                  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  3. Integration Tests                        │
│  ┌───────────────────────────────────────────────┐          │
│  │  Start Services: MinIO, PostgreSQL            │          │
│  │  ↓                                             │          │
│  │  Wait for Health (30s)                        │          │
│  │  ↓                                             │          │
│  │  Run Integration Tests                        │          │
│  │  ↓                                             │          │
│  │  Cleanup                                       │          │
│  └───────────────────────────────────────────────┘          │
│                                                              │
│  Duration: ~5-7 minutes                                      │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  4. Security Scanning                        │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │  Trivy FS  │  │   Python   │  │   Upload   │            │
│  │   Scan     │→ │   Deps     │→ │  to SARIF  │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│                                                              │
│  Duration: ~2-3 minutes                                      │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│               5. Build & Push (main/dev only)                │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │   Build    │  │    Push    │  │Image Scan  │            │
│  │   Docker   │→ │    GHCR    │→ │   Trivy    │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│                                                              │
│  Duration: ~3-5 minutes                                      │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
                   ┌───────────────┐
                   │   All Passed  │
                   │  Ready to     │
                   │    Merge      │
                   └───────────────┘
```

## Deployment Pipeline Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Deployment Trigger                        │
│                                                              │
│  Manual Dispatch  │  Push to Main  │  Version Tag (v*)      │
└─────────┬───────────────┬───────────────┬──────────────────┘
          │               │               │
          └───────────────┼───────────────┘
                          │
                          ▼
          ┌───────────────────────────┐
          │    Determine Environment  │
          │   ┌─────────────────────┐ │
          │   │ dev    → development│ │
          │   │ main   → production │ │
          │   │ v*tag  → production │ │
          │   │ manual → user choice│ │
          │   └─────────────────────┘ │
          └────────────┬──────────────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
          ▼            ▼            ▼
    ┌──────────┐ ┌──────────┐ ┌──────────┐
    │   Dev    │ │ Staging  │ │   Prod   │
    │          │ │          │ │          │
    │ Docker   │ │Kubernetes│ │Kubernetes│
    │ Compose  │ │          │ │          │
    │          │ │ Approval │ │ Approval │
    │ No Gate  │ │ Required │ │ Required │
    └─────┬────┘ └─────┬────┘ └─────┬────┘
          │            │            │
          └────────────┼────────────┘
                       │
                       ▼
          ┌────────────────────────┐
          │   Deploy Components    │
          │  ┌──────────────────┐  │
          │  │ 1. MinIO         │  │
          │  │ 2. PostgreSQL    │  │
          │  │ 3. Hive          │  │
          │  │ 4. Spark         │  │
          │  │ 5. Trino         │  │
          │  │ 6. Airflow       │  │
          │  │ 7. Observability │  │
          │  └──────────────────┘  │
          └────────────┬───────────┘
                       │
                       ▼
          ┌────────────────────────┐
          │  Wait for Deployments  │
          │      (max 10 min)      │
          └────────────┬───────────┘
                       │
                       ▼
          ┌────────────────────────┐
          │     Smoke Tests        │
          │  ┌──────────────────┐  │
          │  │ MinIO Health     │  │
          │  │ API Health       │  │
          │  │ Service Checks   │  │
          │  └──────────────────┘  │
          └────────────┬───────────┘
                       │
          ┌────────────┴────────────┐
          │                         │
          ▼                         ▼
    ┌──────────┐              ┌──────────┐
    │ Success  │              │  Failed  │
    │          │              │          │
    │ Notify   │              │ Rollback │
    └──────────┘              └──────────┘
```

## Dependency Update Flow

```
┌─────────────────────────────────────┐
│   Weekly Schedule (Monday 9 AM)    │
└──────────────┬──────────────────────┘
               │
    ┌──────────┴──────────┐
    │                     │
    ▼                     ▼
┌────────┐          ┌──────────┐
│  NPM   │          │  Python  │
│Updates │          │ Updates  │
└────┬───┘          └─────┬────┘
     │                    │
     │                    │
     ▼                    ▼
┌────────────┐      ┌──────────────┐
│ Check for  │      │ pip-audit    │
│ Outdated   │      │ Security     │
│ Packages   │      │ Scan         │
└─────┬──────┘      └──────┬───────┘
      │                    │
      ▼                    ▼
┌────────────┐      ┌──────────────┐
│npm update  │      │Create Issue  │
│npm audit   │      │for Security  │
│fix         │      │Vulnerabilities│
└─────┬──────┘      └──────┬───────┘
      │                    │
      ▼                    │
┌────────────┐             │
│ Run Tests  │             │
└─────┬──────┘             │
      │                    │
      ▼                    │
┌────────────┐             │
│ Create PR  │             │
│for Updates │             │
└────────────┘             │
                           │
                           ▼
                  ┌─────────────────┐
                  │ Team Reviews &  │
                  │ Takes Action    │
                  └─────────────────┘
```

## Environment Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      Development                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Deployment: Docker Compose                            │  │
│  │  Trigger: Auto on dev push                             │  │
│  │  Approvals: None                                       │  │
│  │  Services: All (MinIO, Postgres, Spark, etc.)         │  │
│  │  Purpose: Feature testing                              │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                        Staging                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Deployment: Kubernetes                                │  │
│  │  Trigger: Manual or scheduled                          │  │
│  │  Approvals: 1 reviewer required                        │  │
│  │  Services: All (production-like)                       │  │
│  │  Purpose: Pre-production validation                    │  │
│  │  Migrations: Yes                                       │  │
│  │  Smoke Tests: Yes                                      │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                      Production                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Deployment: Kubernetes                                │  │
│  │  Trigger: Manual or version tags                       │  │
│  │  Approvals: 2 reviewers required                       │  │
│  │  Wait Timer: 10 minutes                                │  │
│  │  Services: All (high availability)                     │  │
│  │  Purpose: Live production system                       │  │
│  │  Migrations: Yes (with backups)                        │  │
│  │  Smoke Tests: Yes (comprehensive)                      │  │
│  │  Rollback: Automatic on failure                        │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## Service Dependencies

```
┌─────────────────────────────────────────────────────────┐
│                    Data Lake Stack                       │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
   ┌────────┐  ┌──────────┐  ┌────────┐
   │ MinIO  │  │PostgreSQL│  │  Hive  │
   │  (S3)  │  │(Metadata)│  │Metastor│
   └────┬───┘  └─────┬────┘  └────┬───┘
        │            │            │
        └────────────┼────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
   ┌────────┐  ┌──────────┐  ┌────────┐
   │ Spark  │  │  Trino   │  │Airflow │
   │(Process│  │ (Query)  │  │(Orchestr
   └────┬───┘  └─────┬────┘  └────┬───┘
        │            │            │
        └────────────┼────────────┘
                     │
                     ▼
             ┌───────────────┐
             │  Jupyter Lab  │
             │  (Analytics)  │
             └───────────────┘
                     │
                     ▼
             ┌───────────────┐
             │ Observability │
             │     API       │
             └───────────────┘
```

## Timeline Estimates

```
┌────────────────────────────────────────────────┐
│              CI Pipeline Duration              │
├────────────────────────────────────────────────┤
│ Code Quality         │ 2-3 minutes             │
│ Python Tests         │ 3-5 minutes (parallel)  │
│ Integration Tests    │ 5-7 minutes             │
│ Security Scanning    │ 2-3 minutes             │
│ Docker Build & Push  │ 3-5 minutes             │
├────────────────────────────────────────────────┤
│ TOTAL (typical)      │ 10-15 minutes           │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│           Deployment Duration                  │
├────────────────────────────────────────────────┤
│ Setup                │ 1-2 minutes             │
│ Kubernetes Deploy    │ 3-5 minutes             │
│ Wait for Ready       │ 2-5 minutes             │
│ Smoke Tests          │ 1-2 minutes             │
├────────────────────────────────────────────────┤
│ TOTAL (typical)      │ 7-14 minutes            │
└────────────────────────────────────────────────┘
```

## Security Scanning Flow

```
┌─────────────────────────────────────────┐
│         Security Scanning                │
└─────────────────┬───────────────────────┘
                  │
     ┌────────────┼────────────┐
     │            │            │
     ▼            ▼            ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│  Trivy  │  │  Trivy  │  │  Trivy  │
│   FS    │  │  Python │  │  Docker │
│  Scan   │  │  Deps   │  │  Image  │
└────┬────┘  └────┬────┘  └────┬────┘
     │            │            │
     └────────────┼────────────┘
                  │
                  ▼
          ┌───────────────┐
          │  Generate     │
          │  SARIF Report │
          └───────┬───────┘
                  │
                  ▼
          ┌───────────────┐
          │  Upload to    │
          │  GitHub       │
          │  Security     │
          └───────┬───────┘
                  │
                  ▼
        ┌─────────────────────┐
        │ View in Security Tab│
        │  - Vulnerabilities  │
        │  - Severity Levels  │
        │  - Remediation Tips │
        └─────────────────────┘
```

---

**Legend**:
- `→` Sequential flow
- `│` Vertical connection
- `┌┐└┘` Box borders
- `▼` Flow direction

**Usage**: Reference this diagram when understanding or explaining the pipeline architecture.

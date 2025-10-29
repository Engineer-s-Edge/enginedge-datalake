#!/usr/bin/env pwsh

Write-Host "Starting EnginEdge Data Lake..." -ForegroundColor Cyan
Write-Host "This will start all data lake components including MinIO, Spark, Trino, Airflow, and Jupyter" -ForegroundColor Cyan

# Check if Docker is running
try {
    docker ps | Out-Null
    Write-Host "Docker is running [OK]" -ForegroundColor Green
}
catch {
    Write-Host "Docker is not running! Please start Docker first." -ForegroundColor Red
    exit 1
}

# Create data directories if they don't exist
$directories = @("data", "notebooks", "spark/jars", "spark-apps")
foreach ($dir in $directories) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created directory: $dir" -ForegroundColor Yellow
    }
}

# Download required Spark JARs for S3 connectivity
$sparkJarsPath = "./spark/jars"
$requiredJars = @(
    "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar",
    "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.367/aws-java-sdk-bundle-1.12.367.jar",
    "https://repo1.maven.org/maven2/org/postgresql/postgresql/42.5.1/postgresql-42.5.1.jar"
)

Write-Host "Downloading required JAR files..." -ForegroundColor Yellow
foreach ($jarUrl in $requiredJars) {
    $jarName = Split-Path $jarUrl -Leaf
    $jarPath = Join-Path $sparkJarsPath $jarName

    if (-not (Test-Path $jarPath)) {
        try {
            Invoke-WebRequest -Uri $jarUrl -OutFile $jarPath -ErrorAction Stop
            Write-Host "Downloaded: $jarName" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to download: $jarName" -ForegroundColor Red
        }
    }
    else {
        Write-Host "JAR already exists: $jarName" -ForegroundColor Green
    }
}

# Start the data lake services
Write-Host "Starting data lake services..." -ForegroundColor Yellow
docker-compose up -d

# Wait for services to be ready
Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Check service status
Write-Host "`nChecking service status..." -ForegroundColor Cyan
$services = @(
    @{ Name = 'MinIO';          Port = 9000; Url = 'http://localhost:9000' },
    @{ Name = 'MinIO Console';  Port = 9001; Url = 'http://localhost:9001' },
    @{ Name = 'Spark Master';   Port = 8080; Url = 'http://localhost:8080' },
    @{ Name = 'Spark Worker';   Port = 8081; Url = 'http://localhost:8081' },
    @{ Name = 'Trino';          Port = 8090; Url = 'http://localhost:8090' },
    @{ Name = 'Airflow';        Port = 8082; Url = 'http://localhost:8082' },
    @{ Name = 'Jupyter';        Port = 8888; Url = 'http://localhost:8888' },
    @{ Name = 'PostgreSQL';     Port = 5432; Url = 'postgresql://localhost:5432' }
)

foreach ($service in $services) {
    try {
        $connection = Test-NetConnection -ComputerName 'localhost' -Port $service.Port -WarningAction SilentlyContinue
        if ($connection.TcpTestSucceeded) {
            Write-Host ("{0}: [OK] Running" -f $service.Name) -ForegroundColor Green
        }
        else {
            Write-Host ("{0}: [ERR] Not responding" -f $service.Name) -ForegroundColor Red
        }
    }
    catch {
    Write-Host ("{0}: [ERR] Error checking status" -f $service.Name) -ForegroundColor Red
    }
}

Write-Host "`nData Lake is ready!" -ForegroundColor Green
Write-Host "`nAccess URLs:" -ForegroundColor Cyan
Write-Host "  MinIO Console:  http://localhost:9001 (admin: minioadmin / minioadmin123)" -ForegroundColor Yellow
Write-Host "  Spark Master:   http://localhost:8080" -ForegroundColor Yellow
Write-Host "  Trino:          http://localhost:8090" -ForegroundColor Yellow
Write-Host "  Airflow:        http://localhost:8082 (admin: admin / admin123)" -ForegroundColor Yellow
Write-Host "  Jupyter Lab:    http://localhost:8888 (token: jupyter123)" -ForegroundColor Yellow

Write-Host "`nGetting Started:" -ForegroundColor Cyan
Write-Host "  1. Open Jupyter Lab and run the 'Getting_Started.ipynb' notebook" -ForegroundColor White
Write-Host "  2. Access MinIO Console to view object storage" -ForegroundColor White
Write-Host "  3. Use Airflow to schedule and monitor data pipelines" -ForegroundColor White
Write-Host "  4. Query data using Trino SQL interface" -ForegroundColor White

Write-Host "`nTo stop the data lake:" -ForegroundColor Cyan
Write-Host "  docker-compose down" -ForegroundColor Yellow

Write-Host "`nTo view logs:" -ForegroundColor Cyan
Write-Host "  docker-compose logs -f [service-name]" -ForegroundColor Yellow

# Return to parent directory
Set-Location -Path ".."

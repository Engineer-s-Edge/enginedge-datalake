#!/usr/bin/env pwsh

Write-Host "Stopping EnginEdge Data Lake..." -ForegroundColor Yellow

# Change to datalake directory
Set-Location -Path "datalake"

# Stop all services
docker-compose down

Write-Host "✅ Data Lake services stopped" -ForegroundColor Green
Write-Host "Note: Data is preserved in Docker volumes" -ForegroundColor Cyan
Write-Host "To remove all data, run: docker-compose down -v" -ForegroundColor Yellow

# Return to parent directory
Set-Location -Path ".."

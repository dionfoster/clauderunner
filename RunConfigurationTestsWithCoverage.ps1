# Run Configuration tests with code coverage analysis
# This script focuses on just the Configuration module tests for faster iteration

param(
    [Parameter()]
    [double]$CoverageThreshold = 80.0
)

Write-Host "Running Configuration tests with code coverage analysis..." -ForegroundColor Green
Write-Host "Coverage threshold: $CoverageThreshold%" -ForegroundColor Cyan

# Run tests for just the Configuration module
& "$PSScriptRoot\RunTestsWithCoverage.ps1" -TestPath "$PSScriptRoot\tests\Configuration.Tests.ps1" -CoverageThreshold $CoverageThreshold

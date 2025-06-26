# Run tests with comprehensive code coverage
# This script uses the PesterConfig.ps1 for full coverage analysis

param(
    [Parameter()]
    [string]$TestName = "",
    
    [Parameter()]
    [string]$TestPath = "",
    
    [Parameter()]
    [double]$CoverageThreshold = 80.0
)

Write-Host "Running tests with code coverage analysis..." -ForegroundColor Green
Write-Host "Coverage threshold: $CoverageThreshold%" -ForegroundColor Cyan

# Ensure TestResults directory exists
$testResultsPath = "$PSScriptRoot\TestResults"
if (-not (Test-Path $testResultsPath)) {
    New-Item -ItemType Directory -Path $testResultsPath -Force | Out-Null
    Write-Host "Created TestResults directory: $testResultsPath" -ForegroundColor Yellow
}

# Build the parameters for RunTests.ps1
$runTestsParams = @{
    UseConfig = $true
    Coverage = $true
    CoverageThreshold = $CoverageThreshold
}

if ($TestName) {
    $runTestsParams.TestName = $TestName
}

if ($TestPath) {
    $runTestsParams.TestPath = $TestPath
}

# Run the tests with coverage
& "$PSScriptRoot\RunTests.ps1" @runTestsParams

# Display information about generated reports
$coverageFile = "$testResultsPath\coverage.xml"
$testResultsFile = "$testResultsPath\testresults.xml"

Write-Host "`n----- Generated Reports -----" -ForegroundColor Cyan

if (Test-Path $coverageFile) {
    Write-Host "✓ Code coverage report: $coverageFile" -ForegroundColor Green
} else {
    Write-Host "✗ Code coverage report not found" -ForegroundColor Red
}

if (Test-Path $testResultsFile) {
    Write-Host "✓ Test results report: $testResultsFile" -ForegroundColor Green
} else {
    Write-Host "✗ Test results report not found" -ForegroundColor Red
}

Write-Host "`nUse these reports with CI/CD systems or coverage analysis tools." -ForegroundColor Cyan

# Complete Test and Coverage Analysis
# This script runs all tests, generates coverage reports, and provides a comprehensive summary

param(
    [Parameter()]
    [double]$CoverageThreshold = 80.0,
    
    [Parameter()]
    [switch]$OpenReports,
    
    [Parameter()]
    [switch]$SkipHtmlReport
)

Write-Host "🧪 Running Complete Test and Coverage Analysis" -ForegroundColor Green
Write-Host "Coverage threshold: $CoverageThreshold%" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Step 1: Run tests with coverage
Write-Host "`n📊 Step 1: Running tests with code coverage..." -ForegroundColor Yellow
$runTestsParams = @{
    CoverageThreshold = $CoverageThreshold
}

& "$PSScriptRoot\RunTestsWithCoverage.ps1" @runTestsParams
$testExitCode = $LASTEXITCODE

# Step 2: Generate HTML report if not skipped
if (-not $SkipHtmlReport) {
    Write-Host "`n📋 Step 2: Generating HTML coverage report..." -ForegroundColor Yellow
    $generateParams = @{}
    if (-not $OpenReports) {
        # Suppress the interactive prompt by redirecting input
        $generateParams.Add("ErrorAction", "SilentlyContinue")
    }
    
    & "$PSScriptRoot\GenerateCoverageReport.ps1" @generateParams
}

# Step 3: Summary
Write-Host "`n📈 Analysis Complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Gray

$testResultsPath = "$PSScriptRoot\TestResults"
$files = @(
    @{ Name = "JaCoCo XML Coverage"; Path = "$testResultsPath\coverage.xml" },
    @{ Name = "NUnit XML Test Results"; Path = "$testResultsPath\testresults.xml" },
    @{ Name = "HTML Coverage Report"; Path = "$testResultsPath\coverage-report.html" }
)

Write-Host "`n📁 Generated Files:" -ForegroundColor Cyan
foreach ($file in $files) {
    if (Test-Path $file.Path) {
        $size = Get-Item $file.Path | Select-Object -ExpandProperty Length
        $sizeKB = [math]::Round($size / 1KB, 1)
        Write-Host "  ✓ $($file.Name): $($file.Path) ($sizeKB KB)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($file.Name): Not found" -ForegroundColor Red
    }
}

# Step 4: Open reports if requested
if ($OpenReports -and (Test-Path "$testResultsPath\coverage-report.html")) {
    Write-Host "`n🌐 Opening HTML coverage report..." -ForegroundColor Yellow
    Start-Process "$testResultsPath\coverage-report.html"
}

# Step 5: Usage suggestions
Write-Host "`n💡 Usage Tips:" -ForegroundColor Cyan
Write-Host "  • Use JaCoCo XML for CI/CD pipeline integration" -ForegroundColor White
Write-Host "  • Use NUnit XML for test result reporting" -ForegroundColor White
Write-Host "  • Use HTML report for interactive coverage exploration" -ForegroundColor White
Write-Host "  • Run with -OpenReports to auto-open HTML report" -ForegroundColor White
Write-Host "  • Run with -SkipHtmlReport to skip HTML generation" -ForegroundColor White

# Step 6: Exit with appropriate code
if ($testExitCode -ne 0) {
    Write-Host "`n⚠️  Tests failed or coverage below threshold!" -ForegroundColor Red
    exit $testExitCode
} else {
    Write-Host "`n🎉 All tests passed and coverage requirements met!" -ForegroundColor Green
    exit 0
}

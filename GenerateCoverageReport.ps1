# Generate HTML Code Coverage Report
# This script converts JaCoCo XML coverage to a simple HTML report

param(
    [Parameter()]
    [string]$CoverageFile = "$PSScriptRoot\TestResults\coverage.xml",
    
    [Parameter()]
    [string]$OutputFile = "$PSScriptRoot\TestResults\coverage-report.html"
)

if (-not (Test-Path $CoverageFile)) {
    Write-Host "Coverage file not found: $CoverageFile" -ForegroundColor Red
    Write-Host "Run tests with coverage first using: .\RunTestsWithCoverage.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "Generating HTML coverage report from: $CoverageFile" -ForegroundColor Cyan

try {
    # Load the XML coverage data
    [xml]$coverage = Get-Content $CoverageFile
    
    # Extract coverage statistics
    $packages = $coverage.report.package
    $overallStats = $coverage.report.counter | Where-Object { $_.type -eq "LINE" }
    
    $totalLines = [int]$overallStats.missed + [int]$overallStats.covered
    $coveredLines = [int]$overallStats.covered
    $coveragePercent = if ($totalLines -gt 0) { [math]::Round(($coveredLines / $totalLines) * 100, 2) } else { 0 }
    
    # Generate HTML report
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Code Coverage Report - Claude Task Runner</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .summary { margin: 20px 0; }
        .coverage-high { color: green; font-weight: bold; }
        .coverage-medium { color: orange; font-weight: bold; }
        .coverage-low { color: red; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .file-name { font-family: monospace; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Code Coverage Report</h1>
        <p>Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
    </div>
    
    <div class="summary">
        <h2>Overall Coverage</h2>
        <p>Coverage: <span class="$(if ($coveragePercent -ge 80) { 'coverage-high' } elseif ($coveragePercent -ge 60) { 'coverage-medium' } else { 'coverage-low' })">$coveragePercent%</span></p>
        <p>Lines Covered: $coveredLines / $totalLines</p>
    </div>
    
    <h2>File Coverage Details</h2>
    <table>
        <thead>
            <tr>
                <th>File</th>
                <th>Lines Covered</th>
                <th>Lines Missed</th>
                <th>Coverage %</th>
            </tr>
        </thead>
        <tbody>
"@

    # Add file details
    foreach ($package in $packages) {
        foreach ($class in $package.class) {
            $fileName = $class.name
            $lineStats = $class.counter | Where-Object { $_.type -eq "LINE" }
            
            if ($lineStats) {
                $fileCovered = [int]$lineStats.covered
                $fileMissed = [int]$lineStats.missed
                $fileTotal = $fileCovered + $fileMissed
                $filePercent = if ($fileTotal -gt 0) { [math]::Round(($fileCovered / $fileTotal) * 100, 2) } else { 0 }
                
                $coverageClass = if ($filePercent -ge 80) { 'coverage-high' } elseif ($filePercent -ge 60) { 'coverage-medium' } else { 'coverage-low' }
                
                $html += @"
            <tr>
                <td class="file-name">$fileName</td>
                <td>$fileCovered</td>
                <td>$fileMissed</td>
                <td class="$coverageClass">$filePercent%</td>
            </tr>
"@
            }
        }
    }

    $html += @"
        </tbody>
    </table>
    
    <div style="margin-top: 30px; font-size: 12px; color: #666;">
        <p>This report was generated from JaCoCo XML coverage data.</p>
    </div>
</body>
</html>
"@

    # Write the HTML file
    $html | Out-File -FilePath $OutputFile -Encoding UTF8
    
    Write-Host "HTML coverage report generated: $OutputFile" -ForegroundColor Green
    Write-Host "Overall coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' })
    
    # Optionally open the report in the default browser
    $openReport = Read-Host "Open coverage report in browser? (y/N)"
    if ($openReport -eq 'y' -or $openReport -eq 'Y') {
        Start-Process $OutputFile
    }
    
} catch {
    Write-Host "Error generating coverage report: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

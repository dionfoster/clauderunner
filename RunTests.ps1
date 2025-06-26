# Run all Pester tests in the project
param(
    [Parameter()]
    [string]$TestName = "",
    
    [Parameter()]
    [string]$TestPath = "",
    
    [Parameter()]
    [switch]$Coverage,
    
    [Parameter()]
    [switch]$UseConfig,
    
    [Parameter()]
    [double]$CoverageThreshold = 0.0
)

# Ensure Pester is installed
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge "5.0" })) {
    Write-Host "Pester module 5.0 or higher is not installed. Installing..."
    Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0 -Scope CurrentUser
}

# Import Pester module
Import-Module Pester -MinimumVersion 5.0

# Define the root directory for the tests
$TestsRoot = "$PSScriptRoot\tests"

# Verify tests directory exists
if (-not (Test-Path $TestsRoot)) {
    Write-Host "Error: Tests directory not found at $TestsRoot" -ForegroundColor Red
    exit 1
}

# Set up the configuration for Pester
if ($UseConfig) {
    # Use the dedicated Pester configuration file
    Write-Host "Using PesterConfig.ps1 for comprehensive test configuration" -ForegroundColor Cyan
    $config = & "$PSScriptRoot\PesterConfig.ps1"
    
    # Override specific settings if parameters are provided
    if ($TestPath) {
        $config.Run.Path = $TestPath
        Write-Host "Overriding test path to: $TestPath" -ForegroundColor Yellow
    }
    
    if ($TestName) {
        $config.Filter.FullName = $TestName
        Write-Host "Filtering to specific test: $TestName" -ForegroundColor Yellow
    }
    
    # Disable coverage if explicitly not requested
    if (-not $Coverage) {
        $config.CodeCoverage.Enabled = $false
    }
} else {
    # Use the original inline configuration
    $config = New-PesterConfiguration
    $config.Run.PassThru = $true  # Enable PassThru to capture results
    $config.Output.Verbosity = 'Detailed'

    # Set the test path based on parameters
    if ($TestPath) {
        # Use the specific file path
        $config.Run.Path = $TestPath
        Write-Host "Running tests from specific path: $TestPath" -ForegroundColor Cyan
    } else {
        # Use the default tests directory
        $config.Run.Path = $TestsRoot
        Write-Host "Running Pester tests from $TestsRoot" -ForegroundColor Cyan
    }

    # If a specific test name is provided, only run that test
    if ($TestName) {
        $config.Filter.FullName = $TestName
    }
    
    # Configure code coverage if requested
    if ($Coverage) {
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = "$PSScriptRoot\modules\*.psm1"
        $config.CodeCoverage.OutputPath = "$PSScriptRoot\TestResults\coverage.xml"
        $config.CodeCoverage.OutputFormat = 'JaCoCo'
    }
}

# Run the tests and store the results
Write-Host "Running Pester tests..." -ForegroundColor Cyan
$results = Invoke-Pester -Configuration $config

# Display a summary of the test results
Write-Host "`n----- Test Summary -----" -ForegroundColor Cyan

if ($null -eq $results) {
    Write-Host "No test results returned. Check if Pester is running correctly." -ForegroundColor Red
} else {
    # Format numbers for display with consistent decimal places
    $durationFormatted = [math]::Round($results.Duration.TotalSeconds, 2)
    
    # Display test counts with appropriate colors
    $passedColor = if ($results.FailedCount -eq 0 -and $results.PassedCount -gt 0) { "Green" } else { "Yellow" }
    $failedColor = if ($results.FailedCount -gt 0) { "Red" } else { "Green" }
    $skippedColor = if ($results.SkippedCount -gt 0) { "Yellow" } else { "Cyan" }
    
    Write-Host "Tests Passed: $($results.PassedCount) of $($results.TotalCount)" -ForegroundColor $passedColor
    Write-Host "Tests Failed: $($results.FailedCount)" -ForegroundColor $failedColor
    Write-Host "Tests Skipped: $($results.SkippedCount)" -ForegroundColor $skippedColor
    Write-Host "Duration: $durationFormatted seconds" -ForegroundColor Cyan
    
    # Display code coverage information if enabled
    if ($results.CodeCoverage) {
        $coveragePercent = [math]::Round(($results.CodeCoverage.CoveragePercent), 2)
        $coverageColor = switch ($coveragePercent) {
            { $_ -ge 90 } { "Green" }
            { $_ -ge 70 } { "Yellow" }
            default { "Red" }
        }
        
        Write-Host "`n----- Code Coverage -----" -ForegroundColor Cyan
        Write-Host "Coverage: $coveragePercent%" -ForegroundColor $coverageColor
        Write-Host "Lines Covered: $($results.CodeCoverage.CommandsExecutedCount)" -ForegroundColor Green
        Write-Host "Lines Missed: $($results.CodeCoverage.CommandsMissedCount)" -ForegroundColor Red
        
        # Display per-file coverage table
        if ($results.CodeCoverage.CommandsExecuted -or $results.CodeCoverage.CommandsMissed) {
            Write-Host "`n----- Coverage by File -----" -ForegroundColor Cyan
            
            # Group commands by file and calculate statistics
            $fileStats = @{
            }
            
            # Process executed commands
            foreach ($command in $results.CodeCoverage.CommandsExecuted) {
                $fileName = Split-Path $command.File -Leaf
                if (-not $fileStats.ContainsKey($fileName)) {
                    $fileStats[$fileName] = @{ Covered = 0; Missed = 0 }
                }
                $fileStats[$fileName].Covered++
            }
            
            # Process missed commands
            foreach ($command in $results.CodeCoverage.CommandsMissed) {
                $fileName = Split-Path $command.File -Leaf
                if (-not $fileStats.ContainsKey($fileName)) {
                    $fileStats[$fileName] = @{ Covered = 0; Missed = 0 }
                }
                $fileStats[$fileName].Missed++
            }
            
            # Create table data
            $tableData = @()
            foreach ($file in $fileStats.Keys) {
                $covered = $fileStats[$file].Covered
                $missed = $fileStats[$file].Missed
                $total = $covered + $missed
                $percentage = if ($total -gt 0) { [math]::Round(($covered / $total) * 100, 1) } else { 0 }
                
                $tableData += [PSCustomObject]@{
                    'File' = $file
                    'Lines Covered' = $covered
                    'Lines Missed' = $missed
                    'Coverage %' = $percentage
                }
            }
            
            # Display the table sorted by coverage percentage (descending)
            $tableData | Sort-Object 'Coverage %' -Descending | Format-Table -AutoSize
        }
        
        if ($config.CodeCoverage.OutputPath) {
            $reportPath = $config.CodeCoverage.OutputPath
            if ($reportPath -like "*coverage.xml*" -and (Test-Path "$PSScriptRoot\TestResults\coverage.xml")) {
                $reportPath = "$PSScriptRoot\TestResults\coverage.xml"
            }
            Write-Host "Coverage report saved to: $reportPath" -ForegroundColor Cyan
        }
        
        # Check coverage threshold if specified
        if ($CoverageThreshold -gt 0 -and $coveragePercent -lt $CoverageThreshold) {
            Write-Host "WARNING: Coverage $coveragePercent% is below threshold of $CoverageThreshold%" -ForegroundColor Red
            if ($results.FailedCount -eq 0) {
                # Set failed count to 1 if coverage is below threshold
                $global:LASTEXITCODE = 1
            }
        }
    }
}

# Return the results object for potential further processing
# Also return exit code based on test results for CI/CD integration
if ($null -eq $results) {
    return $null
} elseif ($results.FailedCount -gt 0) {
    # Non-zero exit code for CI/CD systems when tests fail
    # But still return the results object when used interactively
    exit 1
} else {
    # Don't output the entire results object
    return
}

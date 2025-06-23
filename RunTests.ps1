# Run all Pester tests in the project
param(
    [Parameter()]
    [string]$TestName = "",
    
    [Parameter()]
    [string]$TestPath = "",
    
    [Parameter()]
    [switch]$Coverage
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
    $config.CodeCoverage.OutputPath = "$PSScriptRoot\coverage.xml"
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
}

# Run the tests and store the results
Write-Host "Running Pester tests from $TestsRoot" -ForegroundColor Cyan
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

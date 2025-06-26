# Pester Configuration for Claude Task Runner
# This configuration enables comprehensive code coverage and test settings

$config = New-PesterConfiguration

# Basic configuration
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'

# Test discovery and execution
$config.Run.Path = @(
    "$PSScriptRoot\tests"
)

# Exclude test helper modules from being considered as tests
$config.Run.ExcludePath = @(
    "$PSScriptRoot\tests\TestHelpers\*"
)

# Code Coverage Configuration
$config.CodeCoverage.Enabled = $true

# Include all PowerShell module files for coverage analysis
$config.CodeCoverage.Path = @(
    "$PSScriptRoot\modules\*.psm1",
    "$PSScriptRoot\claude.ps1"
)

# Note: Pester 5.x automatically excludes test files from coverage
# The ExcludePath property is not available in all versions

# Coverage output settings
$config.CodeCoverage.OutputPath = "$PSScriptRoot\TestResults\coverage.xml"
$config.CodeCoverage.OutputFormat = 'JaCoCo'  # Standard format for CI/CD integration
$config.CodeCoverage.OutputEncoding = 'UTF8'

# Test result output
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = "$PSScriptRoot\TestResults\testresults.xml"
$config.TestResult.OutputFormat = 'NUnitXml'  # Standard format for CI/CD integration

# Filter settings - useful for running specific tests
# $config.Filter.Tag = @('Unit', 'Integration')  # Uncomment to filter by tags
# $config.Filter.ExcludeTag = @('Slow')          # Uncomment to exclude specific tags

# Should settings - control how strict the tests are
$config.Should.ErrorAction = 'Stop'  # Stop on first assertion failure for faster feedback

# Export the configuration so it can be used by other scripts
return $config

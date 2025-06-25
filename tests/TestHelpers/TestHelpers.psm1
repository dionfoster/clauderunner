# TestHelpers.psm1 - Common test functionality for the Claude Task Runner

<#
.SYNOPSIS
Common test setup and utilities for Claude Task Runner tests.

.DESCRIPTION
This module provides shared functionality for test files to reduce duplication
and ensure consistent test patterns across the codebase.
#>

<#
.SYNOPSIS
Sets up a standard Pester test environment with log file and module imports.

.DESCRIPTION
Creates a test log file, imports required modules in the correct order,
and sets up the logging system for tests.

.PARAMETER ModulesToImport
Array of module names to import (without the .psm1 extension).

.PARAMETER TestLogPath
Path for the test log file. If not provided, uses TestDrive or temp directory.

.OUTPUTS
Returns a hashtable with test environment information.
#>
function Initialize-StandardTestEnvironment {
    param(
        [Parameter(Mandatory=$false)]
        [string[]]$ModulesToImport = @("Logging", "StateManagement", "StateVisualization"),
        
        [Parameter(Mandatory=$false)]
        [string]$TestLogPath
    )
    
    # Determine test log path
    if (-not $TestLogPath) {
        if (Test-Path "TestDrive:\") {
            $TestLogPath = "TestDrive:\claude_test.log"
        } else {
            $TestLogPath = "$env:TEMP\claude_test.log"
        }
    }
    
    # Create test log file
    $logDir = Split-Path -Parent $TestLogPath
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    New-Item -Path $TestLogPath -ItemType File -Force | Out-Null
    
    # Import modules in dependency order
    foreach ($moduleName in $ModulesToImport) {
        $modulePath = "$PSScriptRoot\..\modules\$moduleName.psm1"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force
        }
    }
    
    # Set the log path for the logging module
    if (Get-Command -Name Set-LogPath -ErrorAction SilentlyContinue) {
        Set-LogPath -Path $TestLogPath
    }
    
    return @{
        TestLogPath = $TestLogPath
        ModulesImported = $ModulesToImport
    }
}

<#
.SYNOPSIS
Resets the test log file and clears any existing content.

.DESCRIPTION
Removes and recreates the test log file to ensure a clean slate for each test.

.PARAMETER TestLogPath
Path to the test log file to reset.
#>
function Reset-TestLogFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestLogPath
    )
    
    if (Test-Path $TestLogPath) {
        Remove-Item $TestLogPath -Force
    }
    
    $logDir = Split-Path -Parent $TestLogPath
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    New-Item -Path $TestLogPath -ItemType File -Force | Out-Null
}

<#
.SYNOPSIS
Validates that log content matches expected patterns.

.DESCRIPTION
Reads the test log file and validates that it contains expected content patterns.
Provides better error messages than raw Should -Match assertions.

.PARAMETER TestLogPath
Path to the test log file to validate.

.PARAMETER ExpectedPatterns
Array of regex patterns that should be found in the log.

.PARAMETER UnexpectedPatterns
Array of regex patterns that should NOT be found in the log.

.OUTPUTS
Returns $true if validation passes, throws descriptive error if not.
#>
function Assert-LogContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestLogPath,
        
        [Parameter(Mandatory=$false)]
        [string[]]$ExpectedPatterns = @(),
        
        [Parameter(Mandatory=$false)]
        [string[]]$UnexpectedPatterns = @()
    )
    
    if (-not (Test-Path $TestLogPath)) {
        throw "Test log file does not exist: $TestLogPath"
    }
    
    $logContent = Get-Content -Path $TestLogPath -Raw
    
    foreach ($pattern in $ExpectedPatterns) {
        if ($logContent -notmatch $pattern) {
            throw "Expected pattern not found in log: '$pattern'`nLog contents:`n$logContent"
        }
    }
    
    foreach ($pattern in $UnexpectedPatterns) {
        if ($logContent -match $pattern) {
            throw "Unexpected pattern found in log: '$pattern'`nLog contents:`n$logContent"
        }
    }
    
    return $true
}

<#
.SYNOPSIS
Creates a mock function for state management variable access.

.DESCRIPTION
Provides a consistent way to mock and access state management variables in tests.

.PARAMETER ModuleName
Name of the module containing the variables.

.PARAMETER VariableName
Name of the variable to access.

.PARAMETER MockValue
Value to return when the variable is accessed.
#>
function New-StateManagementVariableMock {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory=$true)]
        [string]$VariableName,
        
        [Parameter(Mandatory=$false)]
        [object]$MockValue
    )
    
    $module = Get-Module $ModuleName
    if (-not $module) {
        throw "Module $ModuleName is not loaded"
    }
    
    # Create a script block that returns the mock value
    $scriptBlock = [scriptblock]::Create("return `$MockValue")
    
    # Mock the variable access
    Mock -ModuleName $ModuleName -CommandName "Get-Variable" -MockWith $scriptBlock -ParameterFilter { $Name -eq $VariableName }
}

<#
.SYNOPSIS
Creates a standard BeforeEach block for test contexts.

.DESCRIPTION
Returns a scriptblock that can be used as a BeforeEach block in Pester tests.
This ensures consistent test setup across different test files.

.PARAMETER TestLogPath
Path to the test log file to reset in BeforeEach.

.PARAMETER AdditionalSetup
Additional setup commands to run in BeforeEach.
#>
function Get-StandardBeforeEach {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestLogPath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$AdditionalSetup
    )
    
    return {
        # Reset log file
        Reset-TestLogFile -TestLogPath $TestLogPath
        
        # Reset state machine variables if available
        if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
            Reset-StateMachineVariables
        }
        
        # Run additional setup if provided
        if ($AdditionalSetup) {
            & $AdditionalSetup
        }
    }
}

# Export the functions
Export-ModuleMember -Function Initialize-StandardTestEnvironment, Reset-TestLogFile, Assert-LogContent, New-StateManagementVariableMock, Get-StandardBeforeEach
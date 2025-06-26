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
        [string]$TestLogPath,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeStateManagement,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeCommonMocks
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
    
    # Import modules in dependency order with Global scope
    foreach ($moduleName in $ModulesToImport) {
        $modulePath = "$PSScriptRoot\..\..\modules\$moduleName.psm1"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -Global
        } else {
            Write-Warning "Module not found: $modulePath"
        }
    }
    
    # Set the log path for the logging module
    if (Get-Command -Name Set-LogPath -ErrorAction SilentlyContinue) {
        Set-LogPath -Path $TestLogPath
    }
    
    # Add helper functions if state management is included
    if ($IncludeStateManagement -or $ModulesToImport -contains "StateManagement") {
        Add-StateManagementHelpers
    }
    
    # Add common mocks if requested
    if ($IncludeCommonMocks) {
        Add-CommonTestMocks
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
        [string]$Pattern,
        
        [Parameter(Mandatory=$false)]
        [string[]]$ExpectedPatterns = @(),
        
        [Parameter(Mandatory=$false)]
        [string[]]$UnexpectedPatterns = @()
    )
    
    if (-not (Test-Path $TestLogPath)) {
        throw "Test log file does not exist: $TestLogPath"
    }
    
    $logContent = Get-Content -Path $TestLogPath -Raw
    
    # Handle single pattern parameter
    if ($Pattern) {
        $ExpectedPatterns += $Pattern
    }
    
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
        [Parameter(Mandatory=$false)]
        [string]$TestLogPath,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeStateReset,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$AdditionalSetup
    )
    
    return {
        # Reset log file
        $logPath = if ($TestLogPath) { $TestLogPath } else { $script:TestLogPath }
        if ($logPath) {
            Reset-TestLogFile -TestLogPath $logPath
        }
        
        # Reset state machine variables if requested
        if ($IncludeStateReset -and (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue)) {
            Reset-StateMachineVariables
        }
        
        # Run additional setup if provided
        if ($AdditionalSetup) {
            & $AdditionalSetup
        }
    }.GetNewClosure()
}

<#
.SYNOPSIS
Adds helper functions for state management testing.

.DESCRIPTION
Creates global helper functions that are commonly needed for state management tests.
#>
function Add-StateManagementHelpers {
    # Helper function to access module variables
    function global:Get-StateManagementVar {
        param([string]$VarName)
        $module = Get-Module StateManagement
        if ($module) {
            return & $module ([scriptblock]::Create("return `$script:$VarName"))
        }
        return $null
    }
      # Helper function to reset state machine variables
    function global:Reset-StateMachineVariables {
        # Try to call the actual module function first
        $module = Get-Module StateManagement
        if ($module) {
            & $module ([scriptblock]::Create("Reset-StateMachineVariables"))
        } else {
            # Fallback: Reset global variables if they exist
            if (Get-Variable -Name "ProcessedStates" -Scope Global -ErrorAction SilentlyContinue) {
                $global:ProcessedStates = @{}
            }
            if (Get-Variable -Name "TotalStartTime" -Scope Global -ErrorAction SilentlyContinue) {
                $global:TotalStartTime = $null
            }
            if (Get-Variable -Name "CurrentState" -Scope Global -ErrorAction SilentlyContinue) {
                $global:CurrentState = $null
            }
            # Additional variables used in TestEnvironment
            $global:StateTransitionStarted = $false
            $global:StateStartTimes = @{}
            $global:ActionStartTimes = @{}
        }
    }
}

<#
.SYNOPSIS
Adds common test mocks used across multiple test files.

.DESCRIPTION
Sets up standard mocks that are frequently used in tests.
#>
function Add-CommonTestMocks {
    # Mock for Write-Host to avoid console output during tests
    if (Get-Module Logging) {
        Mock Write-Host { } -ModuleName Logging
    }
    
    # Mock for Write-Log function used in modules (global mock for tests)
    if (-not (Get-Command -Name Write-Log -ErrorAction SilentlyContinue)) {
        function global:Write-Log {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Message,
                
                [Parameter(Mandatory = $false)]
                [string]$Level = "INFO",
                
                [Parameter(Mandatory = $false)]
                [string]$LogPath
            )
            
            # When running in tests, write to the test log file
            $timestamp = Get-Date -Format "HH:mm:ss"
            $emoji = "🔧"
            
            # Use the TestLogPath if no LogPath is provided
            if (-not $LogPath) {
                $LogPath = if (Get-Variable -Name TestLogPath -Scope Script -ErrorAction SilentlyContinue) { 
                    $script:TestLogPath 
                } else { 
                    "$env:TEMP\claude_test.log" 
                }
            }
            
            # Log with timestamp to file
            $logMessage = "[$timestamp] [$Level] $emoji │  $Message"
            $logMessage | Out-File -FilePath $LogPath -Append -Encoding UTF8
        }
    }
    
    # Mock for exit function to prevent tests from exiting PowerShell
    if (-not (Get-Command -Name exit -ErrorAction SilentlyContinue)) {
        function global:exit {
            param(
                [Parameter(Mandatory = $false)]
                [int]$ExitCode = 0
            )
            
            # When running in tests, we don't want to actually exit the process
            return
        }
    }
    
    # Mock for ConvertFrom-Yaml function used in Configuration module
    if (-not (Get-Command -Name ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
        function global:ConvertFrom-Yaml {
            param(
                [Parameter(Mandatory = $true)]
                [string]$YamlString
            )
            
            # Simple YAML parser for tests - handles basic key-value pairs
            $result = @{}
            $lines = $YamlString -split "`n"
            
            foreach ($line in $lines) {
                if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith('#')) {
                    continue
                }
                
                $content = $line.Trim()
                if ($content -match '^([^:]+):\s*(.*)$') {
                    $key = $Matches[1].Trim()
                    $value = $Matches[2].Trim()
                    
                    if (-not [string]::IsNullOrEmpty($value)) {
                        # Remove quotes if present
                        if ($value -match '^"(.*)"$' -or $value -match '^''(.*)''$') {
                            $value = $Matches[1]
                        }
                        $result[$key] = $value
                    } else {
                        $result[$key] = @{}
                    }
                }
            }
            
            return $result
        }
    }
}

<#
.SYNOPSIS
Creates a standard BeforeAll scriptblock for test files.

.DESCRIPTION
Returns a scriptblock that can be used as BeforeAll in Pester tests.
This ensures consistent setup across different test files.

.PARAMETER ModulesToImport
Array of module names to import.

.PARAMETER IncludeStateManagement
Include state management helper functions.

.PARAMETER IncludeCommonMocks
Include common test mocks.

.PARAMETER TestLogPath
Custom test log path (optional).
#>
function Get-StandardBeforeAll {
    param(
        [Parameter(Mandatory=$false)]
        [string[]]$ModulesToImport = @("Logging", "StateManagement", "StateVisualization"),
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeStateManagement,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeCommonMocks,
        
        [Parameter(Mandatory=$false)]
        [string]$TestLogPath
    )
    
    return {
        # Set up test log path
        $script:TestLogPath = if ($TestLogPath) { $TestLogPath } else { Join-Path $TestDrive "test.log" }
        
        # Initialize standard test environment
        $env = Initialize-StandardTestEnvironment -ModulesToImport $ModulesToImport -TestLogPath $script:TestLogPath -IncludeStateManagement:$IncludeStateManagement -IncludeCommonMocks:$IncludeCommonMocks
    }.GetNewClosure()
}

<#
.SYNOPSIS
Sets a mock value for a script-level variable in a module.

.DESCRIPTION
This function allows tests to mock script-level variables in PowerShell modules
for testing purposes. It directly manipulates the module's script scope.

.PARAMETER Name
The name of the script variable to mock (without the $script: prefix).

.PARAMETER Value
The mock value to set for the variable.

.PARAMETER ModuleName
The name of the module where the variable exists. Defaults to 'StateManagement'.
#>
function Set-ScriptVariableMock {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [object]$Value,
        
        [Parameter(Mandatory=$false)]
        [string]$ModuleName = "StateManagement"
    )
    
    $module = Get-Module $ModuleName
    if ($module) {
        # Set the script variable in the module's scope
        & $module ([scriptblock]::Create("`$script:$Name = `$args[0]")) $Value
    } else {
        Write-Warning "Module $ModuleName not found. Cannot set script variable $Name."
    }
}

<#
.SYNOPSIS
Common test patterns and constants used across test files.
#>
$global:CommonTestPatterns = @{
    StateHeader = "┌─ STATE: 🔄"
    DependenciesNone = "Dependencies: none"
    ActionsHeader = "Actions:"
    StateTransitions = "STATE TRANSITIONS:"
    ExecutionSummary = "EXECUTION SUMMARY"
    ResultCompleted = "Result: ✅ COMPLETED"
    ResultFailed = "Result: ❌ FAILED"
    StatusSuccess = "Status: ✓ SUCCESS"
    StatusFailed = "Status: ✗ FAILED"
}

# Global state machine variables for testing
$global:StatusIcons = @{
    "Processing"  = "🔄"
    "Completed"   = "✅"
    "Failed"      = "❌"
    "Skipped"     = "⏭️"
    "Executing"   = "⏳"
    "Success"     = "✓"
    "Error"       = "✗"
    "Warning"     = "⚠️"
    "Checking"    = "🔍"
    "Ready"       = "✅"
    "NotReady"    = "❌"
}

# Export the functions
Export-ModuleMember -Function Initialize-StandardTestEnvironment, Reset-TestLogFile, Assert-LogContent, New-StateManagementVariableMock, Get-StandardBeforeEach, Add-StateManagementHelpers, Add-CommonTestMocks, Get-StandardBeforeAll, Set-ScriptVariableMock
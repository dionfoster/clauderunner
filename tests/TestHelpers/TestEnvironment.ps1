# TestEnvironment.ps1 - Common setup for all test files

# Import TestHelpers module to avoid duplication
Import-Module "$PSScriptRoot\TestHelpers.psm1" -Force -Global

# Set script-scope variables for use in tests
$script:ModuleRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\modules").Path

# Initialize test log path using TestHelpers logic
$script:TestLogPath = if (Test-Path "TestDrive:\") { "TestDrive:\claude_test.log" } else { "$env:TEMP\claude_test.log" }

# Global state machine variables
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

function global:Initialize-TestEnvironment {
    # Initialize test state using TestHelpers
    Reset-StateMachineVariables
    
    # Create test log file using TestHelpers
    Reset-TestLogFile -TestLogPath $script:TestLogPath
}

function global:Reset-LogFile {
    # Delegate to TestHelpers function to avoid duplication
    Reset-TestLogFile -TestLogPath $script:TestLogPath
}

function global:Remove-TestEnvironment {
    # Clean up test log files using TestHelpers
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
}

# Use the Reset-StateMachineVariables function from TestHelpers module
# No need to redefine it here since it's imported

function global:Update-ModuleScriptVariables {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSModuleInfo]$Module
    )
    
    # This is a safer way to update script variables in the module
    & $Module ([scriptblock]::Create(@"
        `$script:StatusIcons = `$global:StatusIcons
        `$script:StateTransitionStarted = `$global:StateTransitionStarted
        `$script:TotalStartTime = `$global:TotalStartTime
        `$script:StateStartTimes = `$global:StateStartTimes
        `$script:ActionStartTimes = `$global:ActionStartTimes
        `$script:ProcessedStates = `$global:ProcessedStates
"@))
}

function global:Get-ModuleScriptVar {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [string]$ModuleName = "Logging"
    )
    
    # Use the helper function from TestHelpers module
    return Get-StateManagementVar -VarName $Name
}

function global:Test-LogContains {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern
    )
    
    # Use the TestHelpers Assert-LogContent function
    try {
        Assert-LogContent -TestLogPath $script:TestLogPath -Pattern $Pattern
        return $true
    }
    catch {
        return $false
    }
}

# Remove the duplicated Set-ScriptVariableMock function since it's available in TestHelpers module

# Mock for Write-Log function used in modules
function global:Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath = $script:TestLogPath
    )
    
    # When running in tests, write to the test log file
    $timestamp = Get-Date -Format "HH:mm:ss"
    $emoji = "🔧"
    
    # Log with timestamp to file
    $logMessage = "[$timestamp] [$Level] $emoji │  $Message"
    $logMessage | Out-File -FilePath $script:TestLogPath -Append -Encoding UTF8
}

# Mock for exit function
function global:exit {
    param(
        [Parameter(Mandatory = $false)]
        [int]$ExitCode = 0
    )
    
    # When running in tests, we don't want to actually exit the process
    # This is just a mock for the function
    return
}

# Mock for ConvertFrom-Yaml function used in Configuration module
function global:ConvertFrom-Yaml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$YamlString
    )
    
    # In tests, we'll parse YAML using a simple approach
    # This is just for testing and won't handle complex YAML correctly
    
    # Define a simple YAML parser for tests
    $result = @{
    }
    $lines = $YamlString -split "`n"
    
    $currentSection = $result
    $currentPath = @()
    
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith('#')) {
            continue
        }
        
        # Get indent level and key/value
        $indent = ($line -replace '^(\s*).*$', '$1').Length
        $content = $line.Trim()
        
        if ($content -match '^([^:]+):\s*(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            
            if ([string]::IsNullOrEmpty($value)) {
                # This is a section
                $currentSection[$key] = @{
                }
                $currentPath += $key
            }
            else {
                # Remove quotes if present
                if ($value -match '^"(.*)"$' -or $value -match '^''(.*)''$') {
                    $value = $Matches[1]
                }
                
                $currentSection[$key] = $value
            }
        }
    }
    
    return $result
}

# Export functions (not using Export-ModuleMember since this is not a module)
# Functions are exported with global: prefix

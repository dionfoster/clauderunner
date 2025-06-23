# TestEnvironment.ps1 - Common setup for all test files

# Set script-scope variables for use in tests
$script:ModuleRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\modules").Path

# Create a TestDrive item if it doesn't exist (for Pester 5)
if (-not (Test-Path "TestDrive:\")) {
    New-Item -Path "TestDrive:\" -ItemType Directory -Force | Out-Null
}

# Ensure TestLogPath is initialized with a valid default value
$script:TestLogPath = "$env:TEMP\claude_test.log"
# Try to use TestDrive if available
if (Test-Path "TestDrive:\") {
    $script:TestLogPath = "TestDrive:\claude_test.log"
}

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

function global:Initialize-TestEnvironment {
    # Initialize test state
    Reset-StateMachineVariables
    
    # Create test log file
    Reset-LogFile
}

function global:Reset-LogFile {
    # Ensure we have a valid log path
    if ([string]::IsNullOrEmpty($script:TestLogPath)) {
        $script:TestLogPath = "$env:TEMP\claude_test.log"
    }
    
    # Remove the log file if it exists
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
    
    # Create a new log file
    $logDir = Split-Path -Parent $script:TestLogPath
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    New-Item -Path $script:TestLogPath -ItemType File -Force | Out-Null
    
    # Set the global log path for the module if the function exists
    if (Get-Command -Name Set-LogPath -ErrorAction SilentlyContinue) {
        Set-LogPath -Path $script:TestLogPath
    }
}

function global:Cleanup-TestEnvironment {
    # Clean up test log files
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
}

function global:Reset-StateMachineVariables {
    # Initialize global variables to mirror module script variables
    $global:StateTransitionStarted = $false
    $global:TotalStartTime = $null
    $global:StateStartTimes = @{}
    $global:ActionStartTimes = @{}
    $global:ProcessedStates = @{}
}

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
    
    # Access script variables from the module's scope
    $module = Get-Module $ModuleName
    if ($module) {
        return & $module ([scriptblock]::Create("return `$script:$Name"))
    }
    return $null
}

function global:Test-LogContains {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern
    )
    
    $logContent = Get-Content -Path $script:TestLogPath -Raw
    return $logContent -match $Pattern
}

function global:Mock-ScriptVar {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        $Value,
        
        [Parameter(Mandatory=$false)]
        [string]$ModuleName = "Logging"
    )
    
    # Set script variable value in the module's scope
    $module = Get-Module $ModuleName
    if ($module) {
        & $module ([scriptblock]::Create("`$script:$Name = `$args[0]")) $Value
        
        # Also update the global copy
        if (Test-Path "variable:global:$Name") {
            Set-Variable -Name $Name -Value $Value -Scope Global
        }
    }
}

# Export functions (not using Export-ModuleMember since this is not a module)
# Functions are exported with global: prefix

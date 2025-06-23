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
    
    # When running in tests, we don't need to actually write to a log file
    # This is just a mock for the function
    return
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
    $currentIndent = 0
    
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
                $currentIndent = $indent
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

function global:Initialize-LoggingModuleVars {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSModuleInfo]$Module
    )
    
    # Reset global variables first
    Reset-StateMachineVariables
    
    # Update the module's script variables
    & $Module {
        $script:StateTransitionStarted = $false
        $script:TotalStartTime = $null
        $script:StateStartTimes = @{}
        $script:ActionStartTimes = @{}
        $script:ProcessedStates = @{}
    }
}

# Helper function to get script variable values from the module
function global:Get-LoggingModuleVar {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSModuleInfo]$Module,
        
        [Parameter(Mandatory=$true)]
        [string]$VarName
    )
    
    # Get the value of the script variable from the module
    $value = & $Module { param($name) Get-Variable -Name $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue } $VarName
    return $value
}

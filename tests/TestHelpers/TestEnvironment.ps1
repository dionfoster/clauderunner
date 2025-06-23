# TestEnvironment.ps1 - Common setup for all test files

# Set script-scope variables for use in tests
$script:ModuleRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\modules").Path

# Create a TestDrive item if it doesn't exist (for Pester 5)
if (-not (Test-Path "TestDrive:\")) {
    New-Item -Path "TestDrive:\" -ItemType Directory -Force | Out-Null
}
$script:TestLogPath = "TestDrive:\claude_test.log"

function Initialize-TestEnvironment {
    # Initialize test state
    $script:StateTransitionStarted = $false
    $script:TotalStartTime = $null
    $script:StateStartTimes = @{}
    $script:ProcessedStates = @{}
    
    # Create test log file
    Reset-LogFile
}

function Reset-LogFile {
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
    New-Item -Path $script:TestLogPath -ItemType File -Force | Out-Null
    
    # Set the global log path for the module if the function exists
    if (Get-Command -Name Set-LogPath -ErrorAction SilentlyContinue) {
        Set-LogPath -Path $script:TestLogPath
    }
}

function Cleanup-TestEnvironment {
    # Clean up test log files
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
}

function Reset-StateMachineVariables {
    $script:StateTransitionStarted = $false
    $script:TotalStartTime = $null
    $script:StateStartTimes = @{}
    $script:ProcessedStates = @{}
}

function Test-LogContains {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern
    )
    
    $logContent = Get-Content -Path $script:TestLogPath -Raw
    return $logContent -match $Pattern
}

# Export functions (not using Export-ModuleMember since this is not a module)
# Initialize-TestEnvironment, Reset-LogFile, Cleanup-TestEnvironment, Reset-StateMachineVariables, Test-LogContains

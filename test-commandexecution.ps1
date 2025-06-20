# test-commandexecution.ps1 - Test script for the refactored CommandExecution module
param(
    [switch]$UseStateMachineLogging
)

$script:LogPath = "test-commandexecution.log"

# Import modules
$modulesPath = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $modulesPath "Logging.psm1") -Force
Import-Module (Join-Path $modulesPath "CommandExecution.psm1") -Force

# Set the log path in the logging module
Set-LogPath -Path $script:LogPath

# Set the logging mode based on parameter
if ($UseStateMachineLogging) {
    Set-LoggingMode -Mode "StateMachine"
    Write-Host "Using State Machine Logging Mode" -ForegroundColor Cyan
} else {
    Set-LoggingMode -Mode "Standard"
    Write-Host "Using Standard Logging Mode" -ForegroundColor Cyan
}

# Create a fake StateName for testing
$StateName = "TestState"

# Test the Start-StateTransitions function
if ($UseStateMachineLogging) {
    Start-StateTransitions
    Start-StateProcessing -StateName $StateName -Dependencies @()
}

# Test 1: Simple command that succeeds
Write-Host "`nTest 1: Simple command that succeeds" -ForegroundColor Yellow
if ($UseStateMachineLogging) {
    Start-StateActions -StateName $StateName
    $actionId = Start-StateAction -StateName $StateName -ActionType "Command" -ActionCommand "Get-Date" -Description "Get current date"
}

$result = CommandExecution\Invoke-Command -Command "Get-Date" -Description "Get current date" -StateName $StateName

if ($UseStateMachineLogging) {
    Complete-StateAction -StateName $StateName -ActionId $actionId -Success $result
}

Write-Host "Result: $result" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Test 2: Command that fails
Write-Host "`nTest 2: Command that fails" -ForegroundColor Yellow
if ($UseStateMachineLogging) {
    $actionId = Start-StateAction -StateName $StateName -ActionType "Command" -ActionCommand "Get-NonExistentCommand" -Description "Run non-existent command"
}

$result = CommandExecution\Invoke-Command -Command "Get-NonExistentCommand" -Description "Run non-existent command" -StateName $StateName

if ($UseStateMachineLogging) {
    Complete-StateAction -StateName $StateName -ActionId $actionId -Success $result -ErrorMessage "Command not found"
}

Write-Host "Result: $result" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Test 3: Command with a timeout
Write-Host "`nTest 3: Command with a timeout (should complete before timeout)" -ForegroundColor Yellow
if ($UseStateMachineLogging) {
    $actionId = Start-StateAction -StateName $StateName -ActionType "Command" -ActionCommand "Start-Sleep -Seconds 1" -Description "Sleep for 1 second with 5 second timeout"
}

$result = CommandExecution\Invoke-Command -Command "Start-Sleep -Seconds 1" -Description "Sleep for 1 second with 5 second timeout" -StateName $StateName -TimeoutSeconds 5

if ($UseStateMachineLogging) {
    Complete-StateAction -StateName $StateName -ActionId $actionId -Success $result
}

Write-Host "Result: $result" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Test 4: Command with a working directory
Write-Host "`nTest 4: Command with a working directory" -ForegroundColor Yellow
if ($UseStateMachineLogging) {
    $actionId = Start-StateAction -StateName $StateName -ActionType "Command" -ActionCommand "Get-Location" -Description "Get current location with working directory set"
}

$result = CommandExecution\Invoke-Command -Command "Get-Location" -Description "Get current location with working directory set" -StateName $StateName -WorkingDirectory "C:\"

if ($UseStateMachineLogging) {
    Complete-StateAction -StateName $StateName -ActionId $actionId -Success $result
}

Write-Host "Result: $result" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Complete the state processing
if ($UseStateMachineLogging) {
    Complete-State -StateName $StateName -Success $true
    Write-StateSummary -Success $true
}

Write-Host "`nAll tests completed. Check $script:LogPath for the log output." -ForegroundColor Green

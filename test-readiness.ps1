# test-readiness.ps1 - Test script for the refactored ReadinessChecks module
param(
    [switch]$UseStateMachineLogging
)

$script:LogPath = "test-readiness.log"

# Import modules
$modulesPath = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $modulesPath "Logging.psm1") -Force
Import-Module (Join-Path $modulesPath "ReadinessChecks.psm1") -Force
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
    Start-StateProcessing -StateName $StateName -Dependencies @("Dep1", "Dep2")
}

# Test 1: Test-WebEndpoint with a valid endpoint
Write-Host "`nTest 1: Testing Test-WebEndpoint with a valid endpoint" -ForegroundColor Yellow
$result = Test-WebEndpoint -Uri "https://www.microsoft.com" -StateName $StateName
Write-Host "Result: $result" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Test 2: Test-WebEndpoint with an invalid endpoint
Write-Host "`nTest 2: Testing Test-WebEndpoint with an invalid endpoint" -ForegroundColor Yellow
$result = Test-WebEndpoint -Uri "https://this-does-not-exist-abcdefg123456.com" -StateName $StateName
Write-Host "Result: $result" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Test 3: Test-PreCheck with a command that succeeds
Write-Host "`nTest 3: Testing Test-PreCheck with a successful command" -ForegroundColor Yellow
if ($UseStateMachineLogging) {
    Write-StateCheck -StateName $StateName -CheckType "Command" -CheckDetails "Test successful command"
}
$result = Test-PreCheck -CheckCommand "Get-Date" -StateName $StateName
if ($UseStateMachineLogging) {
    Write-StateCheckResult -StateName $StateName -IsReady $result -CheckType "Command"
}
Write-Host "Result: $result" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Test 4: Test-PreCheck with a command that fails
Write-Host "`nTest 4: Testing Test-PreCheck with a failing command" -ForegroundColor Yellow
if ($UseStateMachineLogging) {
    Write-StateCheck -StateName $StateName -CheckType "Command" -CheckDetails "Test failing command"
}
$result = Test-PreCheck -CheckCommand "Get-NonExistentCommand" -StateName $StateName
if ($UseStateMachineLogging) {
    Write-StateCheckResult -StateName $StateName -IsReady $result -CheckType "Command"
}
Write-Host "Result: $result" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Test 5: Test-EndpointReadiness with polling
Write-Host "`nTest 5: Testing Test-EndpointReadiness with a valid endpoint (polling)" -ForegroundColor Yellow
if ($UseStateMachineLogging) {
    Start-StateActions -StateName $StateName
}
$result = Test-EndpointReadiness -Uri "https://www.microsoft.com" -StateName $StateName -MaxRetries 2 -RetryInterval 1 -SuccessfulRetries 2 -MaxTimeSeconds 10
Write-Host "Result: $result" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Test 6: Test-ContinueAfter with polling a command
Write-Host "`nTest 6: Testing Test-ContinueAfter with a command (polling)" -ForegroundColor Yellow
$result = Test-ContinueAfter -Command "Get-Date" -StateName $StateName -MaxRetries 2 -RetryInterval 1 -SuccessfulRetries 2 -MaxTimeSeconds 10
Write-Host "Result: $result" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Complete the state processing
if ($UseStateMachineLogging) {
    Complete-State -StateName $StateName -Success $true
    Write-StateSummary -Success $true
}

Write-Host "`nAll tests completed. Check $script:LogPath for the log output." -ForegroundColor Green

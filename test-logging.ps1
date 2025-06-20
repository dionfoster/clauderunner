# test-logging.ps1 - Simple test for the State Machine Visualization logging format
# Import the Logging module
Import-Module (Join-Path $PSScriptRoot "modules\Logging.psm1") -Force

# Configure logging
Set-LogPath -Path "test-logging.log"

# Set the logging mode to StateMachine
Set-LoggingMode -Mode "StateMachine"

# Start simulating a run
Write-Log "▶️ Claude Task Runner (Target: nodeReady)" "INFO"
Write-Log "📋 Configuration loaded from claude.yml" "INFO"

# Simulate dockerStartup state processing
Start-StateProcessing -StateName "dockerStartup"
Write-StateCheck -StateName "dockerStartup" -CheckType "Command" -CheckDetails "docker info"
Write-StateCheckResult -StateName "dockerStartup" -IsReady $true -CheckType "Command"

# Simulate dockerReady state processing
Start-StateProcessing -StateName "dockerReady" -Dependencies @("dockerStartup")
Write-StateCheck -StateName "dockerReady" -CheckType "Command" -CheckDetails "docker info"
Write-StateCheckResult -StateName "dockerReady" -IsReady $true -CheckType "Command"

# Simulate apiReady state processing
Start-StateProcessing -StateName "apiReady" -Dependencies @("dockerReady")
Write-StateCheck -StateName "apiReady" -CheckType "Endpoint" -CheckDetails "https://localhost:5001/healthcheck"
Write-StateCheckResult -StateName "apiReady" -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"

# Simulate nodeReady state processing with actions
Start-StateProcessing -StateName "nodeReady" -Dependencies @("apiReady")
Write-StateCheck -StateName "nodeReady" -CheckType "Command" -CheckDetails "node --version"
Write-StateCheckResult -StateName "nodeReady" -IsReady $false -CheckType "Command"

# Execute actions
Start-StateActions -StateName "nodeReady"

# First action
$actionId1 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "Set-NodeVersion -Version v22.16.0"
Start-Sleep -Seconds 1  # Simulate some work
Complete-StateAction -StateName "nodeReady" -ActionId $actionId1 -Success $true

# Second action
$actionId2 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "node --version"
Start-Sleep -Seconds 1  # Simulate some work
Complete-StateAction -StateName "nodeReady" -ActionId $actionId2 -Success $true

# Third action
$actionId3 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "npm install"
Start-Sleep -Seconds 2  # Simulate some work
Complete-StateAction -StateName "nodeReady" -ActionId $actionId3 -Success $true

# Fourth action
$actionId4 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "npm run dev" -Description "Starting Identity SPA"
Start-Sleep -Seconds 1  # Simulate some work
Complete-StateAction -StateName "nodeReady" -ActionId $actionId4 -Success $true

# Complete the state
Complete-State -StateName "nodeReady" -Success $true

# Write summary
Write-StateSummary -Success $true

# Test script for state machine logging
Import-Module "$PSScriptRoot\modules\Logging.psm1" -Force

# Set logging mode to StateMachine
Set-LoggingMode -Mode "StateMachine"

# Start state transitions
Start-StateTransitions

# Process dockerStartup state
Start-StateProcessing -StateName "dockerStartup"
Write-StateCheck -StateName "dockerStartup" -CheckType "Command" -CheckDetails "docker info"
Write-StateCheckResult -StateName "dockerStartup" -IsReady $true -CheckType "Command"

# Process dockerReady state
Start-StateProcessing -StateName "dockerReady" -Dependencies @("dockerStartup")
Write-StateCheck -StateName "dockerReady" -CheckType "Command" -CheckDetails "docker info"
Write-StateCheckResult -StateName "dockerReady" -IsReady $true -CheckType "Command"

# Process apiReady state
Start-StateProcessing -StateName "apiReady" -Dependencies @("dockerReady")
Write-StateCheck -StateName "apiReady" -CheckType "Endpoint" -CheckDetails "https://localhost:5001/healthcheck"
Write-StateCheckResult -StateName "apiReady" -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"

# Process nodeReady state with actions
Start-StateProcessing -StateName "nodeReady" -Dependencies @("apiReady")
Start-StateActions -StateName "nodeReady"

$actionId1 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "Set-NodeVersion -Version v22.16.0"
Complete-StateAction -StateName "nodeReady" -ActionId $actionId1 -Success $true

$actionId2 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "node --version"
Complete-StateAction -StateName "nodeReady" -ActionId $actionId2 -Success $true

$actionId3 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "npm install"
Complete-StateAction -StateName "nodeReady" -ActionId $actionId3 -Success $true

$actionId4 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "npm run dev" -Description "Starting Identity SPA"
Complete-StateAction -StateName "nodeReady" -ActionId $actionId4 -Success $true

Complete-State -StateName "nodeReady" -Success $true

# Write summary
Write-StateSummary -Success $true

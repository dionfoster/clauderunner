# claude.ps1 - Claude MCP-style task runner with continueAfter logic and launch methods
param(
    [ValidateNotNullOrEmpty()]
    [string]$Target = "apiReady",
    [switch]$Verbose,
    [switch]$UseStateMachineLogging
)

$script:ConfigPath = "claude.yml"
$script:LogPath = "claude.log"

# Import modules
$modulesPath = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $modulesPath "Logging.psm1") -Force
Import-Module (Join-Path $modulesPath "Configuration.psm1") -Force
Import-Module (Join-Path $modulesPath "CommandExecution.psm1") -Force
Import-Module (Join-Path $modulesPath "ReadinessChecks.psm1") -Force

# Set the log path in the logging module
Set-LogPath -Path $script:LogPath
# Set the config path in the configuration module
Set-ConfigPath -Path $script:ConfigPath
# Set the global verbose flag for command execution
$global:Verbose = $Verbose

# Set the logging mode based on parameter
if ($UseStateMachineLogging) {
    Set-LoggingMode -Mode "StateMachine"
} else {
    Set-LoggingMode -Mode "Standard"
}

function Invoke-State {
    param(
        [string]$StateName,
        [hashtable]$Config,
        [System.Collections.Generic.HashSet[string]]$ProcessedStates
    )

    # Avoid infinite loops
    if ($ProcessedStates.Contains($StateName)) {
        Write-StateLog $StateName "State $StateName already processed in this run" "DEBUG"
        return $true
    }
    
    # Get state configuration - only using 'states' root key
    $stateConfig = $null
    if ($Config.states -and $Config.states.$StateName) {
        $stateConfig = $Config.states.$StateName
    }
    if (-not $stateConfig) {
        Write-StateLog $StateName "Unknown state: $StateName" "ERROR"
        return $false
    }
    
    # Validate configuration    
    try {
        Configuration\Test-StateConfiguration -StateConfig $stateConfig -StateName $StateName
    }
    catch {
        Write-StateLog $StateName "Configuration error: $($_.Exception.Message)" "ERROR"
        return $false
    }
    
    # Get dependencies
    $dependencies = @()
    if ($stateConfig.needs) {
        $dependencies = $stateConfig.needs
    }
    
    # State Machine Logging - Start State Processing
    if ($UseStateMachineLogging) {
        Start-StateProcessing -StateName $StateName -Dependencies $dependencies
    }
    else {
        Write-StateLog $StateName "Processing state: $StateName" "INFO"
    }
    
    # Handle dependencies first
    if ($stateConfig.needs) {
        if (-not $UseStateMachineLogging) {
            $depList = $stateConfig.needs -join ', '
            Write-StateLog $StateName "Resolving dependencies for $StateName`: $depList" "INFO"
        }
        
        foreach ($dependency in $stateConfig.needs) {
            if (-not (Invoke-State -StateName $dependency -Config $Config -ProcessedStates $ProcessedStates)) {
                Write-StateLog $StateName "Dependency $dependency failed for state $StateName" "ERROR"
                return $false
            }
        }
    }
    
    # Perform pre-check if defined
    $skipActions = $false
    
    if ($stateConfig.readiness) {
        if ($stateConfig.readiness.checkEndpoint) {
            # Standard logging
            if (-not $UseStateMachineLogging) {
                Write-StateLog $StateName "Checking if $StateName is already ready using endpoint..." "INFO"
            }
            # State Machine logging
            else {
                Write-StateCheck -StateName $StateName -CheckType "Endpoint" -CheckDetails $stateConfig.readiness.checkEndpoint
            }
            
            if (ReadinessChecks\Test-WebEndpoint -Uri $stateConfig.readiness.checkEndpoint -StateName $StateName) {
                # Standard logging
                if (-not $UseStateMachineLogging) {
                    Write-StateLog $StateName "✓ State $StateName is already ready via endpoint check, skipping actions" "SUCCESS"
                }
                # State Machine logging
                else {
                    Write-StateCheckResult -StateName $StateName -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
                }
                
                $skipActions = $true
            }
            else {
                # State Machine logging
                if ($UseStateMachineLogging) {
                    Write-StateCheckResult -StateName $StateName -IsReady $false -CheckType "Endpoint"
                }
            }
        }
        elseif ($stateConfig.readiness.checkCommand) {
            # Standard logging
            if (-not $UseStateMachineLogging) {
                Write-StateLog $StateName "Checking if $StateName is already ready using command..." "INFO"
            }
            # State Machine logging
            else {
                Write-StateCheck -StateName $StateName -CheckType "Command" -CheckDetails $stateConfig.readiness.checkCommand
            }
            
            $isReady = ReadinessChecks\Test-PreCheck -CheckCommand $stateConfig.readiness.checkCommand -StateName $StateName -StateConfig $stateConfig
            
            if ($isReady) {
                # State Machine logging
                if ($UseStateMachineLogging) {
                    Write-StateCheckResult -StateName $StateName -IsReady $true -CheckType "Command"
                }
                
                $skipActions = $true
            }
            else {
                # State Machine logging
                if ($UseStateMachineLogging) {
                    Write-StateCheckResult -StateName $StateName -IsReady $false -CheckType "Command"
                }
            }
        }
    }
    
    # If pre-check succeeded, skip actions and mark as processed
    if ($skipActions) {
        $ProcessedStates.Add($StateName) | Out-Null
        return $true
    }
    
    # Execute actions
    if ($stateConfig.actions) {
        # Standard logging
        if (-not $UseStateMachineLogging) {
            Write-StateLog $StateName "Executing actions for $StateName" "INFO"
        }
        # State Machine logging
        else {
            Start-StateActions -StateName $StateName
        }
        
        foreach ($action in $stateConfig.actions) {
            $params = @{
                Command = ""
                Description = "Execute command"
                StateName = $StateName
                CommandType = "powershell"
                TimeoutSeconds = 0
                LaunchVia = "console"
                WorkingDirectory = ""
            }
            
            if ($action -is [string]) {
                # Simple string command - default to PowerShell
                $params.Command = $action
            } elseif ($action.type -eq "command") {
                # Command type action
                $params.Command = $action.command
            } elseif ($action.type -eq "application") {
                # Application launch type action
                $params.Command = $action.path
                $params.LaunchVia = "windowsApp"
            } else {
                Write-StateLog $StateName "Invalid action format in state $StateName" "ERROR"
                continue
            }
            
            # Extract optional properties
            if ($action.timeout) { $params.TimeoutSeconds = $action.timeout }
            if ($action.description) { $params.Description = $action.description }
            if ($action.workingDirectory) { $params.WorkingDirectory = $action.workingDirectory }
            if ($action.newWindow) { $params.LaunchVia = "newWindow" }
            
            # State Machine logging - start action
            if ($UseStateMachineLogging) {
                $actionType = if ($action.type -eq "application") { "Application" } else { "Command" }
                $actionCommand = if ($action -is [string]) { $action } elseif ($action.type -eq "command") { $action.command } else { $action.path }
                $actionDescription = if ($action.description) { $action.description } else { "" }
                
                $actionId = Start-StateAction -StateName $StateName -ActionType $actionType -ActionCommand $actionCommand -Description $actionDescription
            }
            
            $actionSuccess = CommandExecution\Invoke-Command @params
            
            # State Machine logging - complete action
            if ($UseStateMachineLogging) {
                Complete-StateAction -StateName $StateName -ActionId $actionId -Success $actionSuccess
            }
            
            if (-not $actionSuccess) {
                # State Machine logging - complete state with failure
                if ($UseStateMachineLogging) {
                    Complete-State -StateName $StateName -Success $false -ErrorMessage "Action failed"
                }
                else {
                    Write-StateLog $StateName "Action failed in state $StateName" "ERROR"
                }
                
                return $false
            }
        }
    }
      # Handle wait polling if defined
    if ($stateConfig.readiness -and ($stateConfig.readiness.waitCommand -or $stateConfig.readiness.waitEndpoint)) {
        $maxRetries = 10
        $retryInterval = 3  
        $successfulRetries = 1
        $maxTimeSeconds = 30
        
        # Override with custom values if provided
        if ($stateConfig.readiness.maxRetries) { $maxRetries = $stateConfig.readiness.maxRetries }
        if ($stateConfig.readiness.retryInterval) { $retryInterval = $stateConfig.readiness.retryInterval }
        if ($stateConfig.readiness.successfulRetries) { $successfulRetries = $stateConfig.readiness.successfulRetries }
        if ($stateConfig.readiness.maxTimeSeconds) { $maxTimeSeconds = $stateConfig.readiness.maxTimeSeconds }
        
        # Use endpoint-based waiting if configured
        if ($stateConfig.readiness.waitEndpoint) {
            # State machine logging doesn't show polling details
            if (-not $UseStateMachineLogging) {
                Write-StateLog $StateName "Using wait endpoint for readiness polling: $($stateConfig.readiness.waitEndpoint)" "INFO"
            }
            
            if (-not (ReadinessChecks\Test-EndpointReadiness -Uri $stateConfig.readiness.waitEndpoint -StateName $StateName -MaxRetries $maxRetries -RetryInterval $retryInterval -SuccessfulRetries $successfulRetries -MaxTimeSeconds $maxTimeSeconds -Quiet:$UseStateMachineLogging)) {
                # State Machine logging - complete state with failure
                if ($UseStateMachineLogging) {
                    Complete-State -StateName $StateName -Success $false -ErrorMessage "Failed to become ready via endpoint polling"
                }
                else {
                    Write-StateLog $StateName "State $StateName failed to become ready" "ERROR"
                }
                
                return $false
            }
        }
        # Otherwise use command-based waiting
        elseif ($stateConfig.readiness.waitCommand) {
            $command = $stateConfig.readiness.waitCommand
            
            # State machine logging doesn't show polling details
            if (-not $UseStateMachineLogging) {
                Write-StateLog $StateName "Using wait command for readiness polling: $command" "INFO"
            }
            
            if (-not (ReadinessChecks\Test-ContinueAfter -Command $command -StateName $StateName -MaxRetries $maxRetries -RetryInterval $retryInterval -SuccessfulRetries $successfulRetries -MaxTimeSeconds $maxTimeSeconds -StateConfig $stateConfig -Quiet:$UseStateMachineLogging)) {
                # State Machine logging - complete state with failure
                if ($UseStateMachineLogging) {
                    Complete-State -StateName $StateName -Success $false -ErrorMessage "Failed to become ready via command polling"
                }
                else {
                    Write-StateLog $StateName "State $StateName failed to become ready" "ERROR"
                }
                
                return $false
            }
        }
    }
    
    # Mark state as processed for this run
    $ProcessedStates.Add($StateName) | Out-Null
    
    # State Machine logging - complete state with success
    if ($UseStateMachineLogging) {
        Complete-State -StateName $StateName -Success $true
    }
    else {
        Write-StateLog $StateName "State $StateName completed successfully" "SUCCESS"
    }
    
    return $true
}





# Main execution
try {
    # Standard logging
    if (-not $UseStateMachineLogging) {
        Write-Log "Starting Claude MCP-style Task Runner" "INFO"    
        Write-Log "Target state: $Target" "INFO"
    }
    # State Machine logging
    else {        Write-Log "[INFO] ▶️ Claude Task Runner (Target: $Target)" "SYSTEM"
        Write-Log "[INFO] 📋 Configuration loaded from $script:ConfigPath" "SYSTEM"
    }
    
    Configuration\Initialize-Environment
    $config = Get-Configuration
    
    # Track processed states for this run only
    $processedStates = New-Object System.Collections.Generic.HashSet[string]
    
    $success = Invoke-State -StateName $Target -Config $config -ProcessedStates $processedStates
    
    # Standard logging - Show summary
    if (-not $UseStateMachineLogging) {
        Write-Log "=== Run Summary ===" "INFO"
        if ($processedStates.Count -gt 0) {
            foreach ($stateName in $processedStates | Sort-Object) {
                $icon = Get-StateIcon $stateName
                Write-Host ("{0}{1}: ✅ PROCESSED" -f $icon, $stateName) -ForegroundColor "Green"
            }
        } else {
            Write-Host "No states were processed (all checks passed)" -ForegroundColor "Yellow"
        }
        
        if ($success) {
            Write-Log "🎉 Task runner completed successfully!" "SUCCESS"
            exit 0
        } else {
            Write-Log "❌ Task runner failed" "ERROR"
            exit 1
        }
    }
    # State Machine logging - Show summary
    else {
        Write-StateSummary -Success $success
        
        if ($success) {
            Write-Log "🎉 Task runner completed successfully!" "SUCCESS"
            exit 0
        } else {
            Write-Log "❌ Task runner failed" "ERROR"
            exit 1
        }
    }
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}

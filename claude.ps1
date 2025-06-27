# claude.ps1 - Claude MCP-style task runner with continueAfter logic and launch methods
param(
    [ValidateNotNullOrEmpty()]
    [string]$Target = "apiReady",
    [switch]$Verbose,
    [ValidateSet("Default", "Simple", "Medium", "Elaborate")]
    [string]$OutputFormat = "Default"
)

$script:ConfigPath = "claude.yml"
$script:LogPath = "claude.log"

# Import modules
$modulesPath = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $modulesPath "Logging.psm1") -Force
Import-Module (Join-Path $modulesPath "Configuration.psm1") -Force
Import-Module (Join-Path $modulesPath "CommandExecution.psm1") -Force
Import-Module (Join-Path $modulesPath "ReadinessChecks.psm1") -Force
Import-Module (Join-Path $modulesPath "StateVisualization.psm1") -Force
Import-Module (Join-Path $modulesPath "OutputFormatters.psm1") -Force

# Set the log path in the logging module
Set-LogPath -Path $script:LogPath
# Set the config path in the configuration module
Set-ConfigPath -Path $script:ConfigPath
# Set the global verbose flag for command execution
$global:Verbose = $Verbose

function Invoke-State {
    param(
        [string]$StateName,
        [hashtable]$Config,
        [System.Collections.Generic.HashSet[string]]$ProcessedStates
    )    # Avoid infinite loops
    if ($ProcessedStates.Contains($StateName)) {
        Write-Host "State $StateName already processed in this run" -ForegroundColor Cyan
        return $true
    }
    
    # Get state configuration - only using 'states' root key
    $stateConfig = $null
    if ($Config.states -and $Config.states.$StateName) {
        $stateConfig = $Config.states.$StateName
    }
    if (-not $stateConfig) {
        throw "Unknown state: $StateName"
    }
    
    # Validate configuration    
    try {
        Configuration\Test-StateConfiguration -StateConfig $stateConfig -StateName $StateName
    }
    catch {
        throw "Configuration error: $($_.Exception.Message)"
    }    # Get dependencies
    $dependencies = @()
    if ($stateConfig.needs) {
        $dependencies = $stateConfig.needs
    }
    
    # Handle dependencies first BEFORE starting state processing visualization
    if ($stateConfig.needs) {        
        foreach ($dependency in $stateConfig.needs) {            
            if (-not (Invoke-State -StateName $dependency -Config $Config -ProcessedStates $ProcessedStates)) {
                # We need to start state processing here to show the failure
                StateVisualization\Start-StateProcessing -StateName $StateName -Dependencies $dependencies
                StateVisualization\Complete-State -StateName $StateName -Success $false -ErrorMessage "Dependency $dependency failed"
                return $false
            }
        }
    }
    
    # Now start state processing visualization after dependencies are processed
    StateVisualization\Start-StateProcessing -StateName $StateName -Dependencies $dependencies
    
    # Perform pre-check if defined
    $skipActions = $false
    
    if ($stateConfig.readiness) {        
        if ($stateConfig.readiness.checkEndpoint) {
            StateVisualization\Write-StateCheck -CheckType "Endpoint" -CheckDetails $stateConfig.readiness.checkEndpoint
            
            if (ReadinessChecks\Test-WebEndpoint -Uri $stateConfig.readiness.checkEndpoint -StateName $StateName) {
                StateVisualization\Write-StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
                $skipActions = $true
            }
            else {
                StateVisualization\Write-StateCheckResult -IsReady $false -CheckType "Endpoint"
            }
        }
        elseif ($stateConfig.readiness.checkCommand) {
            StateVisualization\Write-StateCheck -CheckType "Command" -CheckDetails $stateConfig.readiness.checkCommand
            $isReady = ReadinessChecks\Test-PreCheck -CheckCommand $stateConfig.readiness.checkCommand -StateName $StateName -StateConfig $stateConfig
            
            if ($isReady) {
                StateVisualization\Write-StateCheckResult -IsReady $true -CheckType "Command"
                $skipActions = $true
            }
            else {
                StateVisualization\Write-StateCheckResult -IsReady $false -CheckType "Command"
            }
        }
    }
    # If pre-check succeeded, skip actions and mark as processed
    if ($skipActions) {
        StateVisualization\Complete-State -StateName $StateName -Success $true
        $ProcessedStates.Add($StateName) | Out-Null
        return $true
    }
    # Execute actions
    if ($stateConfig.actions) {
        StateVisualization\Start-StateActions
        
        foreach ($action in $stateConfig.actions) {
            $params = @{
                Command          = ""
                Description      = "Execute command"
                StateName        = $StateName
                CommandType      = "powershell"
                TimeoutSeconds   = 0
                LaunchVia        = "console"
                WorkingDirectory = ""
            }
            
            if ($action -is [string]) {
                # Simple string command - default to PowerShell
                $params.Command = $action
            }
            elseif ($action.type -eq "command") {
                # Command type action
                $params.Command = $action.command
            }
            elseif ($action.type -eq "application") {
                # Application launch type action
                $params.Command = $action.path
                $params.LaunchVia = "windowsApp"            
            }
            else {
                StateVisualization\Complete-State -StateName $StateName -Success $false -ErrorMessage "Invalid action format"
                return $false
            }
            
            # Extract optional properties
            if ($action.timeout) { $params.TimeoutSeconds = $action.timeout }
            if ($action.description) { $params.Description = $action.description }
            if ($action.workingDirectory) { $params.WorkingDirectory = $action.workingDirectory }
            if ($action.newWindow) { $params.LaunchVia = "newWindow" }
            
            $actionType = if ($action.type -eq "application") { "Application" } else { "Command" }
            $actionCommand = if ($action -is [string]) { $action } elseif ($action.type -eq "command") { $action.command } else { $action.path }
            $actionDescription = if ($action.description) { $action.description } else { "" }
            $actionId = StateVisualization\Start-StateAction -StateName $StateName -ActionType $actionType -ActionCommand $actionCommand -Description $actionDescription
            
            $actionSuccess = CommandExecution\Invoke-Command @params
            
            StateVisualization\Complete-StateAction -StateName $StateName -ActionId $actionId -Success $actionSuccess
            
            if (-not $actionSuccess) {
                StateVisualization\Complete-State -StateName $StateName -Success $false -ErrorMessage "Action failed"                
                return $false
            }
        }
    }    # Handle wait polling if defined
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
            if (-not (ReadinessChecks\Test-EndpointReadiness -Uri $stateConfig.readiness.waitEndpoint -StateName $StateName -MaxRetries $maxRetries -RetryInterval $retryInterval -SuccessfulRetries $successfulRetries -MaxTimeSeconds $maxTimeSeconds)) {
                StateVisualization\Complete-State -StateName $StateName -Success $false -ErrorMessage "Failed to become ready via endpoint polling"
                return $false
            }
        }
        # Otherwise use command-based waiting
        elseif ($stateConfig.readiness.waitCommand) {
            $command = $stateConfig.readiness.waitCommand
            
            if (-not (ReadinessChecks\Test-ContinueAfter -Command $command -StateName $StateName -MaxRetries $maxRetries -RetryInterval $retryInterval -SuccessfulRetries $successfulRetries -MaxTimeSeconds $maxTimeSeconds -StateConfig $stateConfig)) {
                StateVisualization\Complete-State -StateName $StateName -Success $false -ErrorMessage "Failed to become ready via command polling"
                return $false
            }
        }
    }
    # Mark state as processed for this run
    $ProcessedStates.Add($StateName) | Out-Null
    StateVisualization\Complete-State -StateName $StateName -Success $true
    return $true
}




# Main execution
try {
    Write-Log "▶️ Claude Task Runner (Target: $Target)" "SYSTEM"
    Write-Log "📋 Configuration loaded from $script:ConfigPath" "SYSTEM"
    Write-Log " " "SYSTEM"
    
    Configuration\Initialize-Environment
    $config = Get-Configuration
    
    # Get the final output format (parameter takes precedence over config)
    $finalOutputFormat = Configuration\Get-OutputFormat -Config $config -ParameterFormat $OutputFormat
    
    # Set the output format for all state visualization
    StateVisualization\Set-OutputFormat -OutputFormat $finalOutputFormat
    
    # Track processed states for this run only
    $processedStates = New-Object System.Collections.Generic.HashSet[string]
    $success = Invoke-State -StateName $Target -Config $config -ProcessedStates $processedStates
    
    # Write the unified summary (format-aware)
    StateVisualization\Write-StateSummary
    
    if ($success) {
        exit 0
    }
    else {
        Write-Log "❌ Task runner failed" "ERROR"
        exit 1
    }
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}

# claude.ps1 - Claude MCP-style task runner with continueAfter logic and launch methods
param(
    [ValidateNotNullOrEmpty()]
    [string]$Target = "apiReady",
    [switch]$Verbose
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

function Initialize-Environment {
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Log "Installing powershell-yaml module..." "INFO"
        try {
            Install-Module -Name powershell-yaml -Force -Scope CurrentUser -Repository PSGallery
            Write-Log "powershell-yaml module installed successfully." "SUCCESS"
        }
        catch {
            Write-Log "Failed to install powershell-yaml module: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }
    
    try {
        Import-Module powershell-yaml -ErrorAction Stop
    }
    catch {
        Write-Log "Failed to import powershell-yaml module: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

function Test-StateConfiguration {
    param([hashtable]$StateConfig, [string]$StateName)
    
    # Handle both classic and endpoint-based configurations
    $hasValidReadiness = $false
    
    if ($StateConfig.readiness) {
        if ($StateConfig.readiness.checkEndpoint -or $StateConfig.readiness.waitEndpoint) {
            $hasValidReadiness = $true
        } elseif ($StateConfig.readiness.checkCommand) {
            $hasValidReadiness = $true
        }
    }
    
    if (-not $StateConfig.actions -and -not $hasValidReadiness) {
        throw "State '$StateName' has no actions or valid readiness check defined"
    }
    
    if ($StateConfig.actions) {
        foreach ($action in $StateConfig.actions) {
            if ($action -is [string]) { continue }
            if (-not ($action.type -eq "command" -or $action.type -eq "application")) {
                throw "Invalid action in state '$StateName': must have type 'command' or 'application'"
            }
            if ($action.type -eq "command" -and -not $action.command) {
                throw "Invalid command action in state '$StateName': missing 'command' property"
            }
            if ($action.type -eq "application" -and -not $action.path) {
                throw "Invalid application action in state '$StateName': missing 'path' property"
            }
        }
    }
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
        Test-StateConfiguration -StateConfig $stateConfig -StateName $StateName
    }
    catch {
        Write-StateLog $StateName "Configuration error: $($_.Exception.Message)" "ERROR"
        return $false
    }
    
    Write-StateLog $StateName "Processing state: $StateName" "INFO"
    
    # Handle dependencies first
    if ($stateConfig.needs) {
        $depList = $stateConfig.needs -join ', '
        Write-StateLog $StateName "Resolving dependencies for $StateName`: $depList" "INFO"
        foreach ($dependency in $stateConfig.needs) {
            if (-not (Invoke-State -StateName $dependency -Config $Config -ProcessedStates $ProcessedStates)) {
                Write-StateLog $StateName "Dependency $dependency failed for state $StateName" "ERROR"
                return $false
            }
        }    }
    
    # Perform pre-check if defined
    $skipActions = $false
    
    if ($stateConfig.readiness) {
        if ($stateConfig.readiness.checkEndpoint) {
            Write-StateLog $StateName "Checking if $StateName is already ready using endpoint..." "INFO"
            if (ReadinessChecks\Test-WebEndpoint -Uri $stateConfig.readiness.checkEndpoint -StateName $StateName) {
                Write-StateLog $StateName "✓ State $StateName is already ready via endpoint check, skipping actions" "SUCCESS"
                $skipActions = $true
            }
        }
        elseif ($stateConfig.readiness.checkCommand) {
            if (ReadinessChecks\Test-PreCheck -CheckCommand $stateConfig.readiness.checkCommand -StateName $StateName -StateConfig $stateConfig) {
                $skipActions = $true
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
        Write-StateLog $StateName "Executing actions for $StateName" "INFO"
        
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
              if (-not (CommandExecution\Invoke-Command @params)) {
                Write-StateLog $StateName "Action failed in state $StateName" "ERROR"
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
            Write-StateLog $StateName "Using wait endpoint for readiness polling: $($stateConfig.readiness.waitEndpoint)" "INFO"
            
            if (-not (ReadinessChecks\Test-EndpointReadiness -Uri $stateConfig.readiness.waitEndpoint -StateName $StateName -MaxRetries $maxRetries -RetryInterval $retryInterval -SuccessfulRetries $successfulRetries -MaxTimeSeconds $maxTimeSeconds)) {
                Write-StateLog $StateName "State $StateName failed to become ready" "ERROR"
                return $false
            }
        }
        # Otherwise use command-based waiting
        elseif ($stateConfig.readiness.waitCommand) {
            $command = $stateConfig.readiness.waitCommand
            
            if (-not (ReadinessChecks\Test-ContinueAfter -Command $command -StateName $StateName -MaxRetries $maxRetries -RetryInterval $retryInterval -SuccessfulRetries $successfulRetries -MaxTimeSeconds $maxTimeSeconds -StateConfig $stateConfig)) {
                Write-StateLog $StateName "State $StateName failed to become ready" "ERROR"
                return $false
            }
        }
    }
    
    # Mark state as processed for this run
    $ProcessedStates.Add($StateName) | Out-Null
    Write-StateLog $StateName "State $StateName completed successfully" "SUCCESS"
    return $true
}





# Main execution
try {
    Write-Log "Starting Claude MCP-style Task Runner" "INFO"    
    Write-Log "Target state: $Target" "INFO"
    
    Initialize-Environment
    $config = Get-Configuration
    
    # Track processed states for this run only
    $processedStates = New-Object System.Collections.Generic.HashSet[string]
    
    $success = Invoke-State -StateName $Target -Config $config -ProcessedStates $processedStates
    
    # Show summary of what was processed
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
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}

# ReadinessChecks.psm1 - Claude Task Runner readiness check functions

# Access to state machine logging functions
# These are imported by the main script
function Start-StateTransitions { if (Get-Command Start-StateTransitions -ErrorAction SilentlyContinue) { Start-StateTransitions @args } }
function Start-StateProcessing { if (Get-Command Start-StateProcessing -ErrorAction SilentlyContinue) { Start-StateProcessing @args } }
function Write-StateCheck { if (Get-Command Write-StateCheck -ErrorAction SilentlyContinue) { Write-StateCheck @args } }
function Write-StateCheckResult { if (Get-Command Write-StateCheckResult -ErrorAction SilentlyContinue) { Write-StateCheckResult @args } }
function Start-StateActions { if (Get-Command Start-StateActions -ErrorAction SilentlyContinue) { Start-StateActions @args } }
function Start-StateAction { if (Get-Command Start-StateAction -ErrorAction SilentlyContinue) { Start-StateAction @args } }
function Complete-StateAction { if (Get-Command Complete-StateAction -ErrorAction SilentlyContinue) { Complete-StateAction @args } }
function Complete-State { if (Get-Command Complete-State -ErrorAction SilentlyContinue) { Complete-State @args } }
function Write-StateSummary { if (Get-Command Write-StateSummary -ErrorAction SilentlyContinue) { Write-StateSummary @args } }

<#
.SYNOPSIS
Tests if a web endpoint is accessible.

.DESCRIPTION
Attempts to access a web endpoint and returns success or failure.

.PARAMETER Uri
The URI of the endpoint to check.

.PARAMETER StateName
The name of the state for logging.

.OUTPUTS
Returns $true if the endpoint is accessible, $false otherwise.
#>
function Test-WebEndpoint {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        
        [Parameter(Mandatory=$true)]
        [string]$StateName
    )
    
    try {
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
Tests if an endpoint is ready by polling it.

.DESCRIPTION
Polls an endpoint until it's ready or times out.

.PARAMETER Uri
The URI of the endpoint to check.

.PARAMETER StateName
The name of the state for logging.

.PARAMETER MaxRetries
The maximum number of retries.

.PARAMETER RetryInterval
The interval between retries in seconds.

.PARAMETER SuccessfulRetries
The number of successful retries required.

.PARAMETER MaxTimeSeconds
The maximum time to wait in seconds.

.OUTPUTS
Returns $true if the endpoint is ready, $false otherwise.
#>
function Test-EndpointReadiness {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        
        [Parameter(Mandatory=$true)]
        [string]$StateName,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxRetries = 10,
        
        [Parameter(Mandatory=$false)]
        [int]$RetryInterval = 3,
        
        [Parameter(Mandatory=$false)]
        [int]$SuccessfulRetries = 1,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxTimeSeconds = 30,
        
        [Parameter(Mandatory=$false)]
        [switch]$Quiet
    )
    
    $attempt = 0
    $successCount = 0
    $startTime = Get-Date
    
    $pollingDetails = "Polling endpoint: $Uri (max $MaxRetries tries, ${RetryInterval}s interval, need $SuccessfulRetries successes, timeout ${MaxTimeSeconds}s)"
    $actionId = Start-StateAction -StateName $StateName -ActionType "Command" -ActionCommand "Endpoint polling" -Description $pollingDetails
    
    $finalSuccess = $false
    
    do {
        $attempt++
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        
        $success = Test-WebEndpoint -Uri $Uri -StateName $StateName
        
        if ($success) {
            $successCount++
            
            if ($successCount -ge $SuccessfulRetries) {
                Complete-StateAction -StateName $StateName -ActionId $actionId -Success $true
                $finalSuccess = $true
                return $true
            }
        } else {
            $successCount = 0  # Reset on failure
        }
        
        # Check if we have exceeded time limit
        if ($elapsed -ge $MaxTimeSeconds) {
            Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Timed out after ${elapsed}s"
            $finalSuccess = $false
            return $false
        }
        
        # Check if we have exceeded retry limit
        if ($attempt -ge $MaxRetries) {
            Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Max retries ($MaxRetries) exceeded"
            $finalSuccess = $false
            return $false
        }
        
        # Wait before next attempt
        if ($attempt -lt $MaxRetries -and $elapsed -lt $MaxTimeSeconds) {
            Start-Sleep $RetryInterval
        }
        
    } while ($true)
}

<#
.SYNOPSIS
Tests if a command indicates a state is ready.

.DESCRIPTION
Executes a command and checks if it indicates a state is ready.

.PARAMETER Command
The command to execute.

.PARAMETER StateName
The name of the state for logging.

.PARAMETER MaxRetries
The maximum number of retries.

.PARAMETER RetryInterval
The interval between retries in seconds.

.PARAMETER SuccessfulRetries
The number of successful retries required.

.PARAMETER MaxTimeSeconds
The maximum time to wait in seconds.

.PARAMETER StateConfig
The state configuration.

.OUTPUTS
Returns $true if the command indicates the state is ready, $false otherwise.
#>
function Test-ContinueAfter {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$true)]
        [string]$StateName,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxRetries = 10,
        
        [Parameter(Mandatory=$false)]
        [int]$RetryInterval = 3,
        
        [Parameter(Mandatory=$false)]
        [int]$SuccessfulRetries = 1,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxTimeSeconds = 30,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$StateConfig,
        
        [Parameter(Mandatory=$false)]
        [switch]$Quiet
    )
    
    $attempt = 0
    $successCount = 0
    $startTime = Get-Date
    
    # Use configuration values if provided
    if ($StateConfig -and $StateConfig.readiness) {
        if ($StateConfig.readiness.maxRetries) { $MaxRetries = $StateConfig.readiness.maxRetries }
        if ($StateConfig.readiness.retryInterval) { $RetryInterval = $StateConfig.readiness.retryInterval }
        if ($StateConfig.readiness.successfulRetries) { $SuccessfulRetries = $StateConfig.readiness.successfulRetries }
        if ($StateConfig.readiness.maxTimeSeconds) { $MaxTimeSeconds = $StateConfig.readiness.maxTimeSeconds }
    }
    
    # Create a "polling" action for the command check
    $pollingDetails = "Polling command: $Command (max $MaxRetries tries, ${RetryInterval}s interval, need $SuccessfulRetries successes, timeout ${MaxTimeSeconds}s)"
    $actionId = Start-StateAction -StateName $StateName -ActionType "Command" -ActionCommand "Command polling" -Description $pollingDetails
    
    # Check if this is an endpoint check
    $isEndpointCheck = $null -ne $StateConfig.readiness.endpoint
    $endpointUri = $StateConfig.readiness.endpoint
    
    do {
        $attempt++
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        
        $success = $false
        
        if ($isEndpointCheck) {
            # Handle endpoint check
            $success = Test-WebEndpoint -Uri $endpointUri -StateName $StateName
        } else {
            # Handle normal command
            try {
                $output = Invoke-Expression $Command 2>&1 
                $success = $LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null
                
                if ($success) {
                    $outputString = $output | Out-String
                    if (Test-OutputForErrors -OutputString $outputString) {
                        $success = $false
                    }
                }
            }
            catch {
                $success = $false
            }
        }
        
        if ($success) {
            $successCount++
            
            if ($successCount -ge $SuccessfulRetries) {
                Complete-StateAction -StateName $StateName -ActionId $actionId -Success $true
                return $true
            }
        } else {
            $successCount = 0  # Reset on failure
        }
        
        # Check if we have exceeded time limit
        if ($elapsed -ge $MaxTimeSeconds) {
            Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Timed out after ${elapsed}s"
            return $false
        }
        
        # Check if we have exceeded retry limit
        if ($attempt -ge $MaxRetries) {
            Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Max retries ($MaxRetries) exceeded"
            return $false
        }
        
        # Wait before next attempt
        if ($attempt -lt $MaxRetries -and $elapsed -lt $MaxTimeSeconds) {
            Start-Sleep $RetryInterval
        }
        
    } while ($true)
}

<#
.SYNOPSIS
Tests if a state is already ready using a command.

.DESCRIPTION
Executes a command to check if a state is already ready.

.PARAMETER CheckCommand
The command to execute.

.PARAMETER StateName
The name of the state for logging.

.PARAMETER StateConfig
The state configuration.

.OUTPUTS
Returns $true if the state is already ready, $false otherwise.
#>
function Test-PreCheck {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CheckCommand,
        
        [Parameter(Mandatory=$true)]
        [string]$StateName,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$StateConfig
    )
    
    try {
        # Use try-catch instead of job for better exit code handling
        $output = $null
        $exitCode = $null
        
        try {
            # Execute command directly in the current process for better exit code handling
            $output = Invoke-Expression $CheckCommand 2>&1
            $exitCode = if ($LASTEXITCODE -ne $null) { $LASTEXITCODE } else { 0 }
        }
        catch {
            $output = $_.Exception.Message
            $exitCode = 1
        }
        
        $success = $exitCode -eq 0
        $outputString = $output | Out-String
        
        if ($success -and -not (Test-OutputForErrors -OutputString $outputString)) {
            return $true
        }
    }
    catch {
        # Exception will be reported by the main script
    }
    
    return $false
}

# Export the functions
Export-ModuleMember -Function Test-WebEndpoint, Test-EndpointReadiness, Test-ContinueAfter, Test-PreCheck

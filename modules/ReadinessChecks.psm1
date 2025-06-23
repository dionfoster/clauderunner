# ReadinessChecks.psm1 - Claude Task Runner readiness check functions

# Import Logging module for direct access to logging functions
# No wrapper functions to avoid infinite recursion

<#
.SYNOPSIS
Tests if a web endpoint is accessible.

.DESCRIPTION
Attempts to access a web endpoint and returns success or failure.
Used for both checkEndpoint and waitEndpoint readiness checks.

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
The URI of the endpoint to check (typically from checkEndpoint or waitEndpoint).

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
Optional state configuration to extract readiness parameters from.

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
        [hashtable]$StateConfig,
        
        [Parameter(Mandatory=$false)]
        [switch]$Quiet
    )
    
    $attempt = 0
    $successCount = 0
    $startTime = Get-Date    $pollingDetails = "Polling endpoint: $Uri (max $MaxRetries tries, ${RetryInterval}s interval, need $SuccessfulRetries successes, timeout ${MaxTimeSeconds}s)"
    $actionId = Logging\Start-StateAction -StateName $StateName -ActionType "Command" -ActionCommand "Endpoint polling" -Description $pollingDetails
    
    # Remove the unused $finalSuccess variable
    
    do {
        $attempt++
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        
        $success = Test-WebEndpoint -Uri $Uri -StateName $StateName
        
        if ($success) {
            $successCount++
              if ($successCount -ge $SuccessfulRetries) {
                Logging\Complete-StateAction -StateName $StateName -ActionId $actionId -Success $true
                return $true
            }
        } else {
            $successCount = 0  # Reset on failure
        }
          # Check if we have exceeded time limit
        if ($elapsed -ge $MaxTimeSeconds) {
            Logging\Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Timed out after ${elapsed}s"
            return $false
        }
          # Check if we have exceeded retry limit
        if ($attempt -ge $MaxRetries) {
            Logging\Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Max retries ($MaxRetries) exceeded"
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
Can also perform endpoint checks using checkEndpoint or waitEndpoint from StateConfig.

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
The state configuration with readiness properties.

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
    }    # Create a "polling" action for the command check
    $pollingDetails = "Polling command: $Command (max $MaxRetries tries, ${RetryInterval}s interval, need $SuccessfulRetries successes, timeout ${MaxTimeSeconds}s)"
    $actionId = Logging\Start-StateAction -StateName $StateName -ActionType "Command" -ActionCommand "Command polling" -Description $pollingDetails
    
    # Check if this is an endpoint check - use the helper function
    $endpointUri = Get-EndpointUri -StateConfig $StateConfig -ForWaiting
    $isEndpointCheck = $null -ne $endpointUri
    
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
                Logging\Complete-StateAction -StateName $StateName -ActionId $actionId -Success $true
                return $true
            }
        } else {
            $successCount = 0  # Reset on failure
        }
          # Check if we have exceeded time limit
        if ($elapsed -ge $MaxTimeSeconds) {
            Logging\Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Timed out after ${elapsed}s"
            return $false
        }
        
        # Check if we have exceeded retry limit
        if ($attempt -ge $MaxRetries) {
            Logging\Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Max retries ($MaxRetries) exceeded"
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
Can also check endpoint readiness using the checkEndpoint property from StateConfig.

.PARAMETER CheckCommand
The command to execute.

.PARAMETER StateName
The name of the state for logging.

.PARAMETER StateConfig
The state configuration with readiness properties.

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
      # First check if this is an endpoint pre-check
    if ($StateConfig -and $StateConfig.readiness) {
        # Use the helper function to get the appropriate endpoint for checking
        $checkEndpoint = Get-EndpointUri -StateConfig $StateConfig
        
        # If we have an endpoint to check, test it directly
        if ($checkEndpoint) {
            return Test-WebEndpoint -Uri $checkEndpoint -StateName $StateName
        }
    }
    
    # If not an endpoint check, proceed with command check
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

<#
.SYNOPSIS
Gets the appropriate endpoint URI from a state configuration.

.DESCRIPTION
Extracts the endpoint URI from state configuration based on context.
For waiting operations, it prioritizes waitEndpoint over checkEndpoint.
For checking operations, it uses checkEndpoint.

.PARAMETER StateConfig
The state configuration hashtable containing readiness settings.

.PARAMETER ForWaiting
If specified, prioritizes the waitEndpoint property for polling operations.

.OUTPUTS
Returns the endpoint URI as a string, or $null if no appropriate endpoint is found.
#>
function Get-EndpointUri {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$StateConfig,
        
        [Parameter(Mandatory=$false)]
        [switch]$ForWaiting
    )
    
    if (-not $StateConfig -or -not $StateConfig.readiness) {
        return $null
    }
    if ($ForWaiting) {
        # For waiting, prefer waitEndpoint over checkEndpoint
        if ($null -ne $StateConfig.readiness.waitEndpoint) {
            return $StateConfig.readiness.waitEndpoint
        } elseif ($null -ne $StateConfig.readiness.checkEndpoint) {
            return $StateConfig.readiness.checkEndpoint
        }
    } else {
        # For checking, use checkEndpoint
        if ($null -ne $StateConfig.readiness.checkEndpoint) {
            return $StateConfig.readiness.checkEndpoint
        }
    }
    
    return $null
}

# Export the functions
Export-ModuleMember -Function Test-WebEndpoint, Test-EndpointReadiness, Test-ContinueAfter, Test-PreCheck, Get-EndpointUri


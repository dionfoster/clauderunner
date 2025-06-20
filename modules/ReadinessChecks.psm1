# ReadinessChecks.psm1 - Claude Task Runner readiness check functions

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
    
    Write-StateLog $StateName "Checking endpoint: $Uri" "INFO"
    
    try {
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -ErrorAction Stop
        Write-StateLog $StateName "✓ Endpoint check passed: $Uri (Status: $($response.StatusCode))" "SUCCESS"
        return $true
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Error" }
        $errorMsg = $_.Exception.Message
        
        if ($global:Verbose) {
            Write-StateLog $StateName "✗ Endpoint check failed: $Uri (Status: $statusCode - $errorMsg)" "DEBUG"
        } else {
            Write-StateLog $StateName "✗ Endpoint check failed: $Uri (Status: $statusCode)" "WARN"
        }
        
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
        [int]$MaxTimeSeconds = 30
    )
    
    $attempt = 0
    $successCount = 0
    $startTime = Get-Date
    
    Write-StateLog $StateName "Waiting for endpoint to be ready: $Uri" "INFO"
    Write-StateLog $StateName "Will retry up to $MaxRetries times (every ${RetryInterval}s), need $SuccessfulRetries successful checks, max ${MaxTimeSeconds}s total" "INFO"
    
    do {
        $attempt++
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        
        Write-StateLog $StateName "Attempt $attempt/$MaxRetries - checking endpoint... (elapsed: ${elapsed}s)" "INFO"
        
        $success = Test-WebEndpoint -Uri $Uri -StateName $StateName
        
        if ($success) {
            $successCount++
            Write-StateLog $StateName "✓ Endpoint check passed ($successCount/$SuccessfulRetries successful checks)" "SUCCESS"
            
            if ($successCount -ge $SuccessfulRetries) {
                Write-StateLog $StateName "✓ Endpoint $Uri is ready! ($successCount successful checks in ${elapsed}s)" "SUCCESS"
                return $true
            }
        } else {
            $successCount = 0  # Reset on failure
            Write-StateLog $StateName "✗ Endpoint check failed" "WARN"
        }
        
        # Check if we have exceeded time limit
        if ($elapsed -ge $MaxTimeSeconds) {
            Write-StateLog $StateName "✗ Endpoint $Uri failed to be ready within $MaxTimeSeconds seconds" "ERROR"
            return $false
        }
        
        # Check if we have exceeded retry limit
        if ($attempt -ge $MaxRetries) {
            Write-StateLog $StateName "✗ Endpoint $Uri failed to be ready after $MaxRetries attempts" "ERROR"
            return $false
        }
        
        # Wait before next attempt
        if ($attempt -lt $MaxRetries -and $elapsed -lt $MaxTimeSeconds) {
            Write-StateLog $StateName "Waiting ${RetryInterval}s before next attempt..." "INFO"
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
        [hashtable]$StateConfig
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
    
    Write-StateLog $StateName "Waiting for $StateName to be ready..." "INFO"
    Write-StateLog $StateName "Will retry up to $MaxRetries times (every ${RetryInterval}s), need $SuccessfulRetries successful checks, max ${MaxTimeSeconds}s total" "INFO"
    
    # Check if this is an endpoint check
    $isEndpointCheck = $null -ne $StateConfig.readiness.endpoint
    $endpointUri = $StateConfig.readiness.endpoint
    
    do {
        $attempt++
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        
        Write-StateLog $StateName "Attempt $attempt/$MaxRetries - checking $StateName status... (elapsed: ${elapsed}s)" "INFO"
        
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
                        Write-StateLog $StateName "⚠ Check detected errors in output" "WARN"
                        if ($global:Verbose) {
                            Write-StateLog $StateName "Error output: $($outputString.Trim())" "DEBUG"
                        }
                    }
                } else {
                    if ($global:Verbose -and $output) {
                        $outputString = $output | Out-String
                        Write-StateLog $StateName "Error details: $($outputString.Trim())" "DEBUG"
                    }
                }
            }
            catch {
                $success = $false
                Write-StateLog $StateName "✗ Check exception: $($_.Exception.Message)" "WARN"
            }
        }
        
        if ($success) {
            $successCount++
            Write-StateLog $StateName "✓ Check passed ($successCount/$SuccessfulRetries successful checks)" "SUCCESS"
            
            if ($successCount -ge $SuccessfulRetries) {
                Write-StateLog $StateName "✓ $StateName is ready! ($successCount successful checks in ${elapsed}s)" "SUCCESS"
                return $true
            }
        } else {
            $successCount = 0  # Reset on failure
            Write-StateLog $StateName "✗ Check failed" "WARN"
        }
        
        # Check if we have exceeded time limit
        if ($elapsed -ge $MaxTimeSeconds) {
            Write-StateLog $StateName "✗ $StateName failed to be ready within $MaxTimeSeconds seconds" "ERROR"
            return $false
        }
        
        # Check if we have exceeded retry limit
        if ($attempt -ge $MaxRetries) {
            Write-StateLog $StateName "✗ $StateName failed to be ready after $MaxRetries attempts" "ERROR"
            return $false
        }
        
        # Wait before next attempt
        if ($attempt -lt $MaxRetries -and $elapsed -lt $MaxTimeSeconds) {
            Write-StateLog $StateName "Waiting ${RetryInterval}s before next attempt..." "INFO"
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
    
    Write-StateLog $StateName "Checking if $StateName is already ready using command..." "INFO"
    
    # Default command execution
    try {
        if ($global:Verbose) {
            Write-StateLog $StateName "Check command: $CheckCommand" "DEBUG"
        }
        
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
            Write-StateLog $StateName "✓ State $StateName is already ready, skipping actions" "SUCCESS"
            if ($global:Verbose) {
                $lines = ($outputString -split "`n").Count
                Write-StateLog $StateName "Check returned $lines lines of output (success)" "DEBUG"
            }
            return $true
        } else {
            if ($global:Verbose) {
                if (-not $success) {
                    Write-StateLog $StateName "Check failed (Exit Code: $exitCode)" "DEBUG"
                } else {
                    Write-StateLog $StateName "Check completed but output contains errors" "DEBUG"
                }
            }
        }
    }
    catch {
        if ($global:Verbose) {
            Write-StateLog $StateName "Check failed with exception: $($_.Exception.Message)" "DEBUG"
        }
    }
    
    Write-StateLog $StateName "Pre-check failed or detected issues, proceeding with actions" "INFO"
    return $false
}

# Export the functions
Export-ModuleMember -Function Test-WebEndpoint, Test-EndpointReadiness, Test-ContinueAfter, Test-PreCheck

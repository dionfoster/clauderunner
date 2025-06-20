# ReadinessChecks.psm1 - Claude Task Runner readiness check functions

# Access to Logging module variables and functions
# These are made available by the main script that imports both modules
# State Machine Logging mode
$script:LoggingMode = $script:LoggingMode # From Logging module

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
    
    # Support both logging modes for backward compatibility
    if ($script:LoggingMode -eq "StateMachine") {
        # The main state check already logs this, so we don't need to log again
        # State machine logging occurs in the main script via Write-StateCheck
    } else {
        Write-StateLog $StateName "Checking endpoint: $Uri" "INFO"
    }
    
    try {
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -ErrorAction Stop
        
        # Support both logging modes for backward compatibility
        if ($script:LoggingMode -eq "StateMachine") {
            # Success will be reported by the main script via Write-StateCheckResult
        } else {
            Write-StateLog $StateName "✓ Endpoint check passed: $Uri (Status: $($response.StatusCode))" "SUCCESS"
        }
        
        return $true
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Error" }
        $errorMsg = $_.Exception.Message
        
        # Support both logging modes for backward compatibility
        if ($script:LoggingMode -eq "StateMachine") {
            # Failure will be reported by the main script via Write-StateCheckResult
        } else {
            if ($global:Verbose) {
                Write-StateLog $StateName "✗ Endpoint check failed: $Uri (Status: $statusCode - $errorMsg)" "DEBUG"
            } else {
                Write-StateLog $StateName "✗ Endpoint check failed: $Uri (Status: $statusCode)" "WARN"
            }
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
        [int]$MaxTimeSeconds = 30,
        
        [Parameter(Mandatory=$false)]
        [switch]$Quiet
    )
    
    $attempt = 0
    $successCount = 0
    $startTime = Get-Date
    
    # Support both logging modes for backward compatibility
    if ($script:LoggingMode -eq "StateMachine") {
        # Create a "polling" action for the endpoint check
        $pollingDetails = "Polling endpoint: $Uri (max $MaxRetries tries, ${RetryInterval}s interval, need $SuccessfulRetries successes, timeout ${MaxTimeSeconds}s)"
        $actionId = Start-StateAction -StateName $StateName -ActionType "Command" -ActionCommand "Endpoint polling" -Description $pollingDetails
    } else {
        Write-StateLog $StateName "Waiting for endpoint to be ready: $Uri" "INFO"
        Write-StateLog $StateName "Will retry up to $MaxRetries times (every ${RetryInterval}s), need $SuccessfulRetries successful checks, max ${MaxTimeSeconds}s total" "INFO"
    }
    
    $finalSuccess = $false
    
    do {
        $attempt++
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        
        # Support both logging modes for backward compatibility
        if ($script:LoggingMode -eq "StateMachine") {
            # We'll just report the final result, not each individual attempt
        } else {
            Write-StateLog $StateName "Attempt $attempt/$MaxRetries - checking endpoint... (elapsed: ${elapsed}s)" "INFO"
        }
        
        $success = Test-WebEndpoint -Uri $Uri -StateName $StateName
        
        if ($success) {
            $successCount++
            
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # We'll just report the final result
            } else {
                Write-StateLog $StateName "✓ Endpoint check passed ($successCount/$SuccessfulRetries successful checks)" "SUCCESS"
            }
            
            if ($successCount -ge $SuccessfulRetries) {
                # Support both logging modes for backward compatibility
                if ($script:LoggingMode -eq "StateMachine") {
                    # Complete the polling action successfully
                    Complete-StateAction -StateName $StateName -ActionId $actionId -Success $true
                } else {
                    Write-StateLog $StateName "✓ Endpoint $Uri is ready! ($successCount successful checks in ${elapsed}s)" "SUCCESS"
                }
                
                $finalSuccess = $true
                return $true
            }
        } else {
            $successCount = 0  # Reset on failure
            
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # We'll just report the final result
            } else {
                Write-StateLog $StateName "✗ Endpoint check failed" "WARN"
            }
        }
        
        # Check if we have exceeded time limit
        if ($elapsed -ge $MaxTimeSeconds) {
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # Complete the polling action with failure
                Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Timed out after ${elapsed}s"
            } else {
                Write-StateLog $StateName "✗ Endpoint $Uri failed to be ready within $MaxTimeSeconds seconds" "ERROR"
            }
            
            $finalSuccess = $false
            return $false
        }
        
        # Check if we have exceeded retry limit
        if ($attempt -ge $MaxRetries) {
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # Complete the polling action with failure
                Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Max retries ($MaxRetries) exceeded"
            } else {
                Write-StateLog $StateName "✗ Endpoint $Uri failed to be ready after $MaxRetries attempts" "ERROR"
            }
            
            $finalSuccess = $false
            return $false
        }
        
        # Wait before next attempt
        if ($attempt -lt $MaxRetries -and $elapsed -lt $MaxTimeSeconds) {
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # No need to log this in state machine mode
            } else {
                Write-StateLog $StateName "Waiting ${RetryInterval}s before next attempt..." "INFO"
            }
            
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
    
    # Support both logging modes for backward compatibility
    if ($script:LoggingMode -eq "StateMachine") {
        # Create a "polling" action for the command check
        $pollingDetails = "Polling command: $Command (max $MaxRetries tries, ${RetryInterval}s interval, need $SuccessfulRetries successes, timeout ${MaxTimeSeconds}s)"
        $actionId = Start-StateAction -StateName $StateName -ActionType "Command" -ActionCommand "Command polling" -Description $pollingDetails
    } else {
        Write-StateLog $StateName "Waiting for $StateName to be ready..." "INFO"
        Write-StateLog $StateName "Will retry up to $MaxRetries times (every ${RetryInterval}s), need $SuccessfulRetries successful checks, max ${MaxTimeSeconds}s total" "INFO"
    }
    
    # Check if this is an endpoint check
    $isEndpointCheck = $null -ne $StateConfig.readiness.endpoint
    $endpointUri = $StateConfig.readiness.endpoint
    
    do {
        $attempt++
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        
        # Support both logging modes for backward compatibility
        if ($script:LoggingMode -eq "StateMachine") {
            # We'll just report the final result, not each individual attempt
        } else {
            Write-StateLog $StateName "Attempt $attempt/$MaxRetries - checking $StateName status... (elapsed: ${elapsed}s)" "INFO"
        }
        
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
                        
                        # Support both logging modes for backward compatibility
                        if ($script:LoggingMode -eq "StateMachine") {
                            # We'll just report the final result
                        } else {
                            Write-StateLog $StateName "⚠ Check detected errors in output" "WARN"
                            if ($global:Verbose) {
                                Write-StateLog $StateName "Error output: $($outputString.Trim())" "DEBUG"
                            }
                        }
                    }
                } else {
                    if ($global:Verbose -and $output) {
                        $outputString = $output | Out-String
                        
                        # Support both logging modes for backward compatibility
                        if ($script:LoggingMode -eq "StateMachine") {
                            # We'll just report the final result
                        } else {
                            Write-StateLog $StateName "Error details: $($outputString.Trim())" "DEBUG"
                        }
                    }
                }
            }
            catch {
                $success = $false
                
                # Support both logging modes for backward compatibility
                if ($script:LoggingMode -eq "StateMachine") {
                    # We'll just report the final result
                } else {
                    Write-StateLog $StateName "✗ Check exception: $($_.Exception.Message)" "WARN"
                }
            }
        }
        
        if ($success) {
            $successCount++
            
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # We'll just report the final result
            } else {
                Write-StateLog $StateName "✓ Check passed ($successCount/$SuccessfulRetries successful checks)" "SUCCESS"
            }
            
            if ($successCount -ge $SuccessfulRetries) {
                # Support both logging modes for backward compatibility
                if ($script:LoggingMode -eq "StateMachine") {
                    # Complete the polling action successfully
                    Complete-StateAction -StateName $StateName -ActionId $actionId -Success $true
                } else {
                    Write-StateLog $StateName "✓ $StateName is ready! ($successCount successful checks in ${elapsed}s)" "SUCCESS"
                }
                
                return $true
            }
        } else {
            $successCount = 0  # Reset on failure
            
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # We'll just report the final result
            } else {
                Write-StateLog $StateName "✗ Check failed" "WARN"
            }
        }
        
        # Check if we have exceeded time limit
        if ($elapsed -ge $MaxTimeSeconds) {
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # Complete the polling action with failure
                Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Timed out after ${elapsed}s"
            } else {
                Write-StateLog $StateName "✗ $StateName failed to be ready within $MaxTimeSeconds seconds" "ERROR"
            }
            
            return $false
        }
        
        # Check if we have exceeded retry limit
        if ($attempt -ge $MaxRetries) {
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # Complete the polling action with failure
                Complete-StateAction -StateName $StateName -ActionId $actionId -Success $false -ErrorMessage "Max retries ($MaxRetries) exceeded"
            } else {
                Write-StateLog $StateName "✗ $StateName failed to be ready after $MaxRetries attempts" "ERROR"
            }
            
            return $false
        }
        
        # Wait before next attempt
        if ($attempt -lt $MaxRetries -and $elapsed -lt $MaxTimeSeconds) {
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # No need to log this in state machine mode
            } else {
                Write-StateLog $StateName "Waiting ${RetryInterval}s before next attempt..." "INFO"
            }
            
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
    
    # Support both logging modes for backward compatibility
    if ($script:LoggingMode -eq "StateMachine") {
        # The main state check already logs this, so we don't need to log again
        # State machine logging occurs in the main script via Write-StateCheck
    } else {
        Write-StateLog $StateName "Checking if $StateName is already ready using command..." "INFO"
    }
    
    # Default command execution
    try {
        if ($global:Verbose) {
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # No need for verbose debug logs in state machine mode
            } else {
                Write-StateLog $StateName "Check command: $CheckCommand" "DEBUG"
            }
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
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # Success will be reported by the main script via Write-StateCheckResult
            } else {
                Write-StateLog $StateName "✓ State $StateName is already ready, skipping actions" "SUCCESS"
                if ($global:Verbose) {
                    $lines = ($outputString -split "`n").Count
                    Write-StateLog $StateName "Check returned $lines lines of output (success)" "DEBUG"
                }
            }
            
            return $true
        } else {
            if ($global:Verbose) {
                # Support both logging modes for backward compatibility
                if ($script:LoggingMode -eq "StateMachine") {
                    # Detailed failure will be reported by the main script
                } else {
                    if (-not $success) {
                        Write-StateLog $StateName "Check failed (Exit Code: $exitCode)" "DEBUG"
                    } else {
                        Write-StateLog $StateName "Check completed but output contains errors" "DEBUG"
                    }
                }
            }
        }
    }
    catch {
        if ($global:Verbose) {
            # Support both logging modes for backward compatibility
            if ($script:LoggingMode -eq "StateMachine") {
                # Exception will be reported by the main script
            } else {
                Write-StateLog $StateName "Check failed with exception: $($_.Exception.Message)" "DEBUG"
            }
        }
    }
    
    # Support both logging modes for backward compatibility
    if ($script:LoggingMode -eq "StateMachine") {
        # The failure will be reported by the main script via Write-StateCheckResult
    } else {
        Write-StateLog $StateName "Pre-check failed or detected issues, proceeding with actions" "INFO"
    }
    
    return $false
}

# Export the functions
Export-ModuleMember -Function Test-WebEndpoint, Test-EndpointReadiness, Test-ContinueAfter, Test-PreCheck

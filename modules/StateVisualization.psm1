# StateVisualization.psm1 - Claude Task Runner state visualization functions

# Import dependencies
Import-Module "$PSScriptRoot\StateManagement.psm1" -Prefix "SM"
Import-Module "$PSScriptRoot\Logging.psm1"
Import-Module "$PSScriptRoot\OutputFormatters.psm1"

# Module variables for output formatting
$script:CurrentOutputFormat = "Default"
$script:RealtimeFormatters = $null
$script:TargetState = $null

<#
.SYNOPSIS
Sets the output format for all state visualization functions.

.DESCRIPTION
Configures the output format to be used for real-time state visualization.
This affects all subsequent calls to state visualization functions.

.PARAMETER OutputFormat
The output format to use: Default, Simple, Medium, or Elaborate.
#>
function Set-OutputFormat {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Default", "Simple", "Medium", "Elaborate")]
        [string]$OutputFormat
    )
    
    $script:CurrentOutputFormat = $OutputFormat
    $script:RealtimeFormatters = Get-RealtimeFormatters -FormatName $OutputFormat
}

<#
.SYNOPSIS
Sets the target state name for summary output.

.PARAMETER TargetState
The name of the target state being executed.
#>
function Set-TargetState {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetState
    )
    
    $script:TargetState = $TargetState
}

<#
.SYNOPSIS
Begins state transitions visualization.

.DESCRIPTION
Initializes the state machine visualization and writes the header.
#>
function Start-StateTransitions {
    # Initialize default formatters if not set
    if ($null -eq $script:RealtimeFormatters) {
        Set-OutputFormat -OutputFormat $script:CurrentOutputFormat
    }
    
    # Start tracking in state management
    Start-SMStateTransitions
    
    # Use the appropriate formatter for the header
    $header = & $script:RealtimeFormatters.StateTransitionsHeader
    if ($null -ne $header -and $header -ne "" -and $header.Count -gt 0) {
        if ($header -is [array]) {
            foreach ($line in $header) {
                if ($null -ne $line -and $line -ne "") {
                    Write-Log -Level "SYSTEM" $line
                }
            }
        } else {
            Write-Log -Level "SYSTEM" $header
        }
    }
}

<#
.SYNOPSIS
Begins a state's processing visualization.

.DESCRIPTION
Logs the start of a state's processing.

.PARAMETER StateName
The name of the state being processed.

.PARAMETER Dependencies
Array of dependencies for this state.
#>
function Start-StateProcessing {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StateName,
        [string[]]$Dependencies = @()
    )
    
    # Automatically start state transitions if not already started
    $summary = Get-SMStateSummary
    if ($null -eq $summary.TotalStartTime) {
        Start-StateTransitions
    }
    
    # Start tracking in state management
    Start-SMStateProcessing -StateName $StateName -Dependencies $Dependencies
    
    $stateIcon = Get-SMStateIcon -StateName $StateName
    
    # Use the appropriate formatter for state start
    $output = & $script:RealtimeFormatters.StateStart -StateName $StateName -StateIcon $stateIcon -Dependencies $Dependencies
    if ($output) {
        if ($output -is [array]) {
            foreach ($line in $output) {
                if ($line) {
                    Write-Log -Level "SYSTEM" $line
                }
            }
        } else {
            Write-Log -Level "SYSTEM" $output
        }
    }
}

<#
.SYNOPSIS
Visualizes a state check.

.DESCRIPTION
Logs that a readiness check is being performed.

.PARAMETER CheckType
The type of check (Command or Endpoint).

.PARAMETER CheckDetails
Additional details about the check.
#>
function Write-StateCheck {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CheckType,
        [Parameter(Mandatory=$true)]
        [string]$CheckDetails
    )
    
    # Use the appropriate formatter for state check
    $output = & $script:RealtimeFormatters.StateCheck -CheckType $CheckType -CheckDetails $CheckDetails
    if ($output) {
        if ($output -is [array]) {
            foreach ($line in $output) {
                if ($line) {
                    Write-Log -Level "SYSTEM" $line
                }
            }
        } else {
            Write-Log -Level "SYSTEM" $output
        }
    }
}

<#
.SYNOPSIS
Visualizes a state check result.

.DESCRIPTION
Logs whether a state is already ready based on a readiness check.

.PARAMETER IsReady
Whether the state is already ready.

.PARAMETER CheckType
The type of check that was performed.

.PARAMETER AdditionalInfo
Additional information about the check result.
#>
function Write-StateCheckResult {
    param(
        [Parameter(Mandatory=$true)]
        [bool]$IsReady,
        [Parameter(Mandatory=$true)]
        [string]$CheckType,
        [string]$AdditionalInfo = ""
    )
    
    # Update state management based on check result
    if ($IsReady) {
        # Mark the current state as completed since it's already ready
        $result = "Already ready via $CheckType check"
        Set-SMStateStatus -Status "Completed" -Result $result
    } else {
        # Keep state in processing since we'll need to run actions
        Set-SMStateStatus -Status "Processing"
    }
    
    # Use the appropriate formatter for state check result
    $output = & $script:RealtimeFormatters.StateCheckResult -IsReady $IsReady -CheckType $CheckType -AdditionalInfo $AdditionalInfo
    if ($output) {
        if ($output -is [array]) {
            foreach ($line in $output) {
                if ($line) {
                    Write-Log -Level "SYSTEM" $line
                }
            }
        } else {
            Write-Log -Level "SYSTEM" $output
        }
    }
}

<#
.SYNOPSIS
Begins action execution visualization.

.DESCRIPTION
Logs that actions are being executed.
#>
function Start-StateActions {
    # Use the appropriate formatter for state actions header
    $output = & $script:RealtimeFormatters.StateActionsHeader
    if ($output -and $output -ne "") {
        if ($output -is [array]) {
            foreach ($line in $output) {
                Write-Log -Level "SYSTEM" $line
            }
        } else {
            Write-Log -Level "SYSTEM" $output
        }
    }
}

<#
.SYNOPSIS
Visualizes the start of an action.

.DESCRIPTION
Logs that an action is starting execution.

.PARAMETER ActionType
The type of action being executed.

.PARAMETER ActionCommand
The command or description of the action.

.PARAMETER Description
Optional description of the action.
#>
function Start-StateAction {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StateName,
        [Parameter(Mandatory=$true)]
        [string]$ActionType,
        [Parameter(Mandatory=$true)]
        [string]$ActionCommand,
        [string]$Description = ""
    )
    
    $actionId = Register-SMStateAction -StateName $StateName -ActionType $ActionType -ActionCommand $ActionCommand -Description $Description
    
    # Use the appropriate formatter for state action start
    $output = & $script:RealtimeFormatters.StateActionStart -ActionType $ActionType -Description $Description -ActionCommand $ActionCommand
    if ($output) {
        if ($output -is [array]) {
            foreach ($line in $output) {
                if ($line) {
                    Write-Log -Level "SYSTEM" $line
                }
            }
        } else {
            Write-Log -Level "SYSTEM" $output
        }
    }
    
    return $actionId
}

<#
.SYNOPSIS
Visualizes the completion of an action.

.DESCRIPTION
Logs that an action has completed execution.

.PARAMETER ActionId
The ID of the action that completed.

.PARAMETER Success
Whether the action completed successfully.

.PARAMETER ErrorMessage
Optional error message if the action failed.
#>
function Complete-StateAction {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StateName,
        [Parameter(Mandatory=$true)]
        [string]$ActionId,
        [Parameter(Mandatory=$true)]
        [bool]$Success,
        [string]$ErrorMessage = ""
    )
    
    # Complete action in state management
    Complete-SMStateAction -StateName $StateName -ActionId $ActionId -Success $Success -ErrorMessage $ErrorMessage
    
    # Get the action to retrieve duration
    $summary = Get-SMStateSummary
    $action = $summary.States[$StateName].Actions | Where-Object { $_.Id -eq $ActionId }
    
    $duration = 0
    if ($action -and $action.Duration) {
        $duration = [math]::Round($action.Duration.TotalSeconds, 1)
    }
    
    # Use the appropriate formatter for state action complete
    $output = & $script:RealtimeFormatters.StateActionComplete -Success $Success -ErrorMessage $ErrorMessage -Duration $duration
    if ($output) {
        if ($output -is [array]) {
            foreach ($line in $output) {
                if ($line) {
                    Write-Log -Level "SYSTEM" $line
                }
            }
        } else {
            Write-Log -Level "SYSTEM" $output
        }
    }
}

<#
.SYNOPSIS
Visualizes the completion of a state.

.DESCRIPTION
Logs the final result of a state's processing.

.PARAMETER StateName
The name of the state that completed.

.PARAMETER Success
Whether the state completed successfully.

.PARAMETER ErrorMessage
Optional error message if the state failed.
#>
function Complete-State {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StateName,
        [Parameter(Mandatory=$true)]
        [bool]$Success,
        [string]$ErrorMessage = ""
    )
    
    # Check if the state is already completed to avoid duplicate output
    $summary = Get-SMStateSummary
    $existingState = $summary.States[$StateName]
    
    # If state is already marked as completed (from Write-StateCheckResult), don't output again
    if ($existingState -and $existingState.Status -eq "Completed") {
        # Just update the duration in state management without outputting anything
        Complete-SMState -StateName $StateName -Success $Success -ErrorMessage $ErrorMessage
        return
    }
    
    # Complete state in state management
    Complete-SMState -StateName $StateName -Success $Success -ErrorMessage $ErrorMessage
    
    $updatedSummary = Get-SMStateSummary
    $state = $updatedSummary.States[$StateName]
    $duration = [math]::Round(($state.Duration.TotalSeconds), 1)
    
    # Use the appropriate formatter for state complete
    $output = & $script:RealtimeFormatters.StateComplete -Success $Success -ErrorMessage $ErrorMessage -Duration $duration -StateName $StateName
    if ($output) {
        if ($output -is [array]) {
            foreach ($line in $output) {
                if ($line) {
                    Write-Log -Level "SYSTEM" $line
                }
            }
        } else {
            Write-Log -Level "SYSTEM" $output
        }
    }
}

<#
.SYNOPSIS
Writes a summary of state processing.

.DESCRIPTION
Logs a summary of all states processed. For Default format, provides the traditional
summary output. For other formats, the real-time output already provides comprehensive
information, so only a minimal summary is shown.
#>
function Write-StateSummary {
    $summary = Get-SMStateSummary
    
    # For Default format, show the traditional summary
    if ($script:CurrentOutputFormat -eq "Default") {
        Write-Log -Level "SYSTEM" " "
        Write-Log -Level "SYSTEM" " "
        Write-Log -Level "SYSTEM" "EXECUTION SUMMARY"
        Write-Log -Level "SYSTEM" "----------------"
        
        # Check if TotalStartTime is null to avoid errors
        if ($null -eq $summary.TotalStartTime) {
            Write-Log -Level "SYSTEM" "No state transitions recorded."
            return
        }
        
        $totalDuration = [math]::Round($summary.TotalDuration.TotalSeconds, 1)
        
        # Check if we have any states
        if ($summary.States.Count -gt 0) {
            # Sort states by their start time (execution order)
            $sortedStates = $summary.States.GetEnumerator() | Sort-Object { $summary.StateStartTimes[$_.Key] }
            
            foreach ($state in $sortedStates) {
                $status = if ($state.Value.Success) { "$(Get-StatusIcon 'Success')" } else { "$(Get-StatusIcon 'Error')" }
                
                # Handle potential null Duration
                $duration = 0
                if ($null -ne $state.Value.Duration) {
                    $duration = [math]::Round($state.Value.Duration.TotalSeconds, 1)
                }
                
                Write-Log -Level "SYSTEM" "$status $($state.Key) ($($duration)s)"
                
                if (-not $state.Value.Success -and $state.Value.ErrorMessage) {
                    Write-Log -Level "SYSTEM" "   └─ Error: $($state.Value.ErrorMessage)"
                }
            }
        } else {
            Write-Log -Level "SYSTEM" "No states processed."
        }
        
        Write-Log -Level "SYSTEM" " "
        
        # Count successful and total states
        $successCount = ($summary.States.Values | Where-Object { $_.Success -eq $true }).Count
        $totalCount = $summary.States.Count
        
        Write-Log -Level "SYSTEM" "✅ Success: $successCount/$totalCount tasks completed"
        Write-Log -Level "SYSTEM" "⏱️ Total time: $($totalDuration)s"
    } else {
        # For other formats, use the format-specific summary functions
        if ($null -ne $summary.TotalStartTime) {
            $totalDuration = [math]::Round($summary.TotalDuration.TotalSeconds, 1)
            $success = ($summary.States.Values | Where-Object { $_.Success -eq $false }).Count -eq 0
            $errorMessage = ""
            
            # Add target state information to summary for Simple format
            $summary.TargetState = $script:TargetState
            
            # Get the output formatter for the current format
            $formatter = OutputFormatters\Get-OutputFormatter -FormatName $script:CurrentOutputFormat
            if ($formatter) {
                $formattedOutput = & $formatter -Summary $summary -Success $success -ErrorMessage $errorMessage -Duration $totalDuration
                if ($formattedOutput -and $formattedOutput.Count -gt 0) {
                    foreach ($line in $formattedOutput) {
                        if ($null -ne $line -and $line.Trim() -ne "") {
                            Write-Log -Level "SYSTEM" $line
                        } elseif ($null -ne $line -and ($line -eq "" -or $line -eq " ")) {
                            Write-Log -Level "SYSTEM" " "
                        }
                    }
                } else {
                    # Fallback to basic summary
                    Write-Log -Level "SYSTEM" " "
                    Write-Log -Level "SYSTEM" "==============================================================================="
                    Write-Log -Level "SYSTEM" "Total execution time: ${totalDuration} seconds"
                }
            } else {
                # Fallback to basic summary
                Write-Log -Level "SYSTEM" " "
                Write-Log -Level "SYSTEM" "==============================================================================="
                Write-Log -Level "SYSTEM" "Total execution time: ${totalDuration} seconds"
            }
        }
    }

    # Reset state machine variables after summary
    Reset-SMStateMachineVariables
}

<#
.SYNOPSIS
Gets the current state summary for external use.

.DESCRIPTION
Provides access to the state summary data for output formatters.
This wraps the internal Get-SMStateSummary function.

.OUTPUTS
Returns the state summary hashtable.
#>
function Get-StateSummaryForFormatters {
    return Get-SMStateSummary
}

# Status indicators, keeping these here as they're visualization-specific
# Using basic Unicode characters that work reliably in PowerShell
$script:StatusIcons = @{
    "Processing"  = "🔄"
    "Completed"   = "✅"
    "Failed"      = "❌"
    "Skipped"     = "⏭"
    "Executing"   = "⏳"
    "Success"     = "✓"
    "Error"       = "✗"
    "Warning"     = "⚠"
    "Checking"    = "🔍"
    "Ready"       = "✅"
    "NotReady"    = "❌"
}

function Get-StatusIcon {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Processing", "Completed", "Failed", "Skipped", "Executing", "Success", "Error", "Warning", "Checking", "Ready", "NotReady")]
        [string]$Type
    )
    
    return $script:StatusIcons[$Type]
}

# Export module members
Export-ModuleMember -Function Start-StateTransitions, Start-StateProcessing, 
    Write-StateCheck, Write-StateCheckResult, Start-StateActions, Start-StateAction,
    Complete-StateAction, Complete-State, Write-StateSummary, Get-StatusIcon, 
    Get-StateSummaryForFormatters, Set-OutputFormat, Set-TargetState

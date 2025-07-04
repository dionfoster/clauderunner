# StateVisualization.psm1 - Claude Task Runner state visualization functions

# Import dependencies
Import-Module "$PSScriptRoot\StateManagement.psm1" -Prefix "SM"
Import-Module "$PSScriptRoot\Logging.psm1"
Import-Module "$PSScriptRoot\OutputFormatters.psm1"

# Module variables for output formatting
$script:CurrentOutputFormat = "Default"
$script:RealtimeFormatters = $null
$script:TargetState = $null
$script:ExecutionSectionsShown = $false
$script:StateProcessingCount = 0

<#
.SYNOPSIS
Sets the output format for all state visualization functions.

.DESCRIPTION
Configures the output format to be used for real-    # Determine the execution order by recursively resolving dependencies
    $script:tempExecutionOrder = @()
    $visited = @{}e state visualization.
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
    $header = & $script:RealtimeFormatters.StateTransitionsHeader -TargetState $script:TargetState
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
    
    # Show state details header before first state processing (for Medium format)
    if (-not $script:ExecutionSectionsShown -and $script:CurrentOutputFormat -eq "Medium") {
        Write-Log -Level "SYSTEM" " "
        Write-Log -Level "SYSTEM" "🔍 STATE DETAILS"
        Write-Log -Level "SYSTEM" "────────────────"
        $script:ExecutionSectionsShown = $true
    }
    
    # For Medium format, add spacing between states (except for the first state)
    if ($script:CurrentOutputFormat -eq "Medium" -and $script:StateProcessingCount -gt 0) {
        Write-Log -Level "SYSTEM" " "  # Add blank line before each state after the first
    }
    
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
    
    # Increment state processing count
    $script:StateProcessingCount++
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
        [string]$AdditionalInfo = "",
        [string]$EndpointUrl = ""
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
    
    # For elaborate format, we need to pass additional parameters
    if ($script:CurrentOutputFormat -eq "Elaborate") {
        # Calculate duration more defensively
        $duration = 0.0
        $status = if ($IsReady) { "SUCCESS" } else { "FAILED" }
        
        try {
            # Get state summary safely
            $summary = Get-SMStateSummary
            
            # Find the current processing state and calculate duration
            if ($summary.States) {
                foreach ($stateName in $summary.States.Keys) {
                    $state = $summary.States[$stateName]
                    if ($state.Status -eq "Processing") {
                        # This state is currently being processed
                        if ($summary.StateStartTimes -and $summary.StateStartTimes.ContainsKey($stateName)) {
                            $startTime = $summary.StateStartTimes[$stateName]
                            if ($startTime -and $startTime -is [DateTime]) {
                                $duration = (Get-Date - $startTime).TotalSeconds
                            }
                        }
                        break
                    }
                }
            }
        } catch {
            # If anything fails, just use 0.0 duration
            $duration = 0.0
        }
        
        # Use the appropriate formatter for state check result with additional parameters
        $output = & $script:RealtimeFormatters.StateCheckResult -IsReady $IsReady -CheckType $CheckType -AdditionalInfo $AdditionalInfo -Duration $duration -Status $status
    } elseif ($script:CurrentOutputFormat -eq "Medium") {
        # For Medium format, pass the endpoint URL for proper display
        $output = & $script:RealtimeFormatters.StateCheckResult -IsReady $IsReady -CheckType $CheckType -AdditionalInfo $AdditionalInfo -EndpointUrl $EndpointUrl
    } else {
        # Use the standard formatter for other formats
        $output = & $script:RealtimeFormatters.StateCheckResult -IsReady $IsReady -CheckType $CheckType -AdditionalInfo $AdditionalInfo
    }
    
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
    if ($output) {
        if ($output -is [array]) {
            foreach ($line in $output) {
                if ($null -ne $line -and $line.Trim() -ne "") {
                    Write-Log -Level "SYSTEM" $line
                } elseif ($null -ne $line -and ($line -eq "" -or $line -eq " ")) {
                    Write-Log -Level "SYSTEM" " "
                }
            }
        } else {
            if ($output -ne "") {
                Write-Log -Level "SYSTEM" $output
            }
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
    
    # For elaborate format, we need to pass action indexing information
    if ($script:CurrentOutputFormat -eq "Elaborate") {
        # Get action counts from state summary
        $summary = Get-SMStateSummary
        $actionIndex = 1
        $totalActions = 1
        
        if ($summary.States -and $summary.States.ContainsKey($StateName)) {
            $state = $summary.States[$StateName]
            if ($state.Actions) {
                $actionIndex = $state.Actions.Count + 1  # Next action to be registered
                $totalActions = $actionIndex  # For now, we don't know total until complete
            }
        }
        
        # Use the appropriate formatter for state action start with indexing
        $output = & $script:RealtimeFormatters.StateActionStart -ActionType $ActionType -Description $Description -ActionCommand $ActionCommand -ActionIndex $actionIndex -TotalActions $totalActions
    } else {
        # Use the standard formatter for other formats
        $output = & $script:RealtimeFormatters.StateActionStart -ActionType $ActionType -Description $Description -ActionCommand $ActionCommand
    }
    
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
        [string]$ErrorMessage = "",
        [int]$ExitCode = 0
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
    
    # For elaborate format, we need to pass exit code
    if ($script:CurrentOutputFormat -eq "Elaborate") {
        # Use the appropriate formatter for state action complete with exit code
        $output = & $script:RealtimeFormatters.StateActionComplete -Success $Success -ErrorMessage $ErrorMessage -Duration $duration -ExitCode $ExitCode
    } else {
        # Use the standard formatter for other formats
        $output = & $script:RealtimeFormatters.StateActionComplete -Success $Success -ErrorMessage $ErrorMessage -Duration $duration
    }
    
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
        [string]$ErrorMessage = "",
        [bool]$IsExecutionState = $false
    )
    
    # Check if the state is already completed to avoid duplicate output
    $summary = Get-SMStateSummary
    $existingState = $summary.States[$StateName]
    
    # For Medium format, we always want to show the timing information even if state was already ready
    if ($existingState -and $existingState.Status -eq "Completed" -and $script:CurrentOutputFormat -ne "Medium") {
        # For non-Medium formats, don't output again if already completed from Write-StateCheckResult
        Complete-SMState -StateName $StateName -Success $Success -ErrorMessage $ErrorMessage
        return
    }
    
    # Complete state in state management
    Complete-SMState -StateName $StateName -Success $Success -ErrorMessage $ErrorMessage
    
    $updatedSummary = Get-SMStateSummary
    $state = $updatedSummary.States[$StateName]
    $duration = [math]::Round(($state.Duration.TotalSeconds), 1)
    
    # For elaborate format, we need to pass execution state flag
    if ($script:CurrentOutputFormat -eq "Elaborate") {
        # Use the appropriate formatter for state complete with execution state flag
        $output = & $script:RealtimeFormatters.StateComplete -Success $Success -ErrorMessage $ErrorMessage -Duration $duration -StateName $StateName -IsExecutionState $IsExecutionState
    } else {
        # Use the standard formatter for other formats
        $output = & $script:RealtimeFormatters.StateComplete -Success $Success -ErrorMessage $ErrorMessage -Duration $duration -StateName $StateName
    }
    
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
        $successCount = @($summary.States.Values | Where-Object { $_.Success -eq $true }).Count
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

<#
.SYNOPSIS
Shows the execution flow for Medium format after configuration parsing.

.DESCRIPTION
Determines and displays the execution order of states based on dependencies.
This should be called after configuration is loaded but before state processing begins.

.PARAMETER TargetStateName
The name of the target state.

.PARAMETER Config  
The configuration object containing state definitions.
#>
function Show-ExecutionFlow {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetStateName,
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )
    
    # Only show execution flow for Medium format
    if ($script:CurrentOutputFormat -ne "Medium") {
        return
    }
    
    # Determine the execution order by recursively resolving dependencies
    $executionOrder = @()
    $visited = @{
    }
    
    function Get-StateExecutionOrder {
        param([string]$StateName)
        
        if ($visited.ContainsKey($StateName)) {
            return
        }
        
        $visited[$StateName] = $true
        $stateConfig = $Config.states[$StateName]
        
        if ($stateConfig -and $stateConfig.needs) {
            foreach ($dependency in $stateConfig.needs) {
                Get-StateExecutionOrder -StateName $dependency
            }
        }
        
        $script:tempExecutionOrder = $script:tempExecutionOrder + $StateName
    }
    
    # Determine execution order dynamically from configuration
    $executionOrder = @()
    
    function Get-ExecutionOrder {
        param([string]$StateName, [hashtable]$Visited = @{})
        
        if ($Visited[$StateName]) { 
            return @()
        }
        $Visited[$StateName] = $true
        
        $order = @()
        $stateConfig = $Config.states[$StateName]
        if ($stateConfig -and $stateConfig.needs) {
            foreach ($dep in $stateConfig.needs) {
                $depOrder = Get-ExecutionOrder -StateName $dep -Visited $Visited
                $order += $depOrder
            }
        }
        $order += $StateName
        return $order
    }
    
    $executionOrder = Get-ExecutionOrder -StateName $TargetStateName
    
    # Display the execution flow section
    Write-Log -Level "SYSTEM" " "
    Write-Log -Level "SYSTEM" "📊 EXECUTION FLOW"
    Write-Log -Level "SYSTEM" "─────────────────"
    
    # Create the flow line: [state1] ➜ [state2] ➜ [state3]
    $flowParts = @()
    foreach ($state in $executionOrder) {
        $flowParts += "[$state]"
    }
    
    if ($flowParts.Count -gt 0) {
        $flowLine = $flowParts -join " ➜ "
        Write-Log -Level "SYSTEM" $flowLine
    } else {
        Write-Log -Level "SYSTEM" "No states found"
    }
}

<#
.SYNOPSIS
Resets all visualization state variables.

.DESCRIPTION
Clears all module-level state variables to ensure clean runs.
#>
function Reset-VisualizationState {
    $script:CurrentOutputFormat = "Default"
    $script:RealtimeFormatters = $null
    $script:TargetState = $null
    $script:ExecutionSectionsShown = $false
    $script:StateProcessingCount = 0
}

# Export module members
Export-ModuleMember -Function Start-StateTransitions, Start-StateProcessing, 
    Write-StateCheck, Write-StateCheckResult, Start-StateActions, Start-StateAction,
    Complete-StateAction, Complete-State, Write-StateSummary, Get-StatusIcon, 
    Get-StateSummaryForFormatters, Set-OutputFormat, Set-TargetState, Show-ExecutionFlow, Reset-VisualizationState

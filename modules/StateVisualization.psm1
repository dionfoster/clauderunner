# StateVisualization.psm1 - Claude Task Runner state visualization functions

# Import dependencies
Import-Module "$PSScriptRoot\StateManagement.psm1" -Prefix "SM"
Import-Module "$PSScriptRoot\Logging.psm1"

<#
.SYNOPSIS
Begins state transitions visualization.

.DESCRIPTION
Initializes the state machine visualization and writes the header.
#>
function Start-StateTransitions {
    # Start tracking in state management
    Start-SMStateTransitions
    Write-Log -Level "SYSTEM" "STATE TRANSITIONS:"
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
    
    # Format dependencies with check marks
    $formattedDeps = $Dependencies | ForEach-Object { "$_ ✓" }
    $depText = if ($Dependencies.Count -gt 0) { 
        "Dependencies: $($formattedDeps -join ', ')" 
    } else { 
        "Dependencies: none" 
    }
    
    Write-Log -Level "SYSTEM" "┌─ STATE: $(Get-StatusIcon 'Processing') $stateIcon$StateName"
    Write-Log -Level "SYSTEM" "│  ├─ $depText"
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
    
    Write-Log -Level "SYSTEM" "│  ├─ Check: $(Get-StatusIcon 'Checking') $CheckType check ($CheckDetails)"
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
        
        # Format log message based on whether additional info was provided
        if ($AdditionalInfo) {
            $logMessage = "│  └─ Status: $(Get-StatusIcon 'Ready') Ready - $CheckType ($AdditionalInfo)"
        } else {
            $logMessage = "│  └─ Result: $(Get-StatusIcon 'Ready') READY (already ready via $($CheckType.ToLower()) check)"
        }    } else {
        # Keep state in processing since we'll need to run actions
        Set-SMStateStatus -Status "Processing"
        
        # Format log message based on whether additional info was provided
        # Use Status format only for specific status information, otherwise use Result format
        if ($AdditionalInfo -and ($AdditionalInfo -like "*Status:*" -or $AdditionalInfo -notlike "*retry*")) {
            $logMessage = "│  └─ Status: $(Get-StatusIcon 'NotReady') Not Ready - $CheckType ($AdditionalInfo)"
        } else {
            $logMessage = "│  └─ Result: $(Get-StatusIcon 'NotReady') NOT READY (proceeding with actions)"
        }
    }
    
    Write-Log -Level "SYSTEM" $logMessage
}

<#
.SYNOPSIS
Begins action execution visualization.

.DESCRIPTION
Logs that actions are being executed.
#>
function Start-StateActions {
    Write-Log -Level "SYSTEM" "│  ├─ Actions:"
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
    
    $message = "│  │  ├─ $(Get-StatusIcon 'Executing') $ActionType"
    if ($Description) {
        $message += ": $Description"
    }
    $message += " ($ActionCommand)"
    
    Write-Log -Level "SYSTEM" $message
    
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
    
    $statusIcon = if ($Success) { "$(Get-StatusIcon 'Success')" } else { "$(Get-StatusIcon 'Error')" }
    $statusText = if ($Success) { "SUCCESS" } else { "FAILED" }
    
    $message = "│  │  └─ Status: $statusIcon $statusText"
    
    # Add duration if available
    if ($action -and $action.Duration) {
        $duration = [math]::Round($action.Duration.TotalSeconds, 1)
        $message += " ($($duration)s)"
    }
    
    if (-not $Success -and $ErrorMessage) {
        $message += " Error: $ErrorMessage"
    }
    
    Write-Log -Level "SYSTEM" $message
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
    )    # Complete state in state management
    Complete-SMState -StateName $StateName -Success $Success -ErrorMessage $ErrorMessage
    
    $summary = Get-SMStateSummary
    $state = $summary.States[$StateName]
    $duration = [math]::Round(($state.Duration.TotalSeconds), 1)
    $status = if ($Success) { "$(Get-StatusIcon 'Completed') COMPLETED" } else { "$(Get-StatusIcon 'Failed') FAILED" }
    
    Write-Log -Level "SYSTEM" "│  └─ Result: $status ($($duration)s)"
    
    if (-not $Success -and $ErrorMessage) {
        Write-Log -Level "SYSTEM" "│     └─ Error: $ErrorMessage"
    }
}

<#
.SYNOPSIS
Writes a summary of state processing.

.DESCRIPTION
Logs a summary of all states processed.
#>
function Write-StateSummary {
    $summary = Get-SMStateSummary
    
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
    Write-Log -Level "SYSTEM" " "
    Write-Log -Level "SYSTEM" "Total time: $totalDuration seconds"    # Reset state machine variables after summary
    Reset-SMStateMachineVariables
}

# Status indicators, keeping these here as they're visualization-specific
$script:StatusIcons = @{
    "Processing"  = "🔄"
    "Completed"   = "✅"
    "Failed"      = "❌"
    "Skipped"     = "⏭️"
    "Executing"   = "⏳"
    "Success"     = "✓"
    "Error"       = "✗"
    "Warning"     = "⚠️"
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
    Complete-StateAction, Complete-State, Write-StateSummary, Get-StatusIcon

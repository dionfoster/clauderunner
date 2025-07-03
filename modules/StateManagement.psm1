# StateManagement.psm1 - Claude Task Runner state management functions

# Module-level variables
$script:StateTransitionStarted = $false
$script:StateStartTimes = @{}
$script:ActionStartTimes = @{}
$script:ProcessedStates = @{}
$script:TotalStartTime = $null

# Status indicators - keeping these here as they're state-specific
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

<#
.SYNOPSIS
Gets the appropriate icon for a state.

.DESCRIPTION
Returns an emoji icon representing the given state.

.PARAMETER StateName
The name of the state for which to get the icon.

.OUTPUTS
A string containing the emoji icon for the state.
#>
function Get-StateIcon {
    param(
        [string]$StateName
    )
    
    switch ($StateName.ToLower()) {
        "dockerready" { "🐳 " }
        "dockerstartup" { "⚙️ " }
        "nodeready" { "🟢 " }
        "apiready" { "🚀 " }
        default { "⚙️ " }
    }
}

<#
.SYNOPSIS
Begins tracking state transitions.

.DESCRIPTION
Initializes the state tracking system.
#>
function Start-StateTransitions {
    if (-not $script:StateTransitionStarted) {
        $script:StateTransitionStarted = $true
        $script:TotalStartTime = Get-Date
    }
}

<#
.SYNOPSIS
Records the start of processing a state.

.DESCRIPTION
Initializes tracking for a new state being processed.

.PARAMETER StateName
The name of the state being processed.

.PARAMETER Dependencies
Array of dependencies for this state.
#>
function Start-StateProcessing {
    param(
        [string]$StateName,
        [string[]]$Dependencies = @()
    )
    
    Start-StateTransitions
    $script:StateStartTimes[$StateName] = Get-Date
    $script:ProcessedStates[$StateName] = @{
        "Actions" = @()
        "Dependencies" = $Dependencies
        "Status" = "Processing"
    }
}

<#
.SYNOPSIS
Sets the status of the current state being processed.

.DESCRIPTION
Updates the status and result of a state.

.PARAMETER Status
The status to set for the state.

.PARAMETER Result
Optional result message for the state.
#>
function Set-StateStatus {
    param(
        [string]$Status,
        [string]$Result = ""
    )
    
    # Get the most recently started state
    $latestState = $script:StateStartTimes.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
    if ($latestState) {
        $script:ProcessedStates[$latestState.Key]["Status"] = $Status
        
        # Set Success field based on Status
        if ($Status -eq "Completed") {
            $script:ProcessedStates[$latestState.Key]["Success"] = $true
        } elseif ($Status -eq "Failed") {
            $script:ProcessedStates[$latestState.Key]["Success"] = $false
        }
        
        if ($Result) {
            $script:ProcessedStates[$latestState.Key]["Result"] = $Result
        }
    }
}

<#
.SYNOPSIS
Registers the start of an action within a state.

.DESCRIPTION
Records that an action has started execution.

.PARAMETER StateName
The name of the state for which the action is being executed.

.PARAMETER ActionType
The type of action being executed.
#>
function Register-StateAction {
    param(
        [string]$StateName,
        [string]$ActionType,
        [string]$ActionCommand = "",
        [string]$Description = ""
    )
    
    $actionId = [guid]::NewGuid().ToString()
    $script:ActionStartTimes[$actionId] = Get-Date
    
    $actionData = @{
        Id = $actionId
        Type = $ActionType
        StartTime = $script:ActionStartTimes[$actionId]
    }
    
    if ($ActionCommand) {
        $actionData["Command"] = $ActionCommand
    }
    
    if ($Description) {
        $actionData["Description"] = $Description
    }
    
    $script:ProcessedStates[$StateName].Actions += $actionData
    
    return $actionId
}

<#
.SYNOPSIS
Completes an action within a state.

.DESCRIPTION
Records that an action has completed execution.

.PARAMETER StateName
The name of the state for which the action was executed.

.PARAMETER ActionId
The ID of the action that completed.

.PARAMETER Success
Whether the action completed successfully.
#>
function Complete-StateAction {
    param(
        [string]$StateName,
        [string]$ActionId,
        [bool]$Success,
        [string]$ErrorMessage = ""
    )
    
    $action = $script:ProcessedStates[$StateName].Actions | Where-Object { $_.Id -eq $ActionId }
    if ($action) {
        $action.EndTime = Get-Date
        $action.Success = $Success
        $action.Duration = $action.EndTime - $action.StartTime
        $action.Status = if ($Success) { "Success" } else { "Failed" }
        
        if ($ErrorMessage) {
            $action.ErrorMessage = $ErrorMessage
        }
    }
}

<#
.SYNOPSIS
Completes processing of a state.

.DESCRIPTION
Records the completion status of a state.

.PARAMETER StateName
The name of the state that completed.

.PARAMETER Success
Whether the state completed successfully.
#>
function Complete-State {
    param(
        [string]$StateName,
        [bool]$Success,
        [string]$ErrorMessage = ""
    )
    
    if ($script:ProcessedStates.ContainsKey($StateName)) {
        $script:ProcessedStates[$StateName].EndTime = Get-Date
        $script:ProcessedStates[$StateName].Success = $Success
        $script:ProcessedStates[$StateName].Duration = $script:ProcessedStates[$StateName].EndTime - $script:StateStartTimes[$StateName]
        $script:ProcessedStates[$StateName].Status = if ($Success) { "Completed" } else { "Failed" }
        
        if ($ErrorMessage) {
            $script:ProcessedStates[$StateName].ErrorMessage = $ErrorMessage
        }
    }
}

<#
.SYNOPSIS
Gets a summary of all state processing.

.DESCRIPTION
Returns information about all processed states.

.OUTPUTS
A hashtable containing information about all processed states.
#>
function Get-StateSummary {
    $currentTime = Get-Date
    $duration = if ($script:TotalStartTime) { 
        $currentTime - $script:TotalStartTime 
    } else { 
        New-TimeSpan -Seconds 0 
    }
    
    return @{
        States = $script:ProcessedStates.Clone()
        StateStartTimes = $script:StateStartTimes.Clone()
        TotalStartTime = $script:TotalStartTime
        TotalEndTime = $currentTime
        TotalDuration = $duration
    }
}

<#
.SYNOPSIS
Resets all state machine variables.

.DESCRIPTION
Clears all state tracking variables to prepare for a new run.
#>
function Reset-StateMachineVariables {
    $script:StateTransitionStarted = $false
    $script:StateStartTimes = @{}
    $script:ActionStartTimes = @{}
    $script:ProcessedStates = @{}
    $script:TotalStartTime = $null
}

<#
.SYNOPSIS
Gets the current duration of a state in processing.

.DESCRIPTION
Returns the duration of a state that is currently being processed.

.PARAMETER StateName
The name of the state to get duration for.

.OUTPUTS
The duration in seconds as a double, or 0 if state not found.
#>
function Get-CurrentStateDuration {
    param(
        [string]$StateName
    )
    
    if ($script:StateStartTimes.ContainsKey($StateName)) {
        $currentTime = Get-Date
        $duration = $currentTime - $script:StateStartTimes[$StateName]
        return $duration.TotalSeconds
    }
    
    return 0.0
}

<#
.SYNOPSIS
Gets the name of the current state being processed.

.DESCRIPTION
Returns the name of the state that is currently being processed.

.OUTPUTS
The name of the current state, or empty string if no state is being processed.
#>
function Get-CurrentStateName {
    # Find the state that is currently processing (has start time but no end time)
    foreach ($stateName in $script:StateStartTimes.Keys) {
        if ($script:ProcessedStates.ContainsKey($stateName)) {
            $state = $script:ProcessedStates[$stateName]
            if ($state.Status -eq "Processing") {
                return $stateName
            }
        }
    }
    
    return ""
}

<#
.SYNOPSIS
Gets the current action count for a state.

.DESCRIPTION
Returns the number of actions that have been registered for a state.

.PARAMETER StateName
The name of the state to get action count for.

.OUTPUTS
The number of actions registered for the state.
#>
function Get-StateActionCount {
    param(
        [string]$StateName
    )
    
    if ($script:ProcessedStates.ContainsKey($StateName)) {
        return $script:ProcessedStates[$StateName].Actions.Count
    }
    
    return 0
}

<#
.SYNOPSIS
Gets the total planned action count for a state.

.DESCRIPTION
Returns the total number of actions planned for a state.
For now, this returns the current count since we don't pre-plan actions.

.PARAMETER StateName
The name of the state to get total action count for.

.OUTPUTS
The total number of actions for the state.
#>
function Get-StateTotalActionCount {
    param(
        [string]$StateName
    )
    
    # For now, return the current count since we don't pre-plan actions
    # This could be enhanced to return planned count if we add that feature
    return Get-StateActionCount -StateName $StateName
}

# Export module members
Export-ModuleMember -Function Get-StateIcon, Start-StateTransitions, Start-StateProcessing,
    Register-StateAction, Complete-StateAction, Complete-State, Get-StateSummary, 
    Set-StateStatus, Reset-StateMachineVariables, Get-CurrentStateDuration, Get-CurrentStateName,
    Get-StateActionCount, Get-StateTotalActionCount -Variable StateTransitionStarted,
    StateStartTimes, ActionStartTimes, ProcessedStates, TotalStartTime, StatusIcons

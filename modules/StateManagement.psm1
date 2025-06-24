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
        [string]$ActionType
    )
    
    $actionId = [guid]::NewGuid().ToString()
    $script:ActionStartTimes[$actionId] = Get-Date
    
    $script:ProcessedStates[$StateName].Actions += @{
        Id = $actionId
        Type = $ActionType
        StartTime = $script:ActionStartTimes[$actionId]
    }
    
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
        [bool]$Success
    )
    
    $action = $script:ProcessedStates[$StateName].Actions | Where-Object { $_.Id -eq $ActionId }
    if ($action) {
        $action.EndTime = Get-Date
        $action.Success = $Success
        $action.Duration = $action.EndTime - $action.StartTime
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
        [bool]$Success
    )
    
    if ($script:ProcessedStates.ContainsKey($StateName)) {
        $script:ProcessedStates[$StateName].EndTime = Get-Date
        $script:ProcessedStates[$StateName].Success = $Success
        $script:ProcessedStates[$StateName].Duration = $script:ProcessedStates[$StateName].EndTime - $script:StateStartTimes[$StateName]
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
    return @{
        States = $script:ProcessedStates.Clone()
        TotalStartTime = $script:TotalStartTime
        TotalEndTime = Get-Date
        TotalDuration = (Get-Date) - $script:TotalStartTime
    }
}

# Export module members
Export-ModuleMember -Function Get-StateIcon, Start-StateTransitions, Start-StateProcessing,
    Register-StateAction, Complete-StateAction, Complete-State, Get-StateSummary -Variable StateTransitionStarted,
    StateStartTimes, ActionStartTimes, ProcessedStates, TotalStartTime, StatusIcons

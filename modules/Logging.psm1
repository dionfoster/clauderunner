# Logging.psm1 - Claude Task Runner logging functions

# Module-level variables
$script:LogPath = "claude.log"
$script:StateTransitionStarted = $false
$script:StateStartTimes = @{}
$script:ActionStartTimes = @{}
$script:ProcessedStates = @{}
$script:TotalStartTime = $null
$script:LoggingMode = "Standard" # Can be "Standard" or "StateMachine"

# Status indicators
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

# Function to set the log path from the main script
function Set-LogPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $script:LogPath = $Path
}

# Function to set the logging mode
function Set-LoggingMode {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Standard", "StateMachine")]
        [string]$Mode
    )
    
    $script:LoggingMode = $Mode
}

<#
.SYNOPSIS
Writes a log message to both the console and the log file.

.DESCRIPTION
Writes a log message with timestamp and appropriate emoji to both the console and the log file.

.PARAMETER Message
The message to be logged.

.PARAMETER Level
The log level (INFO, SUCCESS, WARN, ERROR, DEBUG, SYSTEM). Default is INFO.
#>
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message, 
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG", "SYSTEM")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $emoji = ""
    $color = "White"
    
    switch ($Level) {
        "INFO" { $color = "Gray"; $emoji = "ℹ️ " }
        "SUCCESS" { $color = "Green"; $emoji = "✅ " }
        "WARN" { $color = "Yellow"; $emoji = "⚠️ " }
        "ERROR" { $color = "Red"; $emoji = "❌ " }
        "DEBUG" { $color = "Cyan"; $emoji = "🔍 " }
    }
    
    if ($script:LoggingMode -eq "Standard") {
        # Standard mode - include timestamp
        $fullMessage = "[$timestamp] [$Level] $emoji$Message"
        Write-Host $fullMessage -ForegroundColor $color
        
        # Log to file with timestamp
        $logMessage = "[$timestamp] [$Level] $emoji$Message"
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
    else {
        # State machine mode - handle special cases
        if ($Level -eq "SYSTEM") {
            # State machine headers are printed as-is
            Write-Host $Message -ForegroundColor $color
            
            # Log with timestamp to file
            $logMessage = "[$timestamp] [INFO] $Message"
            $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
            return
        }

        # Suppress various types of legacy messages in state machine mode
        if ($Message -match "Checking if .* is already ready using command" -or
            $Message -match "State .* is already ready, skipping actions" -or
            $Message -match "Checking endpoint:" -or
            $Message -match "Endpoint check passed:" -or
            $Message -match "Starting .*: npm run" -or
            $Message -match "Execute command:" -or
            $Message -match "completed successfully" -or
            $Message -match "command failed") {
            # Only log to file for record keeping
            $logMessage = "[$timestamp] [$Level] $emoji$Message"
            $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
            return
        }

        # For other messages in state machine mode
        if (-not $Message.StartsWith("STATE TRANSITIONS:") -and 
            -not $Message.StartsWith("SUMMARY:")) {
            # Add proper indentation for state machine visualization
            $Message = $Message -replace "^", "│  "
        }
        
        Write-Host $Message -ForegroundColor $color
        
        # Log with timestamp to file
        $logMessage = "[$timestamp] [$Level] $emoji$Message"
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
}

<#
.SYNOPSIS
Writes a state-specific log message with the appropriate state icon.

.DESCRIPTION
Writes a log message with the state icon prefixed to the message.

.PARAMETER StateName
The name of the state for which to log the message.

.PARAMETER Message
The message to be logged.

.PARAMETER Level
The log level (INFO, SUCCESS, WARN, ERROR, DEBUG). Default is INFO.
#>
function Write-StateLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StateName, 
        
        [Parameter(Mandatory=$true)]
        [string]$Message, 
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    # In standard mode, use original behavior
    if ($script:LoggingMode -eq "Standard") {
        $icon = Get-StateIcon $StateName
        Write-Log ("{0}{1}" -f $icon, $Message) $Level
    }
    # In state machine mode, delegate to state transition logger
    else {
        # This is a simple pass-through for now to maintain compatibility
        # The state machine visualization will be handled by separate functions
        $icon = Get-StateIcon $StateName
        Write-Log ("{0}{1}" -f $icon, $Message) $Level
    }
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
        [Parameter(Mandatory=$true)]
        [string]$StateName
    )
    
    switch ($StateName.ToLower()) {
        "dockerready" { return "🐳 " }
        "dockerstartup" { return "⚙️ " }
        "nodeready"   { return "🟢 " }
        "apiready"    { return "🚀 " }
        default       { return "⚙️ " }
    }
}

#
# State Machine Visualization Functions
#

<#
.SYNOPSIS
Begins the state transitions section of the log.

.DESCRIPTION
Initializes the state machine visualization and writes the header.
#>
function Start-StateTransitions {    if ($script:LoggingMode -ne "StateMachine") {
        return
    }    if (-not $script:StateTransitionStarted) {
        $script:TotalStartTime = Get-Date
        
        Write-Host "`nSTATE TRANSITIONS:" -ForegroundColor Cyan
        Write-Host "" # Add an extra line break
        $script:StateTransitionStarted = $true
        
        # Log to file
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] - STATE TRANSITIONS:"
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
}

<#
.SYNOPSIS
Marks the beginning of processing a state.

.DESCRIPTION
Logs the start of a state's processing and captures the start time.

.PARAMETER StateName
The name of the state being processed.

.PARAMETER Dependencies
Array of dependencies for this state.
#>
function Start-StateProcessing {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StateName,
        
        [Parameter(Mandatory=$false)]
        [string[]]$Dependencies = @()
    )
    
    if ($script:LoggingMode -ne "StateMachine") {
        return
    }
    
    Start-StateTransitions
    
    $stateIcon = Get-StateIcon $StateName
    $script:StateStartTimes[$StateName] = Get-Date
    $script:ProcessedStates[$StateName] = @{
        "Status" = "Processing"
        "Dependencies" = $Dependencies
        "Actions" = @()
    }    # Format dependencies with check marks
    $depText = if ($Dependencies.Count -gt 0) { 
        $formattedDeps = $Dependencies | ForEach-Object { "$_✓" }
        "Dependencies: $($formattedDeps -join ', ')" 
    } else { 
        "Dependencies: none" 
    }
    
    # Add empty line before new state for better readability
    Write-Host ""
    Write-Host "┌─ STATE: $($script:StatusIcons['Processing']) $stateIcon$StateName" -ForegroundColor Cyan
    Write-Host "│  ├─ $depText" -ForegroundColor Gray
    
    # Log to file
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] - ┌─ STATE: $($script:StatusIcons['Processing']) $stateIcon$StateName"
    $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] - │  ├─ $depText"
    $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
}

<#
.SYNOPSIS
Logs a readiness check for a state.

.DESCRIPTION
Logs that a readiness check is being performed for a state.

.PARAMETER StateName
The name of the state being checked.

.PARAMETER CheckType
The type of check (Command or Endpoint).

.PARAMETER CheckDetails
Additional details about the check.
#>
function Write-StateCheck {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StateName,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Command", "Endpoint")]
        [string]$CheckType,
        
        [Parameter(Mandatory=$true)]
        [string]$CheckDetails
    )
      if ($script:LoggingMode -ne "StateMachine") {
        return
    }
    
    Write-Host "│  ├─ Check: $($script:StatusIcons['Checking']) $CheckType check ($CheckDetails)" -ForegroundColor Gray
    
    # Log to file
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] - │  ├─ Check: $($script:StatusIcons['Checking']) $CheckType check ($CheckDetails)"
    $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
}

<#
.SYNOPSIS
Logs the result of a readiness check.

.DESCRIPTION
Logs whether a state is already ready based on a readiness check.

.PARAMETER StateName
The name of the state being checked.

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
        [string]$StateName,
        
        [Parameter(Mandatory=$true)]
        [bool]$IsReady,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Command", "Endpoint")]
        [string]$CheckType,
        
        [Parameter(Mandatory=$false)]
        [string]$AdditionalInfo = ""
    )
      if ($script:LoggingMode -ne "StateMachine") {
        return
    }
    
    $status = if ($IsReady) { $script:StatusIcons['Ready'] } else { $script:StatusIcons['NotReady'] }
    $resultText = if ($IsReady) { "READY" } else { "NOT READY" }
    $resultColor = if ($IsReady) { "Green" } else { "Yellow" }
      $resultInfo = if ($CheckType -eq "Command") {
        "already ready via command check"
    } elseif ($CheckType -eq "Endpoint" -and $AdditionalInfo -match "Status: (\d+)") {
        "endpoint status: $($Matches[1]) OK"
    } else {
        if ($IsReady) { "already ready via $($CheckType.ToLower()) check" } 
        else { "proceeding with actions" }
        
        if ($AdditionalInfo -and -not $IsReady) { " ($AdditionalInfo)" } else { "" }
    }
    
    if ($IsReady) {
        Write-Host "│  └─ Result: $status $resultText ($resultInfo)" -ForegroundColor $resultColor
        
        # Update state tracking
        $script:ProcessedStates[$StateName]["Status"] = "Completed"
        $script:ProcessedStates[$StateName]["Result"] = "Already ready via $CheckType check"
        
        # Log to file
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [SUCCESS] - │  └─ Result: $status $resultText ($resultInfo)"
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
    else {
        Write-Host "│  └─ Result: $status $resultText (proceeding with actions)" -ForegroundColor $resultColor
        
        # Log to file
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] - │  └─ Result: $status $resultText (proceeding with actions)"
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
}

<#
.SYNOPSIS
Begins action execution for a state.

.DESCRIPTION
Logs that actions are being executed for a state.

.PARAMETER StateName
The name of the state for which actions are being executed.
#>
function Start-StateActions {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StateName
    )
      if ($script:LoggingMode -ne "StateMachine") {
        return
    }
    
    Write-Host "│  ├─ Actions: $($script:StatusIcons['Executing']) EXECUTING" -ForegroundColor Yellow
    
    # Log to file
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] - │  ├─ Actions: $($script:StatusIcons['Executing']) EXECUTING"
    $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
}

<#
.SYNOPSIS
Logs the start of an action.

.DESCRIPTION
Logs that an action is starting execution.

.PARAMETER StateName
The name of the state for which the action is being executed.

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
        [ValidateSet("Command", "Application")]
        [string]$ActionType,
        
        [Parameter(Mandatory=$true)]
        [string]$ActionCommand,
        
        [Parameter(Mandatory=$false)]
        [string]$Description = ""
    )
      if ($script:LoggingMode -ne "StateMachine") {
        return
    }
    
    $actionId = [Guid]::NewGuid().ToString()
    $script:ActionStartTimes[$actionId] = Get-Date
    
    $displayText = if ($Description) { "$ActionCommand ($Description)" } else { $ActionCommand }
    
    Write-Host "│  │  ├─ $ActionType`: $displayText" -ForegroundColor Gray
    
    # Track action
    $script:ProcessedStates[$StateName]["Actions"] += @{
        "Id" = $actionId
        "Type" = $ActionType
        "Command" = $ActionCommand
        "Description" = $Description
        "Status" = "Executing"
    }
    
    # Log to file
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] - │  │  ├─ $ActionType`: $displayText"
    $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    
    return $actionId
}

<#
.SYNOPSIS
Logs the completion of an action.

.DESCRIPTION
Logs that an action has completed execution.

.PARAMETER StateName
The name of the state for which the action was executed.

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
        
        [Parameter(Mandatory=$false)]
        [string]$ErrorMessage = ""
    )
      if ($script:LoggingMode -ne "StateMachine") {
        return
    }
    
    # Calculate duration
    $startTime = $script:ActionStartTimes[$ActionId]
    $endTime = Get-Date
    $duration = [math]::Round(($endTime - $startTime).TotalSeconds, 1)
    
    $status = if ($Success) { $script:StatusIcons['Success'] } else { $script:StatusIcons['Error'] }
    $statusText = if ($Success) { "SUCCESS" } else { "FAILED" }
    $statusColor = if ($Success) { "Green" } else { "Red" }
    
    if ($Success) {
        Write-Host "│  │  │  └─ Status: $status $statusText ($duration`s)" -ForegroundColor $statusColor
        
        # Update action tracking
        $actionIndex = $script:ProcessedStates[$StateName]["Actions"].Count - 1
        $script:ProcessedStates[$StateName]["Actions"][$actionIndex]["Status"] = "Success"
        $script:ProcessedStates[$StateName]["Actions"][$actionIndex]["Duration"] = $duration
        
        # Log to file
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [SUCCESS] - │  │  │  └─ Status: $status $statusText ($duration`s)"
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
    else {
        Write-Host "│  │  │  └─ Status: $status $statusText ($duration`s)" -ForegroundColor $statusColor
        if ($ErrorMessage) {
            Write-Host "│  │  │     └─ Error: $ErrorMessage" -ForegroundColor Red
            
            # Log to file
            $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] - │  │  │     └─ Error: $ErrorMessage"
            $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
        }
        
        # Update action tracking
        $actionIndex = $script:ProcessedStates[$StateName]["Actions"].Count - 1
        $script:ProcessedStates[$StateName]["Actions"][$actionIndex]["Status"] = "Failed"
        $script:ProcessedStates[$StateName]["Actions"][$actionIndex]["Duration"] = $duration
        $script:ProcessedStates[$StateName]["Actions"][$actionIndex]["ErrorMessage"] = $ErrorMessage
        
        # Log to file
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] - │  │  │  └─ Status: $status $statusText ($duration`s)"
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
}

<#
.SYNOPSIS
Logs the completion of a state.

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
        
        [Parameter(Mandatory=$false)]
        [string]$ErrorMessage = ""
    )
      if ($script:LoggingMode -ne "StateMachine") {
        return
    }
    
    # Calculate duration
    $startTime = $script:StateStartTimes[$StateName]
    $endTime = Get-Date
    $duration = [math]::Round(($endTime - $startTime).TotalSeconds, 1)
    
    $status = if ($Success) { $script:StatusIcons['Completed'] } else { $script:StatusIcons['Failed'] }
    $resultText = if ($Success) { "COMPLETED" } else { "FAILED" }
    $resultColor = if ($Success) { "Green" } else { "Red" }
    
    if ($Success) {
        Write-Host "│  └─ Result: $status $resultText ($duration`s)" -ForegroundColor $resultColor
        Write-Host ""
        
        # Update state tracking
        $script:ProcessedStates[$StateName]["Status"] = "Completed"
        $script:ProcessedStates[$StateName]["Duration"] = $duration
        
        # Log to file
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [SUCCESS] - │  └─ Result: $status $resultText ($duration`s)"
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] - "
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
    else {
        Write-Host "│  └─ Result: $status $resultText ($duration`s)" -ForegroundColor $resultColor
        if ($ErrorMessage) {
            Write-Host "│     └─ Error: $ErrorMessage" -ForegroundColor Red
            
            # Log to file
            $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] - │     └─ Error: $ErrorMessage"
            $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
        }
        Write-Host ""
        
        # Update state tracking
        $script:ProcessedStates[$StateName]["Status"] = "Failed"
        $script:ProcessedStates[$StateName]["Duration"] = $duration
        $script:ProcessedStates[$StateName]["ErrorMessage"] = $ErrorMessage
        
        # Log to file
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] - │  └─ Result: $status $resultText ($duration`s)"
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] - "
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
}

<#
.SYNOPSIS
Writes a summary of the state machine execution.

.DESCRIPTION
Logs a summary of all states processed during the execution.

.PARAMETER Success
Whether the overall execution was successful.
#>
function Write-StateSummary {
    param(
        [Parameter(Mandatory=$true)]
        [bool]$Success
    )    if ($script:LoggingMode -ne "StateMachine") {
        return
    }
    
    # Calculate total duration
    $totalDuration = [math]::Round(((Get-Date) - $script:TotalStartTime).TotalSeconds, 1)
    
    # Separate states by status
    $successfulStates = $script:ProcessedStates.Keys | Where-Object { $script:ProcessedStates[$_]["Status"] -eq "Completed" }
    $failedStates = $script:ProcessedStates.Keys | Where-Object { $script:ProcessedStates[$_]["Status"] -eq "Failed" }
    
    # Define standard order for states (to match template format)
    $stateOrder = @("dockerStartup", "dockerReady", "apiReady", "nodeReady")    # Sort successful states based on standard order if they exist in the order array
    $sortedSuccessfulStates = $successfulStates | Sort-Object { 
        $index = [array]::IndexOf($stateOrder, $_)
        if ($index -eq -1) { [int]::MaxValue } else { $index }
    }
    
    Write-Host "`nSUMMARY:"
    
    if ($sortedSuccessfulStates.Count -gt 0) {
        $stateList = $sortedSuccessfulStates -join ", "
        Write-Host "$($script:StatusIcons['Completed']) Successfully processed: $stateList" -ForegroundColor Green
        
        # Log to file
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [SUCCESS] - $($script:StatusIcons['Completed']) Successfully processed: $stateList"
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
    
    if ($failedStates.Count -gt 0) {
        $stateList = $failedStates -join ", "
        Write-Host "$($script:StatusIcons['Failed']) Failed: $stateList" -ForegroundColor Red
        
        # Log to file
        $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] - $($script:StatusIcons['Failed']) Failed: $stateList"
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
    
    Write-Host "⏱️ Total time: $totalDuration`s`n" -ForegroundColor Gray
    
    # Log to file
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] - ⏱️ Total time: $totalDuration`s"
    $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    
    # Reset state machine variables for next run
    $script:StateTransitionStarted = $false
    $script:StateStartTimes = @{}
    $script:ActionStartTimes = @{}
    $script:ProcessedStates = @{}
    $script:TotalStartTime = $null
}

# Export module members
Export-ModuleMember -Function Set-LogPath, Set-LoggingMode, Write-Log, Write-StateLog, Get-StateIcon, 
                     Start-StateTransitions, Start-StateProcessing, Write-StateCheck, Write-StateCheckResult,
                     Start-StateActions, Start-StateAction, Complete-StateAction, Complete-State, Write-StateSummary

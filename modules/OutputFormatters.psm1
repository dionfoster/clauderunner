# OutputFormatters.psm1 - Modular output formatting for Claude Task Runner

<#
.SYNOPSIS
Provides multiple output formatting options for task runner execution summaries.

.DESCRIPTION
This module contains formatters that take state summary data and produce different
output formats: Default (current), Simple, Medium, and Elaborate. Also provides
real-time formatting functions for unified theming during execution.
#>

# ═══════════════════════════════════════════════════════════════════════════════
# REAL-TIME FORMATTING FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
Real-time formatting functions for different output themes.
These functions provide themed output during execution, not just in the summary.
#>

# Default format real-time functions (current behavior)
function Write-StateTransitionsHeader-Default {
    return "STATE TRANSITIONS:"
}

function Write-StateStart-Default {
    param([string]$StateName, [string]$StateIcon, [string[]]$Dependencies)
    
    $formattedDeps = $Dependencies | ForEach-Object { "$_ ✓" }
    $depText = if ($Dependencies.Count -gt 0) { 
        "Dependencies: $($formattedDeps -join ', ')" 
    } else { 
        "Dependencies: none" 
    }
    
    return @(
        "┌─ STATE: 🔄 $StateIcon$StateName",
        "│  ├─ $depText"
    )
}

function Write-StateCheck-Default {
    param([string]$CheckType, [string]$CheckDetails)
    return "│  ├─ Check: 🔍 $CheckType check ($CheckDetails)"
}

function Write-StateCheckResult-Default {
    param([bool]$IsReady, [string]$CheckType, [string]$AdditionalInfo)
    
    if ($IsReady) {
        if ($AdditionalInfo) {
            # For endpoint checks, format like the template: "Result: ✅ READY (endpoint status: 200 OK)"
            if ($CheckType -eq "Endpoint" -and $AdditionalInfo -like "*Status:*") {
                $statusCode = $AdditionalInfo -replace ".*Status:\s*", ""
                return "│  └─ Result: ✅ READY (endpoint status: $statusCode OK)"
            } else {
                return "│  └─ Result: ✅ READY ($AdditionalInfo)"
            }
        } else {
            return "│  └─ Result: ✅ READY (already ready via $($CheckType.ToLower()) check)"
        }
    } else {
        return "│  └─ Result: ❌ NOT READY (proceeding with actions)"
    }
}

function Write-StateActionsHeader-Default {
    return "│  ├─ Actions: ⏳ EXECUTING"
}

function Write-StateActionStart-Default {
    param([string]$ActionType, [string]$Description, [string]$ActionCommand)
    
    $message = "│  │  ├─ Command"
    if ($Description) {
        $message += ": $Description"
    }
    $message += " ($ActionCommand)"
    return $message
}

function Write-StateActionComplete-Default {
    param([bool]$Success, [string]$ErrorMessage, [double]$Duration)
    
    $statusIcon = if ($Success) { "✓" } else { "✗" }
    $statusText = if ($Success) { "SUCCESS" } else { "FAILED" }
    
    $message = "│  │  │  └─ Status: $statusIcon $statusText"
    
    if ($Duration -gt 0) {
        $message += " ($($Duration)s)"
    }
    
    if (-not $Success -and $ErrorMessage) {
        $message += " Error: $ErrorMessage"
    }
    
    return $message
}

function Write-StateComplete-Default {
    param([bool]$Success, [string]$ErrorMessage, [double]$Duration, [string]$StateName = "")
    
    $status = if ($Success) { "✅ COMPLETED" } else { "❌ FAILED" }
    $result = "│  └─ Result: $status ($($Duration)s)"
    
    $output = @($result)
    if (-not $Success -and $ErrorMessage) {
        $output += "│     └─ Error: $ErrorMessage"
    }
    
    return $output
}

# Simple format real-time functions
function Write-StateTransitionsHeader-Simple {
    return $null  # No header during execution - summary shows all
}

function Write-StateStart-Simple {
    param([string]$StateName, [string]$StateIcon, [string[]]$Dependencies)
    return $null  # Minimal output during execution
}

function Write-StateCheck-Simple {
    param([string]$CheckType, [string]$CheckDetails)
    return $null  # No check details during execution
}

function Write-StateCheckResult-Simple {
    param([bool]$IsReady, [string]$CheckType, [string]$AdditionalInfo)
    return $null  # Results shown in summary only
}

function Write-StateActionsHeader-Simple {
    return $null  # No action header
}

function Write-StateActionStart-Simple {
    param([string]$ActionType, [string]$Description, [string]$ActionCommand)
    return $null  # No action start output
}

function Write-StateActionComplete-Simple {
    param([bool]$Success, [string]$ErrorMessage, [double]$Duration)
    return $null  # No action completion output
}

function Write-StateComplete-Simple {
    param([bool]$Success, [string]$ErrorMessage, [double]$Duration, [string]$StateName = "")
    return $null  # No state completion output
}

# Medium format real-time functions
function Write-StateTransitionsHeader-Medium {
    return @(
        "📋 TASK EXECUTION",
        "=================="
    )
}

function Write-StateStart-Medium {
    param([string]$StateName, [string]$StateIcon, [string[]]$Dependencies)
    
    $output = @("▶ Processing: $StateName $StateIcon")
    if ($Dependencies.Count -gt 0) {
        $depStatus = $Dependencies | ForEach-Object { "$_ ✓" }
        $output += "  Prerequisites: $($depStatus -join ', ')"
    }
    return $output
}

function Write-StateCheck-Medium {
    param([string]$CheckType, [string]$CheckDetails)
    return "  🔍 Checking: $CheckType → $CheckDetails"
}

function Write-StateCheckResult-Medium {
    param([bool]$IsReady, [string]$CheckType, [string]$AdditionalInfo)
    
    if ($IsReady) {
        $info = if ($AdditionalInfo) { " ($AdditionalInfo)" } else { "" }
        return "  ✅ Result: READY$info"
    } else {
        return "  ⚠️ Result: Not ready, executing actions..."
    }
}

function Write-StateActionsHeader-Medium {
    return "  🚀 Executing actions..."
}

function Write-StateActionStart-Medium {
    param([string]$ActionType, [string]$Description, [string]$ActionCommand)
    
    $desc = if ($Description) { $Description } else { $ActionCommand }
    return "    ⏳ $ActionType`: $desc"
}

function Write-StateActionComplete-Medium {
    param([bool]$Success, [string]$ErrorMessage, [double]$Duration)
    
    if ($Success) {
        $durationText = if ($Duration -gt 0) { " (${Duration}s)" } else { "" }
        return "    ✅ Completed$durationText"
    } else {
        $errorText = if ($ErrorMessage) { " - $ErrorMessage" } else { "" }
        return "    ❌ Failed$errorText"
    }
}

function Write-StateComplete-Medium {
    param([bool]$Success, [string]$ErrorMessage, [double]$Duration, [string]$StateName = "")
    
    if ($Success) {
        return "  ✅ $StateName completed (${Duration}s)"
    } else {
        $errorText = if ($ErrorMessage) { " - $ErrorMessage" } else { "" }
        return "  ❌ $StateName failed (${Duration}s)$errorText"
    }
}

# Elaborate format real-time functions
function Write-StateTransitionsHeader-Elaborate {
    return @(
        "===============================================================================",
        "                        [rocket] CLAUDE TASK EXECUTION ENGINE                 ",
        "===============================================================================",
        "",
        "[clipboard] EXECUTION TIMELINE & STATE TRANSITIONS",
        "==============================================================================="
    )
}

function Write-StateStart-Elaborate {
    param([string]$StateName, [string]$StateIcon, [string[]]$Dependencies)
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    $output = @(
        "",
        "===============================================================================",
        "| [target] STATE PROCESSING: $($StateName.ToUpper().PadRight(50)) |",
        "===============================================================================",
        "[clock] Timestamp: $timestamp",
        "[target] Target State: $StateName $StateIcon"
    )
    
    if ($Dependencies.Count -gt 0) {
        $output += "[clipboard] Prerequisites: $($Dependencies.Count) dependencies"
        foreach ($dep in $Dependencies) {
            $output += "   [check] $dep (satisfied)"
        }
    } else {
        $output += "[clipboard] Prerequisites: No dependencies required"
    }
    
    $output += "[arrows_clockwise] Status: INITIATING STATE PROCESSING..."
    
    return $output
}

function Write-StateCheck-Elaborate {
    param([string]$CheckType, [string]$CheckDetails)
    
    return @(
        "",
        "[search] READINESS ASSESSMENT",
        "-------------------------------------------------------------------------------",
        "[bar_chart] Check Type: $CheckType",
        "[target] Target: $CheckDetails",
        "[hourglass] Status: EVALUATING CURRENT STATE..."
    )
}

function Write-StateCheckResult-Elaborate {
    param([bool]$IsReady, [string]$CheckType, [string]$AdditionalInfo)
    
    if ($IsReady) {
        $output = @(
            "[check] ASSESSMENT RESULT: STATE ALREADY ACHIEVED",
            "[tada] Outcome: Target state is already active and operational"
        )
        if ($AdditionalInfo) {
            $output += "[chart_with_upwards_trend] Details: $AdditionalInfo"
        }
        $output += @(
            "[rocket] Next Action: Skipping execution phase (optimization achieved)",
            "-------------------------------------------------------------------------------"
        )
    } else {
        $output = @(
            "[warning] ASSESSMENT RESULT: STATE REQUIRES ACTIVATION",
            "[wrench] Outcome: Target state needs configuration/execution",
            "[rocket] Next Action: Proceeding to execution phase...",
            "-------------------------------------------------------------------------------"
        )
    }
    
    return $output
}

function Write-StateActionsHeader-Elaborate {
    return @(
        "",
        "[rocket] EXECUTION PHASE",
        "===============================================================================",
        "[briefcase] Action Management: Coordinating state activation sequence"
    )
}

function Write-StateActionStart-Elaborate {
    param([string]$ActionType, [string]$Description, [string]$ActionCommand)
    
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    
    $output = @(
        "",
        "-------------------------------------------------------------------------------",
        "| [zap] ACTION EXECUTION INITIATED                                            |",
        "-------------------------------------------------------------------------------",
        "[clock] Start Time: $timestamp",
        "[target] Action Type: $ActionType",
        "[memo] Command: $ActionCommand"
    )
    
    if ($Description) {
        $output += "[clipboard] Description: $Description"
    }
    
    $output += @(
        "[arrows_clockwise] Status: EXECUTING...",
        "-------------------------------------------------------------------------------"
    )
    
    return $output
}

function Write-StateActionComplete-Elaborate {
    param([bool]$Success, [string]$ErrorMessage, [double]$Duration)
    
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $statusIcon = if ($Success) { "[check]" } else { "[x]" }
    $statusText = if ($Success) { "SUCCESSFUL COMPLETION" } else { "EXECUTION FAILURE" }
    
    $output = @(
        "[clock] End Time: $timestamp",
        "[bar_chart] Duration: ${Duration} seconds",
        "[target] Result: $statusIcon $statusText"
    )
    
    if (-not $Success -and $ErrorMessage) {
        $output += @(
            "[boom] Error Analysis:",
            "   \- $ErrorMessage"
        )
    }
    
    $output += "-------------------------------------------------------------------------------"
    
    return $output
}

function Write-StateComplete-Elaborate {
    param([bool]$Success, [string]$ErrorMessage, [double]$Duration, [string]$StateName = "")
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $statusIcon = if ($Success) { "[tada]" } else { "[boom]" }
    $statusText = if ($Success) { "MISSION ACCOMPLISHED" } else { "MISSION FAILED" }
    
    $output = @(
        "",
        "===============================================================================",
        "| $statusIcon STATE PROCESSING COMPLETE: $statusText                         |",
        "===============================================================================",
        "[clock] Completion Time: $timestamp",
        "[bar_chart] Total Duration: ${Duration} seconds"
    )
    
    if ($Success) {
        $output += @(
            "[target] Outcome: State successfully achieved and validated",
            "[rocket] System Status: Ready for next operations"
        )
    } else {
        $output += @(
            "[target] Outcome: State activation failed",
            "[wrench] System Status: Requires intervention"
        )
        if ($ErrorMessage) {
            $output += @(
                "[boom] Root Cause Analysis:",
                "   \- $ErrorMessage"
            )
        }
    }
    
    return $output
}

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY FORMAT FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
Default format summary function - not currently implemented as DefaultFormat uses StateVisualization logic.
#>
function Format-DefaultOutput {
    param([hashtable]$Summary, [bool]$Success, [string]$ErrorMessage, [double]$Duration)
    # Default format summary is handled by StateVisualization.psm1
    return @()
}

<#
.SYNOPSIS
Simple format summary function matching success-simple.template.
#>
function Format-SimpleOutput {
    param([hashtable]$Summary, [bool]$Success, [string]$ErrorMessage, [double]$Duration)
    
    $output = @()
    
    # Header: Claude Task Runner - Target: <target>
    $targetState = if ($Summary.TargetState) { $Summary.TargetState } else { "unknown" }
    $output += "Claude Task Runner - Target: $targetState"
    $output += " "
    
    # States chain: state1 -> state2 -> state3
    if ($Summary.States.Count -gt 0) {
        $stateNames = $Summary.StateStartTimes.GetEnumerator() | Sort-Object Value | ForEach-Object { $_.Key }
        $output += "States: $($stateNames -join ' -> ')"
        $output += " "
        
        # Individual state summaries
        foreach ($stateName in $stateNames) {
            $state = $Summary.States[$stateName]
            $duration = if ($state.Duration) { [math]::Round($state.Duration.TotalSeconds, 1) } else { 0 }
            
            if ($state.Actions -and $state.Actions.Count -gt 0) {
                # State with actions: "fourthState: EXECUTED 4 actions - 3.6s"
                $output += "$stateName`: EXECUTED $($state.Actions.Count) actions - $($duration)s"
                
                # Action details
                foreach ($action in $state.Actions) {
                    $actionDuration = if ($action.Duration) { [math]::Round($action.Duration.TotalSeconds, 1) } else { 0 }
                    $actionName = if ($action.Description) { $action.Description } else { $action.Command }
                    $output += "  - $actionName`: $($actionDuration)s"
                }
            } else {
                # State without actions: "firstState: READY (command check) - 4.1s"
                $readinessInfo = ""
                if ($state.Result -like "*command check*") {
                    $readinessInfo = " (command check)"
                } elseif ($state.Result -like "*endpoint*") {
                    $readinessInfo = " (endpoint 200 OK)"
                }
                $output += "$stateName`: READY$readinessInfo - $($duration)s"
            }
        }
        
        $output += " "
    }
    
    # Final status: "Status: SUCCESS (4/4 completed in 11.0s)"
    if ($Success) {
        $completedCount = ($Summary.States.Values | Where-Object { $_.Success -eq $true }).Count
        $totalCount = $Summary.States.Count
        $output += "Status: SUCCESS ($completedCount/$totalCount completed in $($Duration)s)"
    } else {
        $output += "Status: FAILED - $ErrorMessage"
    }
    
    return $output
}

<#
.SYNOPSIS
Medium format summary function.
#>
function Format-MediumOutput {
    param([hashtable]$Summary, [bool]$Success, [string]$ErrorMessage, [double]$Duration)
    
    $output = @()
    
    # Header: Boxed header with target name
    $targetState = if ($Summary.TargetState) { $Summary.TargetState } else { "unknown" }
    
    # Calculate proper spacing for alignment
    # Total box width is 80 characters
    # Inner content width is 78 characters (between the ║ symbols)
    $titleText = "🚀 Claude Task Runner"
    $titleLength = $titleText.Length  # This will be 21
    $titlePadding = 78 - $titleLength
    $titleLeftPad = [math]::Floor($titlePadding / 2)
    $titleRightPad = $titlePadding - $titleLeftPad
    $runnerLine = "║" + " " * $titleLeftPad + $titleText + " " * $titleRightPad + "║"
    
    # For target line: "Target: " + targetState
    $targetContent = "Target: $targetState"
    $targetPadding = 78 - $targetContent.Length
    $targetLeftPad = [math]::Floor($targetPadding / 2)
    $targetRightPad = $targetPadding - $targetLeftPad
    $targetLine = "║" + " " * $targetLeftPad + $targetContent + " " * $targetRightPad + "║"
    
    $output += "╔══════════════════════════════════════════════════════════════════════════════╗"
    $output += $runnerLine
    $output += $targetLine
    $output += "╚══════════════════════════════════════════════════════════════════════════════╝"
    $output += ""
    
    # Execution Flow
    $output += "📊 EXECUTION FLOW"
    $output += "─────────────────"
    if ($Summary.States.Count -gt 0) {
        $stateNames = $Summary.StateStartTimes.GetEnumerator() | Sort-Object Value | ForEach-Object { $_.Key }
        $flowLine = $stateNames | ForEach-Object { "[$_]" }
        $output += $flowLine -join " ──→ "
    }
    $output += ""
    
    # State Details
    $output += "🔍 STATE DETAILS"
    $output += "────────────────"
    
    if ($Summary.States.Count -gt 0) {
        $stateNames = $Summary.StateStartTimes.GetEnumerator() | Sort-Object Value | ForEach-Object { $_.Key }
        
        foreach ($stateName in $stateNames) {
            $state = $Summary.States[$stateName]
            $duration = if ($state.Duration) { [math]::Round($state.Duration.TotalSeconds, 1) } else { 0 }
            
            # State header with dependencies
            $dependencies = ""
            if ($state.Dependencies -and $state.Dependencies.Count -gt 0) {
                $dependencies = " (depends: $($state.Dependencies -join ', '))"
            }
            $output += "▶ $stateName$dependencies"
            
            # Check result or actions
            if ($state.Actions -and $state.Actions.Count -gt 0) {
                # State with actions: show action summary
                $actionSummary = @()
                foreach ($action in $state.Actions) {
                    $actionDuration = if ($action.Duration) { [math]::Round($action.Duration.TotalSeconds, 1) } else { 0 }
                    $actionName = if ($action.Description) { $action.Description } else { $action.Command }
                    $actionSummary += "$actionName($($actionDuration)s)"
                }
                $output += "  Actions: $($actionSummary -join ' | ')"
                $output += "  Result: ✅ COMPLETED"
            } else {
                # State without actions: show readiness check
                $checkResult = ""
                if ($state.Result -like "*command check*") {
                    $checkResult = "docker info → ✅ READY"
                } elseif ($state.Result -like "*endpoint*") {
                    $checkResult = "https://localhost:5001/healthcheck → ✅ 200 OK"
                } else {
                    $checkResult = "readiness check → ✅ READY"
                }
                $output += "  Check: $checkResult"
            }
            
            $output += "  Time: $($duration)s"
            $output += ""
        }
    }
    
    # Summary
    if ($Success) {
        $completedCount = ($Summary.States.Values | Where-Object { $_.Success -eq $true }).Count
        $totalCount = $Summary.States.Count
        $output += "📈 SUMMARY: ✅ $completedCount/$totalCount states completed successfully in $($Duration)s"
    } else {
        $output += "📈 SUMMARY: ❌ Execution failed - $ErrorMessage"
    }
    
    return $output
}

<#
.SYNOPSIS
Elaborate format summary function.
#>
function Format-ElaborateOutput {
    param([hashtable]$Summary, [bool]$Success, [string]$ErrorMessage, [double]$Duration)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $statusIcon = if ($Success) { "[check]" } else { "[x]" }
    $statusText = if ($Success) { "MISSION ACCOMPLISHED" } else { "MISSION FAILED" }
    
    $output = @(
        "",
        "===============================================================================",
        "| $statusIcon STATE PROCESSING COMPLETE: $statusText                         |",
        "===============================================================================",
        "[clock] Completion Time: $timestamp",
        "[bar_chart] Total Duration: ${Duration} seconds"
    )
    
    if ($Success) {
        $output += @(
            "[target] Outcome: State successfully achieved and validated",
            "[rocket] System Status: Ready for next operations"
        )
    } else {
        $output += @(
            "[target] Outcome: State activation failed",
            "[wrench] System Status: Requires intervention"
        )
        if ($ErrorMessage) {
            $output += @(
                "[boom] Root Cause Analysis:",
                "   \- $ErrorMessage"
            )
        }
    }
    
    return $output
}

<#
.SYNOPSIS
Gets the appropriate output formatter function based on format name.

.DESCRIPTION
Returns the formatter function that matches the requested format name.
Validates format names and provides fallback to default format.

.PARAMETER FormatName
The name of the output format: Default, Simple, Medium, or Elaborate.

.OUTPUTS
Returns the formatter function or $null if format not found.
#>
function Get-OutputFormatter {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Default", "Simple", "Medium", "Elaborate")]
        [string]$FormatName
    )
    
    switch ($FormatName.ToLower()) {
        "default" { return ${function:Format-DefaultOutput} }
        "simple" { return ${function:Format-SimpleOutput} }
        "medium" { return ${function:Format-MediumOutput} }
        "elaborate" { return ${function:Format-ElaborateOutput} }
        default { return ${function:Format-DefaultOutput} }
    }
}

<#
.SYNOPSIS
Gets the appropriate real-time formatter functions for a given format.

.DESCRIPTION
Returns a hashtable of formatter functions for real-time output based on the selected format.

.PARAMETER FormatName
The name of the output format: Default, Simple, Medium, or Elaborate.

.OUTPUTS
Returns a hashtable with function references for each real-time formatting need.
#>
function Get-RealtimeFormatters {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Default", "Simple", "Medium", "Elaborate")]
        [string]$FormatName
    )
    
    $suffix = "-$FormatName"
    
    return @{
        StateTransitionsHeader = Get-Item "function:Write-StateTransitionsHeader$suffix"
        StateStart = Get-Item "function:Write-StateStart$suffix"
        StateCheck = Get-Item "function:Write-StateCheck$suffix"
        StateCheckResult = Get-Item "function:Write-StateCheckResult$suffix"
        StateActionsHeader = Get-Item "function:Write-StateActionsHeader$suffix"
        StateActionStart = Get-Item "function:Write-StateActionStart$suffix"
        StateActionComplete = Get-Item "function:Write-StateActionComplete$suffix"
        StateComplete = Get-Item "function:Write-StateComplete$suffix"
    }
}

# Export module members
Export-ModuleMember -Function Format-DefaultOutput, Format-SimpleOutput, 
    Format-MediumOutput, Format-ElaborateOutput, Get-OutputFormatter, Get-RealtimeFormatters

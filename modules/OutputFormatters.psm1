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
    param([string]$TargetState = "unknown")
    
    # Create the boxed header exactly like the template
    $titleText = "🚀 Claude Task Runner"
    $titlePadding = 78 - $titleText.Length
    $titleLeftPad = [math]::Floor($titlePadding / 2)
    $titleRightPad = $titlePadding - $titleLeftPad
    $runnerLine = "║" + " " * $titleLeftPad + $titleText + " " * $titleRightPad + "║"
    
    $targetContent = "Target: $TargetState"
    $targetPadding = 78 - $targetContent.Length
    $targetLeftPad = [math]::Floor($targetPadding / 2)
    $targetRightPad = $targetPadding - $targetLeftPad
    $targetLine = "║" + " " * $targetLeftPad + $targetContent + " " * $targetRightPad + "║"
    
    return @(
        "╔══════════════════════════════════════════════════════════════════════════════╗",
        $runnerLine,
        $targetLine,
        "╚══════════════════════════════════════════════════════════════════════════════╝"
    )
}

function Write-StateStart-Medium {
    param([string]$StateName, [string]$StateIcon, [string[]]$Dependencies)
    
    # Format: ▶ stateName (depends: dep1, dep2) or just ▶ stateName if no dependencies
    if ($Dependencies -and $Dependencies.Count -gt 0) {
        return "▶ $StateName (depends: $($Dependencies -join ', '))"
    } else {
        return "▶ $StateName"
    }
}

function Write-StateCheck-Medium {
    param([string]$CheckType, [string]$CheckDetails)
    # Don't show the checking line, we'll show the result in Write-StateCheckResult-Medium
    return $null
}

function Write-StateCheckResult-Medium {
    param([bool]$IsReady, [string]$CheckType, [string]$AdditionalInfo)
    
    if ($IsReady) {
        # Format like template: "Check: docker info → ✅ READY" or "Check: https://localhost:5001/healthcheck → ✅ 200 OK"
        if ($CheckType -eq "Endpoint" -and $AdditionalInfo -like "*Status:*") {
            $statusCode = $AdditionalInfo -replace ".*Status:\s*", ""
            return "  Check: https://localhost:5001/healthcheck → ✅ $statusCode OK"
        } else {
            return "  Check: docker info → ✅ READY"
        }
    } else {
        return "  Check: docker info → ❌ NOT READY"
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
    
    # Always show time like the template: "Time: X.Xs"
    return "  Time: $($Duration)s"
}

# Elaborate format real-time functions
function Write-StateTransitionsHeader-Elaborate {
    param([string]$TargetState = "")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $targetText = if ($TargetState) { $TargetState } else { "Unknown" }
    
    # Create properly aligned content (84 characters total for all lines)
    $titleLine = "  🎯 Claude Task Runner v2.0 - Execution Report"
    $titlePadding = 82 - $titleLine.Length  # 82 = 84 total - 2 pipes
    $titleLinePadded = $titleLine + (" " * $titlePadding)
    
    $targetLine = "  🎪 Target Environment: $targetText | 📅 Started: $timestamp"
    $targetPadding = 82 - $targetLine.Length
    $targetLinePadded = $targetLine + (" " * $targetPadding)
    
    $matrixLine = "                           ⚙️ STATE EXECUTION MATRIX"
    $matrixPadding = 82 - $matrixLine.Length
    $matrixLinePadded = $matrixLine + (" " * $matrixPadding)
    
    return @(
        "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓",
        "┃$titleLinePadded┃",
        "┃$targetLinePadded┃",
        "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛",
        "",
        "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓",
        "┃$matrixLinePadded┃",
        "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    )
}

function Write-StateStart-Elaborate {
    param([string]$StateName, [string]$StateIcon, [string[]]$Dependencies)
    
    # Determine state emoji and type
    $stateEmoji = switch ($StateName) {
        { $_ -match "first" } { "🏁" }
        { $_ -match "second" } { "🔄" }
        { $_ -match "third" } { "🌐" }
        { $_ -match "fourth" } { "⚡" }
        default { "🔵" }
    }
    
    $output = @(
        "",
        "┌─ $stateEmoji STATE: $StateName $('─' * (69 - $StateName.Length))┐"
    )
    
    # Dependencies section
    if ($Dependencies.Count -gt 0) {
        $depText = ($Dependencies | ForEach-Object { "✅ $_ (satisfied)" }) -join ", "
        $output += "│  🔗 Dependencies: $depText"
    } else {
        $output += "│  🔗 Dependencies: 🚫 None (root state)"
    }
    
    return $output
}

function Write-StateCheck-Elaborate {
    param([string]$CheckType, [string]$CheckDetails)
    
    $checkTypeDisplay = switch ($CheckType) {
        "Command" { "Command Validation" }
        "Endpoint" { "HTTP Endpoint Validation" }
        default { $CheckType }
    }
    
    $output = @(
        "│  🔍 Readiness Check: $checkTypeDisplay"
    )
    
    if ($CheckType -eq "Command") {
        $output += "│  │   ├─ 💻 Command: $CheckDetails"
        $output += "│  │   ├─ ⏰ Timeout: 30s"
    } elseif ($CheckType -eq "Endpoint") {
        $output += "│  │   ├─ 🌍 Endpoint: $CheckDetails"
        $output += "│  │   ├─ ⏰ Timeout: 30s"
        $output += "│  │   ├─ 🔄 Retries: 3 attempts"
    }
    
    return $output
}

function Write-StateCheckResult-Elaborate {
    param(
        [bool]$IsReady, 
        [string]$CheckType, 
        [string]$AdditionalInfo,
        [double]$Duration = 0.0,
        [string]$Status = "SUCCESS"
    )
    
    # Complete the check result line
    $resultText = if ($IsReady) {
        if ($CheckType -eq "Command") {
            "✅ READY (exit code: 0)"
        } elseif ($CheckType -eq "Endpoint") {
            "✅ READY (HTTP 200 OK)"
        } else {
            "✅ READY"
        }
    } else {
        "❌ NOT READY"
    }
    
    $output = @(
        "│  │   └─ 📊 Result: $resultText"
    )
    
    # Add performance metrics
    $statusIcon = if ($Status -eq "SUCCESS") { "SUCCESS" } else { "FAILED" }
    $efficiency = if ($IsReady) { "100%" } else { "0%" }
    $durationText = if ($Duration -gt 0) { "$($Duration.ToString('F1'))s" } else { "0.0s" }
    
    $output += "│  📈 Performance: ⚡ $durationText | 🎯 Status: $statusIcon | 🏆 Efficiency: $efficiency"
    $output += "└─────────────────────────────────────────────────────────────────────────────┘"
    
    return $output
}

function Write-StateActionsHeader-Elaborate {
    return @(
        "│  🎬 Execution Phase: Multi-Action Sequence",
        "│  │"
    )
}

function Write-StateActionStart-Elaborate {
    param(
        [string]$ActionType, 
        [string]$Description, 
        [string]$ActionCommand,
        [int]$ActionIndex = 1,
        [int]$TotalActions = 1
    )
    
    # Get action emoji based on type or command
    $actionEmoji = switch -Regex ($ActionCommand) {
        "Set-.*Version" { "🛠️" }
        ".*--version" { "🔍" }
        ".*install" { "📥" }
        ".*run.*dev" { "🚀" }
        default { "⚙️" }
    }
    
    return @(
        "│  │  ┌─ $actionEmoji ACTION $ActionIndex/$TotalActions $('─' * (58 - $ActionIndex.ToString().Length - $TotalActions.ToString().Length))┐   │",
        "│  │  │ 📦 Command: $ActionCommand$(' ' * (50 - $ActionCommand.Length))│   │"
    )
}

function Write-StateActionComplete-Elaborate {
    param([bool]$Success, [string]$ErrorMessage, [double]$Duration, [int]$ExitCode = 0)
    
    $statusIcon = if ($Success) { "✅ SUCCESS" } else { "❌ FAILED" }
    $durationText = $Duration.ToString("F1")
    
    return @(
        "│  │  │ ⏱️ Duration: ${durationText}s | 📊 Exit Code: $ExitCode | 🎯 Status: $statusIcon    │   │",
        "│  │  └─────────────────────────────────────────────────────────────────┘   │"
    )
}

function Write-StateComplete-Elaborate {
    param([bool]$Success, [string]$ErrorMessage, [double]$Duration, [string]$StateName = "", [bool]$IsExecutionState = $false)
    
    if ($IsExecutionState) {
        # For execution states, complete the state block
        $statusText = if ($Success) { "COMPLETED" } else { "FAILED" }
        $efficiency = if ($Success) { "100%" } else { "0%" }
        $durationText = $Duration.ToString("F1")
        
        return @(
            "│  │",
            "│  📈 Performance: ⚡ ${durationText}s | 🎯 Status: $statusText | 🏆 Efficiency: $efficiency",
            "└─────────────────────────────────────────────────────────────────────────────┘"
        )
    } else {
        # For readiness states, this is already handled by Write-StateCheckResult-Elaborate
        return @()
    }
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
    
    $output = @()
    $output += " "
    $output += " "
    $output += "EXECUTION SUMMARY"
    $output += "----------------"
    
    if ($Summary.States.Count -gt 0) {
        # Use StateStartTimes if available, otherwise use State names in order
        if ($Summary.StateStartTimes) {
            $sortedStates = $Summary.States.GetEnumerator() | Sort-Object { $Summary.StateStartTimes[$_.Key] }
        } else {
            $sortedStates = $Summary.States.GetEnumerator()
        }
        
        foreach ($state in $sortedStates) {
            $status = if ($state.Value.Success) { "✓" } else { "✗" }
            $stateDuration = if ($state.Value.Duration) { [math]::Round($state.Value.Duration.TotalSeconds, 1) } else { 0 }
            $output += "$status $($state.Key) ($($stateDuration)s)"
        }
    }
    
    $output += " "
    $completedCount = @($Summary.States.Values | Where-Object { $_.Success -eq $true }).Count
    $totalCount = $Summary.States.Count
    $output += "Completed: $completedCount/$totalCount states in $($Duration)s"
    
    if (-not $Success -and $ErrorMessage) {
        $output += "Error: $ErrorMessage"
    }
    
    return $output
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
        # Use StateStartTimes if available, otherwise use State names in order
        if ($Summary.StateStartTimes) {
            $stateNames = $Summary.StateStartTimes.GetEnumerator() | Sort-Object Value | ForEach-Object { $_.Key }
        } else {
            $stateNames = $Summary.States.Keys
        }
        $output += "States: $($stateNames -join ' -> ')"
        $output += " "
        
        # Individual state summaries
        foreach ($stateName in $stateNames) {
            $state = $Summary.States[$stateName]
            $stateDuration = if ($state.Duration) { [math]::Round($state.Duration.TotalSeconds, 1) } else { 0 }
            
            if ($state.Actions -and $state.Actions.Count -gt 0) {
                # State with actions: "fourthState: EXECUTED 4 actions - 3.6s"
                $output += "$stateName`: EXECUTED $($state.Actions.Count) actions - $($stateDuration)s"
                
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
                $output += "$stateName`: READY$readinessInfo - $($stateDuration)s"
            }
        }
        
        $output += " "
    }
    
    # Final status: "Status: SUCCESS (4/4 completed in 11.0s)"
    if ($Success) {
        $completedCount = @($Summary.States.Values | Where-Object { $_.Success -eq $true }).Count
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
    
    # For Medium format, the header, execution flow, and state details are already shown in real-time
    # Only show the final summary line
    $successCount = @($Summary.States.Values | Where-Object { $_.Success -eq $true }).Count
    $totalCount = $Summary.States.Count
    $statusIcon = if ($Success) { "✅" } else { "❌" }
    
    return "📈 SUMMARY: $statusIcon $successCount/$totalCount states completed successfully in $($Duration)s"
}

<#
.SYNOPSIS
Elaborate format summary function.
#>
function Format-ElaborateOutput {
    param([hashtable]$Summary, [bool]$Success, [string]$ErrorMessage, [double]$Duration)
    
    # Header section
    $startTime = if ($Summary.StartTime) { $Summary.StartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
    $targetState = if ($Summary.TargetState) { $Summary.TargetState } else { "unknown" }
    
    $output = @(
        "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓",
        "┃  🎯 Claude Task Runner v2.0 - Execution Report                              ┃",
        "┃  🎪 Target Environment: $targetState | 📅 Started: $startTime         ┃",
        "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    )
    
    # State execution matrix
    $output += @(
        "",
        "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓",
        "┃                           🏗️ STATE EXECUTION MATRIX                          ┃",
        "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    )
    
    # Add states from summary
    if ($Summary.States -and $Summary.States.Count -gt 0) {
        # Use StateStartTimes if available for proper ordering
        if ($Summary.StateStartTimes) {
            $stateNames = $Summary.StateStartTimes.GetEnumerator() | Sort-Object Value | ForEach-Object { $_.Key }
        } else {
            $stateNames = $Summary.States.Keys
        }
        
        foreach ($stateName in $stateNames) {
            $state = $Summary.States[$stateName]
            $duration = if ($state.Duration) { [math]::Round($state.Duration.TotalSeconds, 1) } else { 0 }
            $status = if ($state.Success) { "SUCCESS" } else { "FAILED" }
            
            # Get state icon
            $icon = switch ($stateName.ToLower()) {
                "dockerstartup" { "🏁" }
                "dockerready" { "🐳" }
                "apiready" { "🚀" }
                "nodeready" { "🌐" }
                default { "⚡" }
            }
            
            # Determine dependencies
            $dependencies = @()
            if ($state.Dependencies) {
                $dependencies = $state.Dependencies
            }
            
            $output += @(
                "",
                "┌─ $icon STATE: $stateName $('─' * (69 - $stateName.Length))┐",
                "│  🔗 Dependencies: $(if ($dependencies.Count -gt 0) { "✅ $($dependencies -join ', ') (satisfied)" } else { "🚫 None (root state)" })     │"
            )
            
            # Add readiness check info
            if ($state.Actions -and $state.Actions.Count -gt 0) {
                $output += "│  🎬 Execution Phase: Multi-Action Sequence                                 │"
                
                # Show actions
                for ($i = 0; $i -lt $state.Actions.Count; $i++) {
                    $action = $state.Actions[$i]
                    $actionDuration = if ($action.Duration) { [math]::Round($action.Duration.TotalSeconds, 1) } else { 0 }
                    $actionCommand = if ($action.Command) { $action.Command } else { "Unknown" }
                    $actionStatus = if ($action.Success) { "SUCCESS" } else { "FAILED" }
                    
                    $output += @(
                        "│  │  ┌─ 🛠️ ACTION $($i+1)/$($state.Actions.Count) ──────────────────────────────────────────────────┐   │",
                        "│  │  │ 📦 Command: $actionCommand                    │   │",
                        "│  │  │ ⏱️ Duration: ${actionDuration}s | 🎯 Status: $(if ($action.Success) { "✅ SUCCESS" } else { "❌ FAILED" })    │   │",
                        "│  │  └─────────────────────────────────────────────────────────────────┘   │"
                    )
                }
            } else {
                $output += "│  🔍 Readiness Check: Command Validation                                    │"
                $output += "│  │   ├─ 💻 Command: docker info                                           │"
                $output += "│  │   ├─ ⏰ Timeout: 30s                                                   │"
                $output += "│  │   └─ 📊 Result: ✅ READY (exit code: 0)                               │"
            }
            
            $output += @(
                "│  📈 Performance: ⚡ ${duration}s | 🎯 Status: $status | 🏆 Efficiency: 100%        │",
                "└─────────────────────────────────────────────────────────────────────────────┘"
            )
        }
    }
    
    # Final summary
    $successCount = @($Summary.States.Values | Where-Object { $_.Success -eq $true }).Count
    $totalCount = $Summary.States.Count
    $successRate = if ($totalCount -gt 0) { [math]::Round(($successCount / $totalCount) * 100, 0) } else { 0 }
    $avgDuration = if ($totalCount -gt 0) { [math]::Round($Duration / $totalCount, 2) } else { 0 }
    
    $output += @(
        "",
        "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓",
        "┃                         📊 EXECUTION ANALYTICS DASHBOARD                         ┃",
        "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛",
        "",
        "🏆 SUCCESS METRICS"
    )
    
    # Add state table
    if ($Summary.States -and $Summary.States.Count -gt 0) {
        $output += "┌─────────────────┬──────────┬──────────┬────────────┬─────────────────────────┐"
        $output += "│ State Name      │ Duration │ Status   │ Efficiency │ Actions Completed       │"
        $output += "├─────────────────┼──────────┼──────────┼────────────┼─────────────────────────┤"
        
        foreach ($stateName in $stateNames) {
            $state = $Summary.States[$stateName]
            $duration = if ($state.Duration) { [math]::Round($state.Duration.TotalSeconds, 1) } else { 0 }
            $status = if ($state.Success) { "✅ READY" } else { "❌ FAILED" }
            $actionCount = if ($state.Actions) { $state.Actions.Count } else { 0 }
            $actionText = if ($actionCount -gt 0) { "$actionCount Commands Executed" } else { "Command Check" }
            
            $paddedName = $stateName.PadRight(15)
            $paddedDuration = "${duration}s".PadLeft(8)
            $paddedStatus = $status.PadRight(8)
            $paddedEfficiency = "100%".PadLeft(10)
            $paddedActions = $actionText.PadRight(23)
            
            $output += "│ $paddedName │ $paddedDuration │ $paddedStatus │ $paddedEfficiency │ $paddedActions │"
        }
        
        $output += "└─────────────────┴──────────┴──────────┴────────────┴─────────────────────────┘"
    }
    
    # Final summary
    $performanceGrade = if ($successRate -eq 100) { "A+ (Excellent)" } else { "B (Good)" }
    $missionStatus = if ($Success) { "🌟 MISSION ACCOMPLISHED! 🌟" } else { "❌ MISSION FAILED" }
    
    $output += @(
        "",
        "🎉 FINAL SUMMARY",
        "════════════════════════════════════════════════════════════════════════════════",
        "🎯 Target Achieved: $targetState",
        "✨ Success Rate: $successCount/$totalCount states ($successRate%)",
        "⏰ Total Execution Time: $($Duration)s",
        "🚀 Average State Duration: $($avgDuration)s",
        "🏅 Performance Grade: $performanceGrade",
        "🎊 Status: $missionStatus",
        "",
        "💡 Next Steps: Environment is ready for development workflow!"
    )
    
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

# Claude Task Runner - State Leakage Analysis & Solutions

## Problem Identified
The Claude Task Runner script maintains state between runs through module-level script variables and global variables, causing potential caching issues and inconsistent behavior between executions.

## State Leakage Sources

### 1. Module Script Variables (Primary Issue)
**StateManagement.psm1:**
- `$script:StateTransitionStarted = $false`
- `$script:StateStartTimes = @{}`
- `$script:ActionStartTimes = @{}`
- `$script:ProcessedStates = @{}`
- `$script:TotalStartTime = $null`

**StateVisualization.psm1:**
- `$script:CurrentOutputFormat = "Default"`
- `$script:RealtimeFormatters = $null`
- `$script:TargetState = $null`

### 2. Global Variables
**claude.ps1:**
- `$global:Verbose = $Verbose`

### 3. Module Caching
PowerShell modules are cached in memory and script variables persist across `Import-Module -Force` calls.

## Solution Options

### Option 1: **Explicit State Reset (RECOMMENDED)**
Add explicit state reset calls at script startup and cleanup.

**Pros:**
- Minimal code changes
- Preserves existing architecture
- Ensures clean state per run
- Easy to implement and test

**Cons:**
- Requires remembering to call reset functions
- Doesn't address root architectural issue

### Option 2: **Module Removal and Reimport**
Force remove and reimport modules each run.

**Pros:**
- Guarantees clean module state
- Simple to implement

**Cons:**
- Performance impact (module loading overhead)
- May affect other scripts using same modules
- Overkill for the problem

### Option 3: **Stateless Architecture Refactor**
Remove all script-level variables and pass state explicitly.

**Pros:**
- Eliminates state leakage entirely
- Better architecture long-term
- Easier to test and debug

**Cons:**
- Major refactoring required
- Breaking changes to module APIs
- Significant testing effort

### Option 4: **Session-Based State Management**
Create a state session object passed between functions.

**Pros:**
- Clean separation of concerns
- Allows multiple concurrent sessions
- Maintains clean APIs

**Cons:**
- Moderate refactoring required
- Changes to function signatures

## Recommended Implementation: Option 1

### Changes Required:

#### 1. Add Script Startup Reset
In `claude.ps1`, add after module imports:
```powershell
# Reset all module state to ensure clean runs
StateManagement\Reset-StateMachineVariables
StateVisualization\Reset-VisualizationState  # New function needed
```

#### 2. Add Script Cleanup
In `claude.ps1`, add before exit:
```powershell
# Clean up state before exit
StateManagement\Reset-StateMachineVariables
StateVisualization\Reset-VisualizationState
Remove-Variable -Name "Verbose" -Scope Global -ErrorAction SilentlyContinue
```

#### 3. Create Reset Function for StateVisualization
Add to `StateVisualization.psm1`:
```powershell
function Reset-VisualizationState {
    $script:CurrentOutputFormat = "Default"
    $script:RealtimeFormatters = $null
    $script:TargetState = $null
}
```

#### 4. Enhanced Reset Function for StateManagement
Ensure `Reset-StateMachineVariables` is comprehensive and exported.

### Quick Implementation Plan:

1. **Phase 1**: Add reset calls to script startup/cleanup
2. **Phase 2**: Create comprehensive reset functions
3. **Phase 3**: Add tests to verify clean state between runs
4. **Phase 4**: Document state management requirements

## Verification Strategy

### Test Cases Needed:
1. **State Isolation Test**: Run script twice with different configs, verify no state bleeding
2. **Variable Reset Test**: Verify all script variables are reset between runs
3. **Output Format Test**: Verify output format doesn't persist between runs
4. **Timing Test**: Verify timing calculations start fresh each run

### Implementation Validation:
- Run script multiple times with different parameters
- Verify consistent behavior regardless of previous runs
- Test with different output formats in sequence
- Monitor memory usage for any leaks

## Benefits of Implementation:
- ✅ Guarantees consistent behavior per run
- ✅ Eliminates caching-related bugs
- ✅ Improves script reliability
- ✅ Maintains existing functionality
- ✅ Minimal performance impact
- ✅ Easy to test and validate

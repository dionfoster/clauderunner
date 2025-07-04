# Claude Task Runner - Stateless Architecture Refactor Plan

## Overview
Transform the Claude Task Runner from a stateful to stateless architecture by eliminating all script-level variables and passing state explicitly through function parameters and return values.

## Current State Analysis

### Script Variables to Eliminate

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

**claude.ps1:**
- `$global:Verbose = $Verbose`

### Functions That Currently Use Script State
1. **StateManagement.psm1**: 15+ functions depend on script variables
2. **StateVisualization.psm1**: 8+ functions depend on script variables
3. **OutputFormatters.psm1**: Functions that call StateManagement/StateVisualization

## Proposed Solution: State Context Object

Create a `$StateContext` object that encapsulates all state and is passed between functions:

```powershell
$StateContext = @{
    # Timing State
    StateTransitionStarted = $false
    StateStartTimes = @{}
    ActionStartTimes = @{}
    ProcessedStates = @{}
    TotalStartTime = $null
    
    # Visualization State
    CurrentOutputFormat = "Default"
    RealtimeFormatters = $null
    TargetState = $null
    
    # Configuration State
    Verbose = $false
    ConfigFile = "claude.yml"
    
    # Runtime State
    CurrentState = $null
    ExecutionResults = @{}
}
```

## Implementation Plan

### Phase 1: Preparation & Testing Foundation
**Goal**: Establish comprehensive test coverage before any changes

#### Step 1.1: Audit Current Function Signatures
- [ ] Document all functions in StateManagement.psm1 and their dependencies
- [ ] Document all functions in StateVisualization.psm1 and their dependencies
- [ ] Map data flow between functions
- [ ] Identify circular dependencies

#### Step 1.2: Create Comprehensive Integration Tests
- [ ] Test complete script execution end-to-end
- [ ] Test with different output formats
- [ ] Test with different configurations
- [ ] Test error scenarios
- [ ] Test state isolation between runs
- [ ] Capture baseline behavior for regression testing

#### Step 1.3: Create State Context Schema
- [ ] Define the complete StateContext structure
- [ ] Create helper functions for StateContext manipulation
- [ ] Define initialization and cleanup patterns
- [ ] Create validation functions for StateContext integrity

### Phase 2: StateManagement.psm1 Refactor
**Goal**: Convert StateManagement to stateless architecture

#### Step 2.1: Create New Function Signatures
- [ ] Design new function signatures that accept StateContext
- [ ] Ensure all functions return updated StateContext
- [ ] Create backward-compatible wrapper functions (temporary)
- [ ] Write unit tests for new function signatures

#### Step 2.2: Implement StateContext-based Functions
- [ ] Convert timing functions (Start-StateTransition, etc.)
- [ ] Convert state tracking functions
- [ ] Convert performance calculation functions
- [ ] Ensure all script variables are replaced with StateContext access

#### Step 2.3: Update Function Exports
- [ ] Export new StateContext-based functions
- [ ] Maintain old functions for backward compatibility (temporary)
- [ ] Update module manifest if needed

### Phase 3: StateVisualization.psm1 Refactor
**Goal**: Convert StateVisualization to stateless architecture

#### Step 3.1: Refactor Visualization Functions
- [ ] Convert output format management functions
- [ ] Convert target state tracking functions
- [ ] Convert realtime formatter functions
- [ ] Replace script variables with StateContext access

#### Step 3.2: Update OutputFormatters Integration
- [ ] Ensure OutputFormatters can work with StateContext
- [ ] Update any direct dependencies on StateVisualization state
- [ ] Test all output formats work correctly

### Phase 4: Main Script Refactor
**Goal**: Update claude.ps1 to use stateless architecture

#### Step 4.1: Initialize StateContext
- [ ] Create StateContext initialization at script start
- [ ] Remove global variable usage
- [ ] Pass StateContext to all function calls

#### Step 4.2: Update Main Execution Flow
- [ ] Modify state machine execution to pass StateContext
- [ ] Update error handling to work with StateContext
- [ ] Ensure StateContext is passed through all execution paths

### Phase 5: Integration & Cleanup
**Goal**: Remove temporary code and validate complete system

#### Step 5.1: Remove Backward Compatibility Code
- [ ] Remove old function implementations
- [ ] Remove script variable declarations
- [ ] Clean up temporary wrapper functions
- [ ] Update all module exports

#### Step 5.2: Final Testing & Validation
- [ ] Run complete test suite
- [ ] Verify no state leakage between runs
- [ ] Performance testing to ensure no regressions
- [ ] Test edge cases and error scenarios

## Risk Mitigation Strategies

### 1. Incremental Implementation
- Implement one module at a time
- Maintain backward compatibility during transition
- Test each phase thoroughly before proceeding

### 2. Comprehensive Testing
- Write tests before making changes (TDD approach)
- Maintain integration tests throughout process
- Create regression test suite

### 3. Rollback Plan
- Use Git branches for each phase
- Maintain working baseline at each step
- Document rollback procedures

### 4. Function Signature Evolution
```powershell
# Current:
function Start-StateTransition { param([string]$StateName) }

# Intermediate (with backward compatibility):
function Start-StateTransition { 
    param(
        [string]$StateName,
        [hashtable]$StateContext = $null
    )
}

# Final:
function Start-StateTransition { 
    param(
        [string]$StateName,
        [hashtable]$StateContext
    )
}
```

## Testing Strategy

### Before Each Phase
1. **Behavioral Tests**: Capture current behavior
2. **Unit Tests**: Test individual functions
3. **Integration Tests**: Test module interactions
4. **End-to-End Tests**: Test complete script execution

### During Implementation
1. **TDD Approach**: Write tests for new signatures first
2. **Parallel Testing**: Run both old and new implementations
3. **State Validation**: Verify StateContext integrity

### After Each Phase
1. **Regression Testing**: Ensure no behavior changes
2. **Performance Testing**: Verify no performance degradation
3. **Integration Testing**: Test cross-module interactions

## Success Criteria

### Functional Requirements
- [ ] All existing functionality preserved
- [ ] No state leakage between script runs
- [ ] All output formats work correctly
- [ ] Error handling remains robust

### Technical Requirements
- [ ] No script-level variables in any module
- [ ] StateContext passed explicitly to all functions
- [ ] Clean function signatures with proper parameter validation
- [ ] Comprehensive test coverage (>95%)

### Performance Requirements
- [ ] No significant performance degradation (<5% slower)
- [ ] Memory usage remains stable
- [ ] Script startup time unchanged

## Timeline Estimate

- **Phase 1**: 3-4 days (comprehensive testing setup)
- **Phase 2**: 4-5 days (StateManagement refactor)
- **Phase 3**: 3-4 days (StateVisualization refactor)
- **Phase 4**: 2-3 days (Main script updates)
- **Phase 5**: 2-3 days (Cleanup and final testing)

**Total**: 14-19 days (assuming focused work)

## Questions for Stakeholder

1. **Scope**: Should we also refactor Configuration.psm1 and other modules for consistency?
2. **Timeline**: Is the 2-3 week timeline acceptable?
3. **Breaking Changes**: Are temporary breaking changes acceptable during development?
4. **Testing**: Should we add any specific test scenarios beyond what's planned?
5. **Performance**: What's the acceptable performance impact threshold?

## Next Steps

Please review this plan and let me know:
1. Which phase should we start with?
2. Any modifications to the approach?
3. Any additional requirements or constraints?
4. Approval to proceed with Phase 1 preparation?

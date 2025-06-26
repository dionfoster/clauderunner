# Output Formatting Modularization Strategy

## Overview
This document outlines a simple approach to add modular output formatting to the task runner without breaking existing functionality.

## Current State Analysis

### StateVisualization.psm1 Current Responsibilities
1. **State Tracking Integration** - Calls to StateManagement functions (SM prefix)
2. **Real-time Output Generation** - Immediate logging during execution
3. **Status Icon Management** - Visual indicators for different states
4. **Summary Generation** - Final execution summary

### What We Want to Add
- Multiple output formats (simple, medium, elaborate)
- Template-based formatting for the final summary
- Keep existing real-time output unchanged

## Simple Modular Approach

### Step 1: Create OutputFormatters.psm1 (This Week)
- [ ] Create new module for post-execution formatting
- [ ] Implement formatters for: Default (current), Simple, Medium, Elaborate
- [ ] Use existing state summary data from StateManagement
- [ ] No changes to StateVisualization.psm1

### Step 2: Add Format Selection (This Week)
- [ ] Add `-OutputFormat` parameter to claude.ps1
- [ ] Add `outputFormat` setting to YAML configuration
- [ ] Default behavior remains unchanged (backwards compatible)
- [ ] New formats only affect final summary, not real-time output

### Step 3: Template Integration (Next Week)
- [ ] Load template files from `/templates` directory
- [ ] Simple variable substitution using state summary data
- [ ] Fallback to default format if template not found
- [ ] No complex templating engine needed

## Implementation Details

### OutputFormatters.psm1 Structure
```powershell
# Simple functions that take state summary data and return formatted strings
function Format-DefaultOutput { param($StateSummary) }
function Format-SimpleOutput { param($StateSummary) }
function Format-MediumOutput { param($StateSummary) }
function Format-ElaborateOutput { param($StateSummary) }
function Get-OutputFormatter { param($FormatName) }
```

### Integration Points
1. **claude.ps1**: Add format selection logic in final success/failure output
2. **Configuration.psm1**: Add outputFormat validation
3. **Templates**: Use existing template files with simple variable substitution

### No Deprecation Needed
- StateVisualization.psm1 continues to handle real-time output
- New module only handles final summary formatting
- Both modules can coexist indefinitely
- Users get additional formatting options without losing existing functionality

## Timeline

| Task | Duration | Deliverable |
|------|----------|-------------|
| Create OutputFormatters.psm1 | 2-3 hours | New module with 4 formatters |
| Add parameter support | 1 hour | Command line and YAML config |
| Template integration | 2-3 hours | Template loading and substitution |
| Testing | 1-2 hours | Verify all formats work |

**Total Time**: 1-2 days maximum

## Success Criteria
- [ ] Multiple output formats available via parameter/config
- [ ] Existing behavior unchanged (backwards compatible) 
- [ ] Template files work with elaborate format
- [ ] No performance impact on execution
- [ ] Simple, maintainable code

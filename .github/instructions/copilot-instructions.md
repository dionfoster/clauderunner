---
applyTo: '**'
---
# Claude Task Runner - Coding Standards & Practices

## Project Philosophy
- **Simplicity**: Favor readable, straightforward code over complex abstractions
- **Maintainability**: Well-documented, consistent code patterns
- **Robustness**: Thorough error handling and graceful failure modes

## Refactoring Guidelines
- Refactor for clarity, not just to reduce lines of code
- Avoid premature optimization; focus on clear, maintainable code first
- Use descriptive names for functions and variables to convey intent
- Break down large functions into smaller, reusable components
- For each refactor, make small incremental changes and test thoroughly

## PowerShell Standards
- Use explicit parameter validation and help documentation
- Follow consistent error handling patterns with try/catch blocks
- Prefer named parameters over positional parameters
- Use Write-Log for all output instead of direct Write-Host calls
- Use proper PowerShell casing (Pascal for functions, camelCase for variables)
- Write functions that do one thing well

## YAML Configuration Standards
- Keep configuration simple and flat where possible
- Use comments to explain non-obvious settings
- Follow a consistent structure for state definitions
- Avoid excessive nesting and complexity
- Prioritize readability over brevity

## Task Runner Design Principles
- States should have clear, single responsibilities
- Dependencies between states should be explicit
- Readiness checks should be reliable and timeout appropriately
- Provide helpful, actionable error messages
- Launch methods should be appropriate to the application type

## Implementation Patterns
- Prefer explicit return values over relying on $LASTEXITCODE
- Always provide working directory context for commands
- Use consistent retry mechanisms for transient failures
- Log both success and failure paths clearly
- Structure code to make failure points obvious

## Documentation Requirements
- Document all functions with comment-based help
- Include examples in README for common usage patterns
- Document any required dependencies or prerequisites
- Explain the reasoning behind complex logic
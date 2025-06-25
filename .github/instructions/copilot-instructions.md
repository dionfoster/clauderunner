---
applyTo: '**'
---
# Claude Task Runner - Coding Standards & Practices

## Project Philosophy
- **Simplicity**: Favor readable, straightforward code over complex abstractions
- **Maintainability**: Well-documented, consistent code patterns
- **Robustness**: Thorough error handling and graceful failure modes
- **Powershell Syntax**: DO NOT CONTINUE IF SYNTAX IS INCORRECT

## Refactoring Guidelines
- Refactor for clarity, not just to reduce lines of code
- Avoid premature optimization; focus on clear, maintainable code first
- Use descriptive names for functions and variables to convey intent
- Break down large functions into smaller, reusable components
- For each refactor, make small incremental changes and test thoroughly

## Backwards Compatibility
- If a change breaks existing functionality, ask for confirmation before proceeding with backwards compatability changes
- This task runner is in development, so breaking changes are acceptable as long as they are communicated clearly
- Always ask for confirmation before making backwards compatibility changes

## Bug Fixing
- Focus on the root cause, not just symptoms
- Do not introduce new bugs while fixing existing ones
- Write tests for fixed bugs to prevent regressions
- If introducing a fix that changes the behavior of existing code, ask for confirmation before proceeding

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
- It is important that tasks are either explicitly retried or fail gracefully, there are specific points in which the task runner should fail, and continue, do not invent ways to ignore errors and continue
- Do not use delays or sleeps in the task runner, it should either fail or retry based on the task's readiness and state

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

## New Ideas
- If there is a completely new idea or approach, ask for confirmation before proceeding
- Provide a clear explanation of the benefits and trade-offs of the new approach
- Ensure that new ideas align with the overall project philosophy and standards

## Testing
- When fixing broken tests, focus on fixing the functional issue, not adjusting the tests unless they are incorrect
- Ensure that tests are written to cover the functionality, not just to pass
- Before adding new tests, ensure that the existing tests are passing and the syntax is correct, DO NOT CONTINUE IF SYNTAX IS INCORRECT
- The tests are run using Pester, so ensure that the tests are written in Pester syntax
  - Use `Describe`, `Context`, and `It` blocks to structure tests
    - Ensure the syntax is correct and the tests are passing before proceeding
    - `Context` should be on a new line
    - `Describe` should be on a new line
    - `It` should be on a new line
    - `BeforeEach` should be on a new line
    - `AfterEach` should be on a new line
  - Use `BeforeAll` and `AfterAll` for setup and teardown
  - Use `Mock` to mock dependencies where appropriate
  
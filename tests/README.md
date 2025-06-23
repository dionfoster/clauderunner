# Claude Task Runner Tests

This directory contains automated tests for the Claude Task Runner project using the Pester testing framework.

## Test Structure

The tests are organized to mirror the module structure of the project:

```
tests/
├── CommandExecution.Tests.ps1   # Tests for CommandExecution.psm1
├── Configuration.Tests.ps1      # Tests for Configuration.psm1
├── Logging.Tests.ps1            # Tests for Logging.psm1
├── ReadinessChecks.Tests.ps1    # Tests for ReadinessChecks.psm1
├── StateMachineVisualization.Tests.ps1  # Additional tests for state machine visualization
└── TestHelpers/                 # Common helper functions for tests
    └── TestEnvironment.ps1      # Test environment setup and teardown
```

## Running Tests

To run all tests:

```powershell
.\RunTests.ps1
```

To run tests for a specific module:

```powershell
.\RunTests.ps1 -TestName "*Logging*"
```

To run tests with code coverage:

```powershell
.\RunTests.ps1 -Coverage
```

## Test Helpers

The `TestHelpers/TestEnvironment.ps1` file provides common functions for test setup and teardown:

- `Initialize-TestEnvironment`: Sets up the test environment
- `Reset-LogFile`: Creates a new log file for tests
- `Cleanup-TestEnvironment`: Cleans up after tests
- `Reset-StateMachineVariables`: Resets state machine variables for testing
- `Test-LogContains`: Checks if a log file contains a specific pattern

## Current Test Coverage

- **Logging Module**: Basic logging functionality, log levels, state icons
- **State Machine Visualization**: Initial tests for state machine visualization

## Future Improvements

- Add more comprehensive tests for state machine visualization
- Add more tests for module integration
- Add tests for edge cases and error handling
- Add tests for the main `claude.ps1` script

## Testing Philosophy

The tests are designed to be:

1. **Independent**: Each test should run independently of others
2. **Fast**: Tests should run quickly to encourage frequent testing
3. **Reliable**: Tests should produce consistent results
4. **Clear**: Test failures should provide clear information about what went wrong
5. **Maintainable**: Tests should be easy to understand and update

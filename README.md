# Claude Task Runner

A PowerShell-based task orchestration tool for managing complex application startup dependencies with Docker, .NET, Node.js and other services.

## Overview

Claude Task Runner is a flexible dependency-based task orchestration system that allows you to:

- Define a sequence of states with dependencies
- Start applications in the correct order
- Wait for services to be ready before proceeding
- Launch applications in new windows or as background processes
- Perform pre-checks to skip already-running services

## Installation

1. Ensure you have PowerShell 5.1 or higher installed
2. Place `claude.ps1` and `claude.yml` in your project folder
3. Run `.\claude.ps1` to execute the default task

## Configuration

The task runner is configured through a YAML file (`claude.yml`) that defines states and their dependencies.

### Basic Structure

```yaml
states:
  stateName:
    readiness:
      checkCommand: command-to-check-readiness
      waitCommand: command-to-verify-readiness
    needs: [dependency1, dependency2]
    actions:
      - command1
      - command2
```

### Configuration Options

| Option | Description |
|--------|-------------|
| `readiness.checkCommand` | Command to execute to check if state is already ready |
| `readiness.waitCommand` | Command to poll to determine when state is fully ready |
| `readiness.errorPattern` | Custom regex pattern to detect errors in command output |
| `readiness.maxRetries` | Maximum number of retry attempts for wait polling (default: 10) |
| `readiness.retryInterval` | Time in seconds between retry attempts (default: 3) |
| `readiness.successfulRetries` | Number of consecutive successful checks required (default: 1) |
| `readiness.maxTimeSeconds` | Maximum total time in seconds for wait polling (default: 30) |
| `needs` | List of state dependencies that must be completed first |
| `actions` | List of commands or command objects to execute |

### Readiness Check Configuration

The task runner allows detailed configuration of how readiness checks are performed through several parameters in the `readiness` section.

#### Polling Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `maxRetries` | Maximum number of attempts | 10 |
| `retryInterval` | Seconds between attempts | 3 |
| `successfulRetries` | Required consecutive successes | 1 | 
| `maxTimeSeconds` | Total timeout in seconds | 30 |

#### When to Adjust Polling Parameters

- **Slow-starting services**: Increase `maxRetries`, `retryInterval`, and `maxTimeSeconds`
- **Unstable services**: Increase `successfulRetries` to ensure stability
- **Quick checks**: Decrease values for faster execution
- **Critical services**: Increase timeouts and retries for mission-critical components

#### Example

```yaml
databaseReady:
  readiness:
    checkCommand: Test-NetConnection -ComputerName localhost -Port 5432
    waitCommand: Test-NetConnection -ComputerName localhost -Port 5432
    maxRetries: 20
    retryInterval: 5
    successfulRetries: 3
    maxTimeSeconds: 120
```

This configuration:
- Checks PostgreSQL database connectivity
- Tries up to 20 times with 5 seconds between attempts
- Requires 3 consecutive successful connections
- Will wait up to 2 minutes total

### Command Types

Commands can be specified in several ways:

#### Simple PowerShell Command

```yaml
actions:
  - Get-Process
  - docker start postgres
```

#### Command with Options

```yaml
actions:
  - type: command
    command: dotnet run
    workingDirectory: "C:\path\to\project"
    description: "Starting API"
    newWindow: true
```

#### Application Launch

```yaml
actions:
  - type: application
    path: "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    description: "Starting Docker Desktop"
```

### Command Options

| Option | Description |
|--------|-------------|
| `type` | Type of action: "command" or "application" |
| `command` | The command to execute (for type: command) |
| `path` | Path to application executable to launch (for type: application) |
| `workingDirectory` | Working directory for the command (original directory is restored after execution) |
| `description` | Description of the command (for logs) |
| `newWindow` | When true, launches in a new window |
| `timeout` | Command timeout in seconds |

## Examples

### Docker Services

```yaml
dockerStartup:
  check: docker info
  run:
    - app: 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
      desc: "Starting Docker Desktop"
  waitFor: docker info

dockerReady:
  needs: [dockerStartup]
  check: docker info
  run:
    - docker start postgres
    - docker start rabbitmq
```

This example:
1. Checks if Docker is running with `docker info`
2. If not, launches Docker Desktop application
3. Waits for Docker to be ready by polling `docker info`
4. Once Docker is running, starts Postgres and RabbitMQ containers

### .NET Application

```yaml
apiReady:
  needs: [dockerReady]
  run:
    - command: dotnet run
      dir: "C:\github\Identity.Api\src\Identity.Api"
      window: true
      desc: "Starting Identity API"
```

This example:
1. Depends on `dockerReady` state completing successfully
2. Runs `dotnet run` in the specified directory
3. Launches the application in a new window
4. Displays "Starting Identity API" in the logs

### Node.js Application

```yaml
nodeReady:
  needs: [apiReady]
  run:
    - Set-NodeVersion -Version v22.16.0
    - command: npm install
      dir: "C:\github\Identity.Spa"
    - command: npm run dev
      dir: "C:\github\Identity.Spa"
      window: true
      desc: "Starting Identity SPA"
```

This example:
1. Sets the Node.js version
2. Runs `npm install` in the SPA directory
3. Runs `npm run dev` in a new window
4. Displays "Starting Identity SPA" in the logs

### Docker Services with Custom Error Detection and Polling

```yaml
dockerStartup:
  readiness:
    checkCommand: docker info
    waitCommand: docker info
    errorPattern: "(?i)cannot connect|is not running"
    maxRetries: 15
    retryInterval: 4
    successfulRetries: 2
    maxTimeSeconds: 60
  
  actions:
    - type: application
      path: 'C:\ Program Files\Docker\Docker\Docker Desktop.exe'
      description: "Starting Docker Desktop"
```

This example:
1. Checks if Docker is running with `docker info`
2. If not, launches Docker Desktop application
3. Waits for Docker to be ready by polling `docker info`
4. Uses a custom error pattern to detect specific Docker-related errors
5. Configures polling behavior with custom retry settings:
   - Up to 15 retry attempts
   - 4 seconds between each attempt
   - Requires 2 consecutive successful checks
   - Will wait up to 60 seconds total

## Custom Error Detection

The task runner supports custom error pattern detection through regex patterns. This allows you to specify exactly what should be considered an error in your command output.

### How Error Detection Works

1. By default, the runner looks for common error terms like "error", "failed", "not found", etc.

2. With custom error patterns, you can:
   - Target specific error messages relevant to your tools
   - Ignore false positives from standard error detection
   - Create more precise readiness checks

### Example

```yaml
apiReady:
  readiness:
    checkCommand: dotnet build
    errorPattern: "(?i)build failed|Could not find a part of the path|CS[0-9]{4}"
```

In this example, the error pattern will detect:
- "build failed" (case insensitive)
- "Could not find a part of the path" 
- Any C# compiler error codes (like CS0001)

### When to Use Custom Error Patterns

Use custom error patterns when:
- Your tools use unique error formats
- The default error detection is too broad
- You need to check for specific error conditions

## Usage

### Basic Usage

Run the default target (typically the last state in the chain):

```powershell
.\claude.ps1
```

### Run Specific Target

Run a specific target state and its dependencies:

```powershell
.\claude.ps1 -Target dockerReady
```

### Verbose Mode

Enable detailed logging:

```powershell
.\claude.ps1 -Verbose
```

## How It Works

1. **Dependency Resolution**: The runner starts with the target state and recursively processes all dependencies first.

2. **Pre-Checks**: Before running actions, the runner checks if a state is already ready using the `readiness.checkCommand`.

3. **Action Execution**: Commands are executed sequentially within each state.

4. **Wait Polling**: After actions complete, the runner can poll a command to ensure the state is fully ready with custom error detection and retry behavior.

5. **Status Tracking**: The runner keeps track of processed states to avoid duplication and detect circular dependencies.

## Window and Process Launching

The runner supports different ways to launch processes:

### Console (Default)

Commands run in the current console:

```yaml
run:
  - docker start postgres
```

### New Window

Commands run in a new window:

```yaml
run:
  - command: npm run dev
    window: true
```

### Application Launch

GUI applications launch via the Start command:

```yaml
run:
  - app: 'C:\ Program Files\Docker\Docker\Docker Desktop.exe'
```

## Working Directory Handling

When commands specify a working directory with the `dir` option, the task runner:

1. Saves the current working directory
2. Changes to the specified directory
3. Executes the command
4. Restores the original working directory

This ensures that each command runs in its specified directory without affecting subsequent commands, maintaining proper isolation between tasks.

## Troubleshooting

### Common Issues

- **Error "Unknown state"**: Check for typos in state names and dependencies
- **Docker commands failing**: Ensure Docker Desktop is running
- **Command timeout**: Increase timeout values for long-running commands
- **Path issues**: Use absolute paths and proper escaping in YAML

## Customizing the Runner

You can extend the task runner by:

1. Adding new state icon mappings in the `Get-StateIcon` function
2. Modifying error patterns in the `Test-OutputForErrors` function
3. Adding new command transformation methods in `Transform-CommandForLaunch`

### Debugging

Use the `-Verbose` flag to see detailed information about command execution and state transitions:

```powershell
.\claude.ps1 -Verbose
```

Check the `claude.log` file for a complete record of all operations.

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
    check: command-to-check-readiness
    needs: [dependency1, dependency2]
    run:
      - command1
      - command2
    waitFor: command-to-verify-readiness
```

### Configuration Options

| Option | Description |
|--------|-------------|
| `check` | Command to execute to check if state is already ready |
| `needs` | List of state dependencies that must be completed first |
| `run` | List of commands or command objects to execute |
| `waitFor` | Command to poll to determine when state is fully ready |

### Command Types

Commands can be specified in several ways:

#### Simple PowerShell Command

```yaml
run:
  - Get-Process
  - docker start postgres
```

#### Command with Options

```yaml
run:
  - command: dotnet run
    dir: "C:\path\to\project"
    desc: "Starting API"
    window: true
```

#### Application Launch

```yaml
run:
  - app: "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    desc: "Starting Docker Desktop"
```

### Command Options

| Option | Description |
|--------|-------------|
| `command` | The command to execute |
| `app` | Path to application executable to launch |
| `dir` | Working directory for the command |
| `desc` | Description of the command (for logs) |
| `window` | When true, launches in a new window |
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

2. **Pre-Checks**: Before running actions, the runner checks if a state is already ready using the `check` command.

3. **Action Execution**: Commands are executed sequentially within each state.

4. **Wait Polling**: After actions complete, the runner can poll a command to ensure the state is fully ready.

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
  - app: 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
```

## Customizing the Runner

You can extend the task runner by:

1. Adding new state icon mappings in the `Get-StateIcon` function
2. Modifying error patterns in the `Test-OutputForErrors` function
3. Adding new command transformation methods in `Transform-CommandForLaunch`

## Troubleshooting

### Common Issues

- **Error "Unknown state"**: Check for typos in state names and dependencies
- **Docker commands failing**: Ensure Docker Desktop is running
- **Command timeout**: Increase timeout values for long-running commands
- **Path issues**: Use absolute paths and proper escaping in YAML

### Debugging

Use the `-Verbose` flag to see detailed information about command execution and state transitions:

```powershell
.\claude.ps1 -Verbose
```

Check the `claude.log` file for a complete record of all operations.

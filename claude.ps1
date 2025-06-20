# claude.ps1 - Claude MCP-style task runner with continueAfter logic and launch methods
param(
    [ValidateNotNullOrEmpty()]
    [string]$Target = "apiReady",
    [switch]$Verbose
)

$ConfigPath = "claude.yml"
$LogPath = "claude.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $emoji = ""
    $color = "White"
    switch ($Level) {
        "INFO" { $color = "Gray"; $emoji = "ℹ️ " }
        "SUCCESS" { $color = "Green"; $emoji = "✅ " }
        "WARN" { $color = "Yellow"; $emoji = "⚠️ " }
        "ERROR" { $color = "Red"; $emoji = "❌ " }
        "DEBUG" { $color = "Cyan"; $emoji = "🔍 " }
    }
    $fullMessage = "$timestamp [$Level] - $emoji$Message"
    Write-Host $fullMessage -ForegroundColor $color
    $fullMessage | Out-File -FilePath $LogPath -Append -Encoding UTF8
}

function Write-StateLog {
    param([string]$StateName, [string]$Message, [string]$Level = "INFO")
    $icon = Get-StateIcon $StateName
    Write-Log ("{0}{1}" -f $icon, $Message) $Level
}

function Get-StateIcon {
    param([string]$StateName)
    switch ($StateName.ToLower()) {
        "dockerready" { return "🐳 " }
        "dockerstartup" { return "⚙️ " }
        "nodeready"   { return "🟢 " }
        "apiready"    { return "🚀 " }
        default       { return "⚙️ " }
    }
}

function Initialize-Environment {
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Log "Installing powershell-yaml module..." "INFO"
        try {
            Install-Module -Name powershell-yaml -Force -Scope CurrentUser -Repository PSGallery
            Write-Log "powershell-yaml module installed successfully." "SUCCESS"
        }
        catch {
            Write-Log "Failed to install powershell-yaml module: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }
    
    try {
        Import-Module powershell-yaml -ErrorAction Stop
    }
    catch {
        Write-Log "Failed to import powershell-yaml module: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

function Load-Configuration {
    if (-not (Test-Path $ConfigPath)) {
        Write-Log "Missing config file: $ConfigPath" "ERROR"
        Write-Log "Please create a claude.yml file with your state configuration." "INFO"
        exit 1
    }
    
    try {
        $yamlContent = Get-Content $ConfigPath -Raw -Encoding UTF8
        $config = ConvertFrom-Yaml $yamlContent
        Write-Log "Configuration loaded successfully from $ConfigPath" "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to parse YAML configuration: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

function Test-OutputForErrors {
    param(
        [string]$OutputString
    )
    
    $errorPatterns = @(
        "error", "not found", "unable", "fail", "failed",
        "no such file", "connection refused"
    )
    
    foreach ($pattern in $errorPatterns) {
        if ($OutputString -match "(?i)$pattern") {
            return $true
        }
    }
    return $false
}

function Get-ExecutableAndArgs {
    param([string]$Command)
    
    $split = $Command.IndexOf(' ')

    if ($split -eq -1) { 
        return $Command, ""
    }

    return $Command.Substring(0, $split), $Command.Substring($split + 1)
}

function Build-StartProcessCommand {
    param([string]$Executable, [string]$Arguments, [string]$WorkingDirectory, [string]$WindowStyle)
    
    $args = @("-FilePath `"$Executable`"")
    if ($Arguments) { $args += "-ArgumentList `"$Arguments`"" }
    if ($WorkingDirectory) { $args += "-WorkingDirectory `"$WorkingDirectory`"" }
    $args += "-WindowStyle $WindowStyle"
    
    return "Start-Process " + ($args -join " ")
}

function Transform-CommandForLaunch {
    param(
        [string]$Command,
        [string]$LaunchVia,
        [string]$WorkingDirectory
    )
    
    switch ($LaunchVia) {
        "windowsApp" {
            return @{
                Command = "start `"`" `"$Command`""
                CommandType = "cmd"
                PreserveWorkingDir = $false
            }
        }
        "newWindow" {
            $executable, $arguments = Get-ExecutableAndArgs -Command $Command
            return @{
                Command = Build-StartProcessCommand -Executable $executable -Arguments $arguments -WorkingDirectory $WorkingDirectory -WindowStyle "Normal"
                CommandType = "powershell"
                PreserveWorkingDir = $false
            }
        }
        default { # "console"
            if ($WorkingDirectory) {
                return @{
                    Command = "$Command"
                    CommandType = "powershell"
                    PreserveWorkingDir = $true
                    WorkingDirectory = $WorkingDirectory
                }
            } else {
                return @{
                    Command = $Command
                    CommandType = "powershell"
                    PreserveWorkingDir = $false
                }
            }
        }
    }
}

function Invoke-CommandWithTimeout {
    param(
        [string]$Command,
        [string]$CommandType,
        [int]$TimeoutSeconds,
        [string]$Icon,
        [bool]$PreserveWorkingDir = $false,
        [string]$WorkingDirectory = ""
    )
    
    # Save current location if we need to preserve it
    $originalLocation = $null
    if ($PreserveWorkingDir -and $WorkingDirectory) {
        $originalLocation = Get-Location
        Set-Location -Path $WorkingDirectory
    }
    
    try {
        if ($TimeoutSeconds -gt 0) {
            if ($Verbose) {
                Write-Log ("{0}Executing {1} command with timeout: {2}" -f $Icon, $CommandType.ToUpper(), $Command) "DEBUG"
            }
            
            if ($CommandType -eq "cmd") {
                $job = Start-Job -ScriptBlock { param($cmd) cmd /c $cmd } -ArgumentList $Command
            } else {
                $job = Start-Job -ScriptBlock { param($cmd) Invoke-Expression $cmd } -ArgumentList $Command
            }
            
            $completed = Wait-Job $job -Timeout $TimeoutSeconds
            
            if ($completed) {
                $output = Receive-Job $job
                $success = $job.State -eq "Completed"
                Remove-Job $job
                return @{ Success = $success; Output = $output }
            } else {
                Stop-Job $job
                Remove-Job $job
                return @{ Success = $false; Output = "Timeout after $TimeoutSeconds seconds" }
            }
        } else {
            if ($Verbose) {
                Write-Log ("{0}Executing {1} command: {2}" -f $Icon, $CommandType.ToUpper(), $Command) "DEBUG"
            }
            
            if ($CommandType -eq "cmd") {
                $output = cmd /c $Command 2>&1
                $success = $LASTEXITCODE -eq 0
            } else {
                $output = Invoke-Expression $Command 2>&1
                $success = $LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null
            }
            return @{ Success = $success; Output = $output }
        }
    }
    finally {
        # Always restore the original location if we changed it
        if ($originalLocation) {
            Set-Location -Path $originalLocation
        }
    }
}

function Invoke-Command {
    param(
        [string]$Command,
        [string]$Description,
        [string]$StateName,
        [string]$CommandType = "powershell",
        [string]$LaunchVia = "console",
        [string]$WorkingDirectory = "",
        [int]$TimeoutSeconds = 0
    )
    
    # Transform command based on launch method
    $transformedCommand = Transform-CommandForLaunch -Command $Command -LaunchVia $LaunchVia -WorkingDirectory $WorkingDirectory
    
    $timeoutText = if ($TimeoutSeconds -gt 0) { " (timeout: ${TimeoutSeconds}s)" } else { "" }
    Write-StateLog $StateName "$Description`: $Command$timeoutText" "INFO"
    
    try {
        # Execute command
        $icon = Get-StateIcon $StateName
        $result = Invoke-CommandWithTimeout -Command $transformedCommand.Command `
                                           -CommandType $transformedCommand.CommandType `
                                           -TimeoutSeconds $TimeoutSeconds `
                                           -Icon $icon `
                                           -PreserveWorkingDir $transformedCommand.PreserveWorkingDir `
                                           -WorkingDirectory $(if ($transformedCommand.PreserveWorkingDir) { $transformedCommand.WorkingDirectory } else { "" })
        
        # Check for success and error patterns in output
        if ($result.Success -and $result.Output) {
            $outputString = $result.Output | Out-String
            if (Test-OutputForErrors -OutputString $outputString) {
                Write-StateLog $StateName "✗ $Description completed but detected errors in output" "ERROR"
                if ($Verbose) {
                    Write-StateLog $StateName "Error output: $($outputString.Trim())" "DEBUG"
                }
                return $false
            }
        }
        
        if ($result.Success) {
            Write-StateLog $StateName "✓ $Description completed successfully" "SUCCESS"
            if ($Verbose -and $result.Output) {
                Write-StateLog $StateName "Output: $($result.Output)" "DEBUG"
            }
            return $true
        } else {
            $exitCode = if ($TimeoutSeconds -gt 0) { "TIMEOUT" } else { $LASTEXITCODE }
            Write-StateLog $StateName "✗ $Description failed (Exit Code: $exitCode)" "ERROR"
            if ($result.Output) {
                Write-StateLog $StateName "Error Output: $($result.Output)" "ERROR"
            }
            return $false
        }
    }
    catch {
        Write-StateLog $StateName "✗ $Description failed with exception: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-ContinueAfter {    param(
        [string]$Command,
        [string]$StateName,
        [int]$MaxRetries = 10,
        [int]$RetryInterval = 3,
        [int]$SuccessfulRetries = 1,
        [int]$MaxTimeSeconds = 30
    )
    
    $attempt = 0
    $successCount = 0
    $startTime = Get-Date
    
    Write-StateLog $StateName "Waiting for $StateName to be ready..." "INFO"
    Write-StateLog $StateName "Will retry up to $MaxRetries times (every ${RetryInterval}s), need $SuccessfulRetries successful checks, max ${MaxTimeSeconds}s total" "INFO"
    
    do {
        $attempt++
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        
        Write-StateLog $StateName "Attempt $attempt/$MaxRetries - checking $StateName status... (elapsed: ${elapsed}s)" "INFO"
        
        try {
            $output = Invoke-Expression $Command 2>&1 
            $success = $LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null
            
            if ($success) {
                $outputString = $output | Out-String
                  if (-not (Test-OutputForErrors -OutputString $outputString)) {
                    $successCount++
                    Write-StateLog $StateName "✓ Check passed ($successCount/$SuccessfulRetries successful checks)" "SUCCESS"
                    
                    if ($successCount -ge $SuccessfulRetries) {
                        Write-StateLog $StateName "✓ $StateName is ready! ($successCount successful checks in ${elapsed}s)" "SUCCESS"
                        return $true
                    }
                } else {
                    $successCount = 0  # Reset on error
                    Write-StateLog $StateName "⚠ Check detected errors, resetting success count" "WARN"
                    if ($Verbose) {
                        Write-StateLog $StateName "Error output: $($outputString.Trim())" "DEBUG"
                    }
                }
            } else {
                $successCount = 0  # Reset on failure
                Write-StateLog $StateName "✗ Check failed (Exit Code: $LASTEXITCODE)" "WARN"
                if ($Verbose -and $output) {
                    $outputString = $output | Out-String
                    Write-StateLog $StateName "Error details: $($outputString.Trim())" "DEBUG"
                }
            }
        }
        catch {
            $successCount = 0  # Reset on exception
            Write-StateLog $StateName "✗ Check exception: $($_.Exception.Message)" "WARN"
        }
        
        # Check if we have exceeded time limit
        if ($elapsed -ge $MaxTimeSeconds) {
            Write-StateLog $StateName "✗ $StateName failed to be ready within $MaxTimeSeconds seconds" "ERROR"
            return $false
        }
        
        # Check if we have exceeded retry limit
        if ($attempt -ge $MaxRetries) {
            Write-StateLog $StateName "✗ $StateName failed to be ready after $MaxRetries attempts" "ERROR"
            return $false
        }
        
        # Wait before next attempt
        if ($attempt -lt $MaxRetries -and $elapsed -lt $MaxTimeSeconds) {
            Write-StateLog $StateName "Waiting ${RetryInterval}s before next attempt..." "INFO"
            Start-Sleep $RetryInterval
        }
        
    } while ($true)
}

function Test-PreCheck {
    param(
        [string]$CheckCommand,
        [string]$StateName,
        [hashtable]$StateConfig
    )
    
    Write-StateLog $StateName "Checking if $StateName is already ready..." "INFO"
      try {
        if ($Verbose) {
            Write-StateLog $StateName "Check command: $CheckCommand" "DEBUG"
        }
        
        # Use try-catch instead of job for better exit code handling
        $output = $null
        $exitCode = $null
        
        try {
            # Execute command directly in the current process for better exit code handling
            $output = Invoke-Expression $CheckCommand 2>&1
            $exitCode = if ($LASTEXITCODE -ne $null) { $LASTEXITCODE } else { 0 }
        }
        catch {
            $output = $_.Exception.Message
            $exitCode = 1
        }
        
        $success = $exitCode -eq 0
        $outputString = $output | Out-String
        
        if ($success -and -not (Test-OutputForErrors -OutputString $outputString)) {
            Write-StateLog $StateName "✓ State $StateName is already ready, skipping actions" "SUCCESS"
            if ($Verbose) {
                $lines = ($outputString -split "`n").Count
                Write-StateLog $StateName "Check returned $lines lines of output (success)" "DEBUG"
            }
            return $true
        } else {
            if ($Verbose) {
                if (-not $success) {
                    Write-StateLog $StateName "Check failed (Exit Code: $exitCode)" "DEBUG"
                } else {
                    Write-StateLog $StateName "Check completed but output contains errors" "DEBUG"
                }
            }
        }
    }
    catch {
        if ($Verbose) {
            Write-StateLog $StateName "Check failed with exception: $($_.Exception.Message)" "DEBUG"
        }
    }
    
    Write-StateLog $StateName "Pre-check failed or detected issues, proceeding with actions" "INFO"
    return $false
}

function Test-StateConfiguration {
    param([hashtable]$StateConfig, [string]$StateName)
    
    if (-not $StateConfig.actions -and -not ($StateConfig.readiness -and $StateConfig.readiness.waitCommand)) {
        throw "State '$StateName' has no actions or wait command defined"
    }
    
    if ($StateConfig.actions) {
        foreach ($action in $StateConfig.actions) {
            if ($action -is [string]) { continue }
            if (-not ($action.type -eq "command" -or $action.type -eq "application")) {
                throw "Invalid action in state '$StateName': must have type 'command' or 'application'"
            }
            if ($action.type -eq "command" -and -not $action.command) {
                throw "Invalid command action in state '$StateName': missing 'command' property"
            }
            if ($action.type -eq "application" -and -not $action.path) {
                throw "Invalid application action in state '$StateName': missing 'path' property"
            }
        }
    }
}

function Invoke-State {
    param(
        [string]$StateName,
        [hashtable]$Config,
        [System.Collections.Generic.HashSet[string]]$ProcessedStates
    )

    # Avoid infinite loops
    if ($ProcessedStates.Contains($StateName)) {
        Write-StateLog $StateName "State $StateName already processed in this run" "DEBUG"
        return $true
    }
    
    # Get state configuration - only using 'states' root key
    $stateConfig = $null
    if ($Config.states -and $Config.states.$StateName) {
        $stateConfig = $Config.states.$StateName
    }
    if (-not $stateConfig) {
        Write-StateLog $StateName "Unknown state: $StateName" "ERROR"
        return $false
    }
    
    # Validate configuration
    try {
        Test-StateConfiguration -StateConfig $stateConfig -StateName $StateName
    }
    catch {
        Write-StateLog $StateName "Configuration error: $($_.Exception.Message)" "ERROR"
        return $false
    }
    
    Write-StateLog $StateName "Processing state: $StateName" "INFO"
    
    # Handle dependencies first
    if ($stateConfig.needs) {
        $depList = $stateConfig.needs -join ', '
        Write-StateLog $StateName "Resolving dependencies for $StateName`: $depList" "INFO"
        foreach ($dependency in $stateConfig.needs) {
            if (-not (Invoke-State -StateName $dependency -Config $Config -ProcessedStates $ProcessedStates)) {
                Write-StateLog $StateName "Dependency $dependency failed for state $StateName" "ERROR"
                return $false
            }
        }
    }
    
    # Perform pre-check if defined
    if ($stateConfig.readiness -and $stateConfig.readiness.checkCommand) {
        if (Test-PreCheck -CheckCommand $stateConfig.readiness.checkCommand -StateName $StateName -StateConfig $stateConfig) {
            $ProcessedStates.Add($StateName) | Out-Null
            return $true
        }
    }
    
    # Execute actions
    if ($stateConfig.actions) {
        Write-StateLog $StateName "Executing actions for $StateName" "INFO"
        
        foreach ($action in $stateConfig.actions) {
            $params = @{
                Command = ""
                Description = "Execute command"
                StateName = $StateName
                CommandType = "powershell"
                TimeoutSeconds = 0
                LaunchVia = "console"
                WorkingDirectory = ""
            }
            
            if ($action -is [string]) {
                # Simple string command - default to PowerShell
                $params.Command = $action
            } elseif ($action.type -eq "command") {
                # Command type action
                $params.Command = $action.command
            } elseif ($action.type -eq "application") {
                # Application launch type action
                $params.Command = $action.path
                $params.LaunchVia = "windowsApp"
            } else {
                Write-StateLog $StateName "Invalid action format in state $StateName" "ERROR"
                continue
            }
            
            # Extract optional properties
            if ($action.timeout) { $params.TimeoutSeconds = $action.timeout }
            if ($action.description) { $params.Description = $action.description }
            if ($action.workingDirectory) { $params.WorkingDirectory = $action.workingDirectory }
            if ($action.newWindow) { $params.LaunchVia = "newWindow" }
            
            if (-not (Invoke-Command @params)) {
                Write-StateLog $StateName "Action failed in state $StateName" "ERROR"
                return $false
            }
        }
    }
    
    # Handle wait polling if defined
    if ($stateConfig.readiness -and $stateConfig.readiness.waitCommand) {
        $command = $stateConfig.readiness.waitCommand
          # Use smart defaults for polling
        $maxRetries = 10
        $retryInterval = 3  
        $successfulRetries = 1
        $maxTimeSeconds = 30
        
        # Override with custom values if provided
        if ($stateConfig.readiness.maxRetries) { $maxRetries = $stateConfig.readiness.maxRetries }
        if ($stateConfig.readiness.retryInterval) { $retryInterval = $stateConfig.readiness.retryInterval }
        if ($stateConfig.readiness.successfulRetries) { $successfulRetries = $stateConfig.readiness.successfulRetries }
        if ($stateConfig.readiness.maxTimeSeconds) { $maxTimeSeconds = $stateConfig.readiness.maxTimeSeconds }
        
        if (-not (Test-ContinueAfter -Command $command -StateName $StateName -MaxRetries $maxRetries -RetryInterval $retryInterval -SuccessfulRetries $successfulRetries -MaxTimeSeconds $maxTimeSeconds)) {
            Write-StateLog $StateName "State $StateName failed to become ready" "ERROR"
            return $false
        }
    }
    
    # Mark state as processed for this run
    $ProcessedStates.Add($StateName) | Out-Null
    Write-StateLog $StateName "State $StateName completed successfully" "SUCCESS"
    return $true
}

# Main execution
try {
    Write-Log "Starting Claude MCP-style Task Runner" "INFO"
    Write-Log "Target state: $Target" "INFO"
    
    Initialize-Environment
    $config = Load-Configuration
    
    # Track processed states for this run only
    $processedStates = New-Object System.Collections.Generic.HashSet[string]
    
    $success = Invoke-State -StateName $Target -Config $config -ProcessedStates $processedStates
    
    # Show summary of what was processed
    Write-Log "=== Run Summary ===" "INFO"
    if ($processedStates.Count -gt 0) {
        foreach ($stateName in $processedStates | Sort-Object) {
            $icon = Get-StateIcon $stateName
            Write-Host ("{0}{1}: ✅ PROCESSED" -f $icon, $stateName) -ForegroundColor "Green"
        }
    } else {
        Write-Host "No states were processed (all checks passed)" -ForegroundColor "Yellow"
    }
    
    if ($success) {
        Write-Log "🎉 Task runner completed successfully!" "SUCCESS"
        exit 0
    } else {
        Write-Log "❌ Task runner failed" "ERROR"
        exit 1
    }
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}

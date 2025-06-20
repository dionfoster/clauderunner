# CommandExecution.psm1 - Claude Task Runner command execution functions

<#
.SYNOPSIS
Tests if a command output string contains error patterns.

.DESCRIPTION
Checks if a command output string contains common error patterns like "error", "not found", etc.

.PARAMETER OutputString
The output string to check for error patterns.

.OUTPUTS
Returns $true if error patterns are found, $false otherwise.
#>
function Test-OutputForErrors {
    param(
        [Parameter(Mandatory=$true)]
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

<#
.SYNOPSIS
Splits a command string into executable and arguments.

.DESCRIPTION
Takes a command string and splits it at the first space into executable and arguments.

.PARAMETER Command
The command string to split.

.OUTPUTS
Returns a tuple containing the executable and arguments.
#>
function Get-ExecutableAndArgs {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    $split = $Command.IndexOf(' ')

    if ($split -eq -1) { 
        return $Command, ""
    }

    return $Command.Substring(0, $split), $Command.Substring($split + 1)
}

<#
.SYNOPSIS
Builds a Start-Process command string.

.DESCRIPTION
Creates a PowerShell Start-Process command string with the given executable, arguments, working directory, and window style.

.PARAMETER Executable
The executable to run.

.PARAMETER Arguments
The arguments to pass to the executable.

.PARAMETER WorkingDirectory
The working directory to run the command in.

.PARAMETER WindowStyle
The window style to use (Normal, Minimized, Maximized, Hidden).

.OUTPUTS
Returns a string containing the Start-Process command.
#>
function Build-StartProcessCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Executable, 
        
        [Parameter(Mandatory=$false)]
        [string]$Arguments, 
        
        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory, 
        
        [Parameter(Mandatory=$true)]
        [string]$WindowStyle
    )
    
    $cmdArgs = @("-FilePath `"$Executable`"")
    if ($Arguments) { $cmdArgs += "-ArgumentList `"$Arguments`"" }
    if ($WorkingDirectory) { $cmdArgs += "-WorkingDirectory `"$WorkingDirectory`"" }
    $cmdArgs += "-WindowStyle $WindowStyle"
    
    return "Start-Process " + ($cmdArgs -join " ")
}

<#
.SYNOPSIS
Transforms a command for different launch methods.

.DESCRIPTION
Transforms a command based on the launch method (console, windowsApp, newWindow).

.PARAMETER Command
The command to transform.

.PARAMETER LaunchVia
The launch method to use (console, windowsApp, newWindow).

.PARAMETER WorkingDirectory
The working directory to run the command in.

.OUTPUTS
Returns a hashtable containing the transformed command and related properties.
#>
function ConvertTo-LaunchCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("console", "windowsApp", "newWindow")]
        [string]$LaunchVia = "console",
        
        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = ""
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

<#
.SYNOPSIS
Executes a command with an optional timeout.

.DESCRIPTION
Executes a PowerShell or CMD command with an optional timeout. Returns success status and output.

.PARAMETER Command
The command to execute.

.PARAMETER CommandType
The type of command (powershell or cmd).

.PARAMETER TimeoutSeconds
The timeout in seconds. If 0, no timeout is applied.

.PARAMETER Icon
The icon to display in log messages.

.PARAMETER PreserveWorkingDir
Whether to preserve the working directory.

.PARAMETER WorkingDirectory
The working directory to run the command in.

.OUTPUTS
Returns a hashtable containing the success status and output.
#>
function Invoke-CommandWithTimeout {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("powershell", "cmd")]
        [string]$CommandType,
        
        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 0,
        
        [Parameter(Mandatory=$false)]
        [string]$Icon = "",
        
        [Parameter(Mandatory=$false)]
        [bool]$PreserveWorkingDir = $false,
        
        [Parameter(Mandatory=$false)]
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
            if ($global:Verbose) {
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
            if ($global:Verbose) {
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

<#
.SYNOPSIS
Invokes a command with logging and error handling.

.DESCRIPTION
Invokes a command with proper logging, error handling, and output checking.

.PARAMETER Command
The command to execute.

.PARAMETER Description
A description of the command for logging.

.PARAMETER StateName
The name of the state for logging.

.PARAMETER CommandType
The type of command (powershell or cmd).

.PARAMETER LaunchVia
The launch method to use (console, windowsApp, newWindow).

.PARAMETER WorkingDirectory
The working directory to run the command in.

.PARAMETER TimeoutSeconds
The timeout in seconds. If 0, no timeout is applied.

.OUTPUTS
Returns $true if the command succeeded, $false otherwise.
#>
function Invoke-Command {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$true)]
        [string]$Description,
        
        [Parameter(Mandatory=$true)]
        [string]$StateName,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("powershell", "cmd")]
        [string]$CommandType = "powershell",
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("console", "windowsApp", "newWindow")]
        [string]$LaunchVia = "console",
        
        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = "",
        
        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 0
    )
      # Transform command based on launch method
    $transformedCommand = ConvertTo-LaunchCommand -Command $Command -LaunchVia $LaunchVia -WorkingDirectory $WorkingDirectory
    
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
                if ($global:Verbose) {
                    Write-StateLog $StateName "Error output: $($outputString.Trim())" "DEBUG"
                }
                return $false
            }
        }
        
        if ($result.Success) {
            Write-StateLog $StateName "✓ $Description completed successfully" "SUCCESS"
            if ($global:Verbose -and $result.Output) {
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

# Export the functions
Export-ModuleMember -Function Test-OutputForErrors, Get-ExecutableAndArgs, Build-StartProcessCommand, ConvertTo-LaunchCommand, Invoke-CommandWithTimeout, Invoke-Command

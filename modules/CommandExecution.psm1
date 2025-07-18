# CommandExecution.psm1 - Claude Task Runner command execution functions

# Import required modules
Import-Module "$PSScriptRoot\StateVisualization.psm1"

# No wrapper functions to avoid infinite recursion

<#
.SYNOPSIS
Command Execution Module for Claude Task Runner

.DESCRIPTION
This module provides functions for executing commands in various ways with proper error handling.

.NOTES
To add support for additional command aliases, extend the $script:CommandAliases hashtable at the top of this file.
Example:
$script:CommandAliases = @{
    "npm" = {param($cmdArgs) & npm $cmdArgs}
    "newcommand" = {param($cmdArgs) & newcommand $cmdArgs}
}
#>

# Script-level command alias mapping
$script:CommandAliases = @{
    "npm" = "npm"
    "yarn" = "yarn"
    "pnpm" = "pnpm"
    "node" = "node"
    "Set-NodeVersion" = "Set-NodeVersion"
}

<#
.SYNOPSIS
Resolves command aliases to proper executable commands.

.DESCRIPTION
Takes a command string and checks if the first word matches a known command alias.
If a match is found, it transforms the command to use the appropriate execution method.

.PARAMETER Command
The command string to resolve.

.OUTPUTS
Returns the resolved command string.
#>
function Resolve-CommandAlias {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    # Normal command alias handling
    $cmdParts = $Command -split ' ', 2
    $cmdName = $cmdParts[0]
    $cmdArgs = if ($cmdParts.Length -gt 1) { $cmdParts[1] } else { "" }
    
    if ($script:CommandAliases.ContainsKey($cmdName)) {
        # Just use the direct command - simpler and more reliable
        return "$($script:CommandAliases[$cmdName]) $cmdArgs"
    }
    
    return $Command
}

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
        }        "newWindow" {
            $executable, $arguments = Get-ExecutableAndArgs -Command $Command
            
            # Special handling for npm/node commands when launched in a new window
            if ($executable -eq "npm" -or $executable -eq "node") {
                return @{
                    Command = "Start-Process pwsh -ArgumentList '-NoExit','-Command',`"cd '$WorkingDirectory'; $Command`"" 
                    CommandType = "powershell"
                    PreserveWorkingDir = $false
                }
            }
            
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
        [string]$WorkingDirectory = "",
        
        [Parameter(Mandatory=$false)]
        [string]$StateName = ""
    )
    
    # For commands that need working directory, handle them via jobs or Start-Process
    # Never change the PowerShell session's current directory
    
    try {
        if ($TimeoutSeconds -gt 0) {
            if ($CommandType -eq "cmd") {
                $job = Start-Job -ScriptBlock { param($cmd, $workDir) 
                    if ($workDir) {
                        $output = cmd /c "cd /d `"$workDir`" && $cmd" 2>&1
                    } else {
                        $output = cmd /c $cmd 2>&1
                    }
                    return @{ ExitCode = $LASTEXITCODE; Output = $output }
                } -ArgumentList $Command, $WorkingDirectory
            } else {
                $job = Start-Job -ScriptBlock { param($cmd, $workDir) 
                    if ($workDir) {
                        Set-Location -Path $workDir
                    }
                    # Special handling for exit commands in jobs
                    if ($cmd -match "^\s*exit\s+(\d+)\s*$") {
                        $exitCode = [int]$($cmd -replace "^\s*exit\s+", "")
                        return @{ ExitCode = $exitCode; Output = "" }
                    } else {
                        try {
                            $output = Invoke-Expression $cmd 2>&1
                            # For PowerShell, success is determined by no exceptions, not LASTEXITCODE
                            return @{ ExitCode = 0; Output = $output }
                        } catch {
                            return @{ ExitCode = 1; Output = $_.Exception.Message }
                        }
                    }
                } -ArgumentList $Command, $WorkingDirectory
            }
            
            $completed = Wait-Job $job -Timeout $TimeoutSeconds
            
            if ($completed) {
                $jobResult = Receive-Job $job
                $output = if ($jobResult -is [hashtable]) { $jobResult.Output } else { $jobResult }
                $exitCode = if ($jobResult -is [hashtable]) { $jobResult.ExitCode } else { 0 }
                $success = $exitCode -eq 0
                Remove-Job $job
                return @{ Success = $success; Output = $output }
            } else {
                Stop-Job $job
                Remove-Job $job
                return @{ Success = $false; Output = "Timeout after $TimeoutSeconds seconds" }
            }
        } else {
            # For non-timeout scenarios, handle directly but with special cases
            if ($CommandType -eq "cmd") {
                if ($WorkingDirectory) {
                    $output = cmd /c "cd /d `"$WorkingDirectory`" && $Command" 2>&1
                } else {
                    $output = cmd /c $Command 2>&1
                }
                $success = $LASTEXITCODE -eq 0
            } else {
                # Special handling for exit commands
                if ($Command -match "^\s*exit\s+(\d+)\s*$") {
                    $exitCode = [int]$Matches[1]
                    $output = ""
                    $success = $exitCode -eq 0
                } else {
                    try {
                        # Handle working directory for PowerShell commands
                        if ($WorkingDirectory) {
                            $originalLocation = Get-Location
                            try {
                                Set-Location -Path $WorkingDirectory
                                $output = Invoke-Expression $Command 2>&1
                            } finally {
                                Set-Location -Path $originalLocation
                            }
                        } else {
                            $output = Invoke-Expression $Command 2>&1
                        }
                        # For PowerShell, success is determined by no exceptions, not LASTEXITCODE
                        $success = $true
                    } catch {
                        $output = $_.Exception.Message
                        $success = $false
                    }
                }
            }
            return @{ Success = $success; Output = $output }
        }
    }
    finally {
        # No need to restore location since we never change it
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
    
    # Resolve any command aliases
    $resolvedCommand = Resolve-CommandAlias -Command $Command
    
    # Transform command based on launch method
    $transformedCommand = ConvertTo-LaunchCommand -Command $resolvedCommand -LaunchVia $LaunchVia -WorkingDirectory $WorkingDirectory
    
    # Override CommandType based on launch method requirements
    # windowsApp always uses cmd, newWindow always uses powershell
    # console preserves the explicitly passed CommandType
    if ($LaunchVia -eq "windowsApp") {
        $CommandType = "cmd"
    } elseif ($LaunchVia -eq "newWindow") {
        $CommandType = "powershell"
    }
    # For console launch, preserve the explicitly passed CommandType
    
    try {
        # Execute command
        $icon = "⏳"  # Use direct icon instead of calling function
        $result = Invoke-CommandWithTimeout -Command $transformedCommand.Command `
                                           -CommandType $CommandType `
                                           -TimeoutSeconds $TimeoutSeconds `
                                           -Icon $icon `
                                           -PreserveWorkingDir $transformedCommand.PreserveWorkingDir `
                                           -WorkingDirectory $(if ($transformedCommand.PreserveWorkingDir) { $transformedCommand.WorkingDirectory } else { "" }) `
                                           -StateName $StateName
        
        # Check for success and error patterns in output
        if ($result.Success -and $result.Output) {
            $outputString = $result.Output | Out-String
            if (Test-OutputForErrors -OutputString $outputString) {
                return $false
            }
        }
        
        return $result.Success
    }
    catch {
        Write-Host "✗ $Description failed with exception: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

<#
.SYNOPSIS
Executes a Docker command and returns the output.

.DESCRIPTION
Executes a Docker command and returns the output. Throws an exception if the command fails.

.PARAMETER Command
The Docker command to execute, without the 'docker' prefix.

.OUTPUTS
Returns the output of the Docker command.

.EXAMPLE
Invoke-DockerCommand -Command "ps"
#>

# Export the functions
Export-ModuleMember -Function Test-OutputForErrors, Get-ExecutableAndArgs, Build-StartProcessCommand, ConvertTo-LaunchCommand, Invoke-CommandWithTimeout, Invoke-Command, Resolve-CommandAlias

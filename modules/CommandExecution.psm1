# CommandExecution.psm1 - Claude Task Runner command execution functions

# Access to state machine logging functions
# These are imported by the main script
function Start-StateTransitions { if (Get-Command Start-StateTransitions -ErrorAction SilentlyContinue) { Start-StateTransitions @args } }
function Start-StateProcessing { if (Get-Command Start-StateProcessing -ErrorAction SilentlyContinue) { Start-StateProcessing @args } }
function Write-StateCheck { if (Get-Command Write-StateCheck -ErrorAction SilentlyContinue) { Write-StateCheck @args } }
function Write-StateCheckResult { if (Get-Command Write-StateCheckResult -ErrorAction SilentlyContinue) { Write-StateCheckResult @args } }
function Start-StateActions { if (Get-Command Start-StateActions -ErrorAction SilentlyContinue) { Start-StateActions @args } }
function Start-StateAction { if (Get-Command Start-StateAction -ErrorAction SilentlyContinue) { Start-StateAction @args } }
function Complete-StateAction { if (Get-Command Complete-StateAction -ErrorAction SilentlyContinue) { Complete-StateAction @args } }
function Complete-State { if (Get-Command Complete-State -ErrorAction SilentlyContinue) { Complete-State @args } }
function Write-StateSummary { if (Get-Command Write-StateSummary -ErrorAction SilentlyContinue) { Write-StateSummary @args } }

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
    
    # Save current location if we need to preserve it
    $originalLocation = $null
    if ($PreserveWorkingDir -and $WorkingDirectory) {
        $originalLocation = Get-Location
        Set-Location -Path $WorkingDirectory
    }
    
    try {
        if ($TimeoutSeconds -gt 0) {
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
    
    # Resolve any command aliases
    $resolvedCommand = Resolve-CommandAlias -Command $Command
    
    # Transform command based on launch method
    $transformedCommand = ConvertTo-LaunchCommand -Command $resolvedCommand -LaunchVia $LaunchVia -WorkingDirectory $WorkingDirectory
    
    try {
        # Execute command
        $icon = Get-StateIcon $StateName
        $result = Invoke-CommandWithTimeout -Command $transformedCommand.Command `
                                           -CommandType $transformedCommand.CommandType `
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

# Export the functions
Export-ModuleMember -Function Test-OutputForErrors, Get-ExecutableAndArgs, Build-StartProcessCommand, ConvertTo-LaunchCommand, Invoke-CommandWithTimeout, Invoke-Command, Resolve-CommandAlias

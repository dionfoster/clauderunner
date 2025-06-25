# Logging.psm1 - Claude Task Runner logging functions

# Import dependencies
Import-Module "$PSScriptRoot\StateManagement.psm1"

# Module-level variables
$script:LogPath = "claude.log"

<#
.SYNOPSIS
Writes a log message to both the console and the log file.

.DESCRIPTION
Writes a log message with timestamp and appropriate emoji to both the console and the log file.

.PARAMETER Message
The message to be logged.

.PARAMETER Level
The log level (INFO, SUCCESS, WARN, ERROR, DEBUG, SYSTEM). Default is INFO.
#>
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message, 
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG", "SYSTEM")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $emoji = ""
    $color = "White"
    
    switch ($Level) {
        "INFO" { 
            $emoji = "ℹ️"
            $color = "White"
        }
        "SUCCESS" { 
            $emoji = "✅"
            $color = "Green"
        }
        "WARN" { 
            $emoji = "⚠️"
            $color = "Yellow"
        }
        "ERROR" { 
            $emoji = "❌"
            $color = "Red"
        }
        "DEBUG" { 
            $emoji = "🔍"
            $color = "Gray"
        }
        "SYSTEM" {
            $emoji = ""  # No emoji prefix for system messages
            $color = "Cyan"
        }
    }
    
    if ($emoji -eq "") {
        Write-Host "$Message" -ForegroundColor $color
        $logMessage = "[$timestamp] [$Level] $Message"
    } else {
        Write-Host "$emoji │  $Message" -ForegroundColor $color
        $logMessage = "[$timestamp] [$Level] $emoji │  $Message"
    }
    
    # Log with timestamp to file
    $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
}

<#
.SYNOPSIS
Sets the path for the log file.

.DESCRIPTION
Updates the path where log messages will be written.

.PARAMETER Path
The new path for the log file.
#>
function Set-LogPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $script:LogPath = $Path
}

# Export module members
Export-ModuleMember -Function Write-Log, Set-LogPath
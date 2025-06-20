# Logging.psm1 - Claude Task Runner logging functions

# Module-level variable to store log path
$script:LogPath = "claude.log"

# Function to set the log path from the main script
function Set-LogPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $script:LogPath = $Path
}

<#
.SYNOPSIS
Writes a log message to both the console and the log file.

.DESCRIPTION
Writes a log message with timestamp and appropriate emoji to both the console and the log file.

.PARAMETER Message
The message to be logged.

.PARAMETER Level
The log level (INFO, SUCCESS, WARN, ERROR, DEBUG). Default is INFO.
#>
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message, 
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    
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
    
    # Use module-level variable for log path
    $fullMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
}

<#
.SYNOPSIS
Writes a state-specific log message with the appropriate state icon.

.DESCRIPTION
Writes a log message with the state icon prefixed to the message.

.PARAMETER StateName
The name of the state for which to log the message.

.PARAMETER Message
The message to be logged.

.PARAMETER Level
The log level (INFO, SUCCESS, WARN, ERROR, DEBUG). Default is INFO.
#>
function Write-StateLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StateName, 
        
        [Parameter(Mandatory=$true)]
        [string]$Message, 
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $icon = Get-StateIcon $StateName
    Write-Log ("{0}{1}" -f $icon, $Message) $Level
}

<#
.SYNOPSIS
Gets the appropriate icon for a state.

.DESCRIPTION
Returns an emoji icon representing the given state.

.PARAMETER StateName
The name of the state for which to get the icon.

.OUTPUTS
A string containing the emoji icon for the state.
#>
function Get-StateIcon {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StateName
    )
    
    switch ($StateName.ToLower()) {
        "dockerready" { return "🐳 " }
        "dockerstartup" { return "⚙️ " }
        "nodeready"   { return "🟢 " }
        "apiready"    { return "🚀 " }
        default       { return "⚙️ " }
    }
}

# Export the functions
Export-ModuleMember -Function Write-Log, Write-StateLog, Get-StateIcon, Set-LogPath

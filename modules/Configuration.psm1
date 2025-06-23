# Configuration.psm1 - Claude Task Runner configuration functions

# Module-level variable to store config path
$script:ConfigPath = "claude.yml"

# Function to set the config path from the main script
function Set-ConfigPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $script:ConfigPath = $Path
}

<#
.SYNOPSIS
Initializes the environment by ensuring the required PowerShell modules are installed.

.DESCRIPTION
Checks if the powershell-yaml module is installed and installs it if necessary.
Then imports the module to ensure it's available for use.
#>
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

<#
.SYNOPSIS
Loads the YAML configuration file.

.DESCRIPTION
Loads and parses the YAML configuration file specified in $ConfigPath.

.OUTPUTS
A hashtable containing the parsed YAML configuration.
#>
function Get-Configuration {
    if (-not (Test-Path $script:ConfigPath)) {
        Write-Log "Missing config file: $script:ConfigPath" "ERROR"
        Write-Log "Please create a claude.yml file with your state configuration." "INFO"
        return $null
    }
      try {
        $yamlContent = Get-Content $script:ConfigPath -Raw -Encoding UTF8
        $config = ConvertFrom-Yaml $yamlContent
        return $config
    }
    catch {
        Write-Log "Failed to parse YAML configuration: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

<#
.SYNOPSIS
Validates a state configuration.

.DESCRIPTION
Checks that a state configuration is valid, with the required properties.

.PARAMETER StateConfig
The state configuration to validate.

.PARAMETER StateName
The name of the state.

.THROWS
Throws an exception if the state configuration is invalid.
#>
function Test-StateConfiguration {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$StateConfig, 
        
        [Parameter(Mandatory=$true)]
        [string]$StateName
    )
    
    # Handle both classic and endpoint-based configurations
    $hasValidReadiness = $false
    
    if ($StateConfig.readiness) {
        if ($StateConfig.readiness.checkEndpoint -or $StateConfig.readiness.waitEndpoint) {
            $hasValidReadiness = $true
        } elseif ($StateConfig.readiness.checkCommand) {
            $hasValidReadiness = $true
        }
    }
    
    if (-not $StateConfig.actions -and -not $hasValidReadiness) {
        throw "State '$StateName' has no actions or valid readiness check defined"
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

# Export the functions
Export-ModuleMember -Function Initialize-Environment, Get-Configuration, Test-StateConfiguration, Set-ConfigPath

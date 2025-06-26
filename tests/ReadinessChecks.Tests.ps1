# Pester tests for ReadinessChecks module
BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    $env = Initialize-StandardTestEnvironment -ModulesToImport @("ReadinessChecks") -TestLogPath $script:TestLogPath
    
    # Create mock for Invoke-WebRequest
    Mock -ModuleName ReadinessChecks Invoke-WebRequest {
        param($Uri, $Method, $TimeoutSec)
        
        if ($Uri -like "*/readiness") {
            return @{
                StatusCode = 200
                Content = '{"status":"ready"}'
            }
        }
        
        if ($Uri -like "*/health") {
            return @{
                StatusCode = 200
                Content = '{"status":"healthy"}'
            }
        }
        
        # Default fallback
        throw "Connection failed"
    }
}

Describe "ReadinessChecks Module" {
    BeforeEach {
        # Use standardized BeforeEach setup
        Reset-TestLogFile -TestLogPath $script:TestLogPath
    }
    
}

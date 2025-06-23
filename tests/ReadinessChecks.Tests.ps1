# Pester tests for ReadinessChecks module
BeforeAll {
    # Import the TestEnvironment helper
    . "$PSScriptRoot\TestHelpers\TestEnvironment.ps1"
    
    # Set up test environment
    Initialize-TestEnvironment
    
    # Import the module to test
    Import-Module "$PSScriptRoot\..\modules\ReadinessChecks.psm1" -Force
    
    # Mock dependencies
    function global:Mock-CommandExists {
        param([string]$command)
        return $true # Always return true in tests
    }
    
    # Create mock for Invoke-WebRequest
    Mock Invoke-WebRequest {
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

AfterAll {
    # Clean up test environment
    Cleanup-TestEnvironment
    
    # Remove mock
    Remove-Item -Path function:global:Mock-CommandExists -ErrorAction SilentlyContinue
}

Describe "ReadinessChecks Module" {
    Context "Test-DockerInstalled" {
        It "Returns true when Docker is installed (mocked)" {
            # Arrange
            Mock Get-Command { return $true } -ParameterFilter { $Name -eq "docker" }
            
            # Act
            $result = Test-DockerInstalled
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Returns false when Docker is not installed" {
            # Arrange
            Mock Get-Command { throw "Command not found" } -ParameterFilter { $Name -eq "docker" }
            
            # Act
            $result = Test-DockerInstalled
            
            # Assert
            $result | Should -BeFalse
        }
    }
    
    Context "Test-DockerRunning" {
        It "Returns true when Docker is running (mocked)" {
            # Arrange
            Mock docker { return "Docker is running" } -ParameterFilter { $args -contains "info" }
            
            # Act
            $result = Test-DockerRunning
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Returns false when Docker is not running" {
            # Arrange
            Mock docker { throw "Docker is not running" } -ParameterFilter { $args -contains "info" }
            
            # Act
            $result = Test-DockerRunning
            
            # Assert
            $result | Should -BeFalse
        }
    }
    
    Context "Test-NodeJSInstalled" {
        It "Returns true when Node.js is installed (mocked)" {
            # Arrange
            Mock Get-Command { return $true } -ParameterFilter { $Name -eq "node" }
            
            # Act
            $result = Test-NodeJSInstalled
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Returns false when Node.js is not installed" {
            # Arrange
            Mock Get-Command { throw "Command not found" } -ParameterFilter { $Name -eq "node" }
            
            # Act
            $result = Test-NodeJSInstalled
            
            # Assert
            $result | Should -BeFalse
        }
    }
    
    Context "Test-ApiReady" {
        It "Returns true when API is ready (mocked)" {
            # Act
            $result = Test-ApiReady -ApiHost "test-host:8000"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Returns false when API is not ready" {
            # Arrange
            Mock Invoke-WebRequest { throw "Connection failed" }
            
            # Act
            $result = Test-ApiReady -ApiHost "test-host:8000"
            
            # Assert
            $result | Should -BeFalse
        }
    }
}

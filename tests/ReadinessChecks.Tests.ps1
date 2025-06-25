# Pester tests for ReadinessChecks module
BeforeAll {
    # Import the TestEnvironment helper
    . "$PSScriptRoot\TestHelpers\TestEnvironment.ps1"
    
    # Set up test environment
    Initialize-TestEnvironment
    
    # Import the module to test
    Import-Module "$PSScriptRoot\..\modules\ReadinessChecks.psm1" -Force
    
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

AfterAll {
    # Clean up test environment
    Remove-TestEnvironment
}

Describe "ReadinessChecks Module" {    Context "Test-CommandAvailable for Docker" {
        It "Returns true when Docker is installed (mocked)" {
            # Arrange
            Mock -ModuleName ReadinessChecks Get-Command { return $true } -ParameterFilter { $Name -eq "docker" }
            
            # Act
            $result = Test-CommandAvailable -CommandName "docker"
            
            # Assert
            $result | Should -BeTrue
            Should -Invoke -ModuleName ReadinessChecks Get-Command -ParameterFilter { $Name -eq "docker" } -Times 1
        }
        
        It "Returns false when Docker is not installed" {
            # Arrange
            Mock -ModuleName ReadinessChecks Get-Command { throw "Command not found" } -ParameterFilter { $Name -eq "docker" }
            
            # Act
            $result = Test-CommandAvailable -CommandName "docker"
            
            # Assert
            $result | Should -BeFalse
            Should -Invoke -ModuleName ReadinessChecks Get-Command -ParameterFilter { $Name -eq "docker" } -Times 1
        }
    }
    
    Context "Test-ServiceRunning for Docker" {
        It "Returns true when Docker is running (mocked)" {
            # Arrange
            Mock -ModuleName ReadinessChecks Invoke-Expression { return "Docker is running" } -ParameterFilter { $Command -like "*docker info*" }
            
            # Act
            $result = Test-ServiceRunning -Command "docker info"
            
            # Assert
            $result | Should -BeTrue
            Should -Invoke -ModuleName ReadinessChecks Invoke-Expression -ParameterFilter { $Command -like "*docker info*" } -Times 1
        }
        
        It "Returns false when Docker is not running" {
            # Arrange
            Mock -ModuleName ReadinessChecks Invoke-Expression { throw "Docker is not running" } -ParameterFilter { $Command -like "*docker info*" }
            
            # Act
            $result = Test-ServiceRunning -Command "docker info"
            
            # Assert
            $result | Should -BeFalse
            Should -Invoke -ModuleName ReadinessChecks Invoke-Expression -ParameterFilter { $Command -like "*docker info*" } -Times 1
        }
    }
    
    Context "Test-CommandAvailable for Node.js" {
        It "Returns true when Node.js is installed (mocked)" {
            # Arrange
            Mock -ModuleName ReadinessChecks Get-Command { return $true } -ParameterFilter { $Name -eq "node" }
            
            # Act
            $result = Test-CommandAvailable -CommandName "node"
            
            # Assert
            $result | Should -BeTrue
            Should -Invoke -ModuleName ReadinessChecks Get-Command -ParameterFilter { $Name -eq "node" } -Times 1
        }
        
        It "Returns false when Node.js is not installed" {
            # Arrange
            Mock -ModuleName ReadinessChecks Get-Command { throw "Command not found" } -ParameterFilter { $Name -eq "node" }
            
            # Act
            $result = Test-CommandAvailable -CommandName "node"
            
            # Assert
            $result | Should -BeFalse
            Should -Invoke -ModuleName ReadinessChecks Get-Command -ParameterFilter { $Name -eq "node" } -Times 1
        }
    }
    
    Context "Test-EndpointPath for API readiness" {
        It "Returns true when API is ready (mocked)" {
            # Arrange
            Mock -ModuleName ReadinessChecks Invoke-WebRequest {
                return @{
                    StatusCode = 200
                    Content = '{"status":"ready"}'
                }
            } -ParameterFilter { $Uri -like "*/readiness" }
            
            # Act
            $result = Test-EndpointPath -Host "test-host:8000" -Path "/readiness"
            
            # Assert
            $result | Should -BeTrue
            Should -Invoke -ModuleName ReadinessChecks Invoke-WebRequest -ParameterFilter { $Uri -like "*/readiness" } -Times 1
        }
        
        It "Returns false when API is not ready" {
            # Arrange
            Mock -ModuleName ReadinessChecks Invoke-WebRequest { throw "Connection failed" } -ParameterFilter { $Uri -like "*/readiness" }
            
            # Act
            $result = Test-EndpointPath -Host "test-host:8000" -Path "/readiness"
            
            # Assert
            $result | Should -BeFalse
            Should -Invoke -ModuleName ReadinessChecks Invoke-WebRequest -ParameterFilter { $Uri -like "*/readiness" } -Times 1
        }
    }
    
    Context "Test-CommandAvailable" {
        It "Returns true when a command is available" {
            # Arrange
            Mock -ModuleName ReadinessChecks Get-Command { return $true } -ParameterFilter { $Name -eq "testcmd" }
            
            # Act
            $result = Test-CommandAvailable -CommandName "testcmd"
            
            # Assert
            $result | Should -BeTrue
            Should -Invoke -ModuleName ReadinessChecks Get-Command -ParameterFilter { $Name -eq "testcmd" } -Times 1
        }
        
        It "Returns false when a command is not available" {
            # Arrange
            Mock -ModuleName ReadinessChecks Get-Command { throw "Command not found" } -ParameterFilter { $Name -eq "nonexistentcmd" }
            
            # Act
            $result = Test-CommandAvailable -CommandName "nonexistentcmd"
            
            # Assert
            $result | Should -BeFalse
            Should -Invoke -ModuleName ReadinessChecks Get-Command -ParameterFilter { $Name -eq "nonexistentcmd" } -Times 1
        }
    }
    
    Context "Test-ServiceRunning" {
        It "Returns true when a service is running" {
            # Arrange
            Mock -ModuleName ReadinessChecks Invoke-Expression { return "Service is running" } -ParameterFilter { $Command -eq "test-service status" }
            
            # Act
            $result = Test-ServiceRunning -Command "test-service status"
            
            # Assert
            $result | Should -BeTrue
            Should -Invoke -ModuleName ReadinessChecks Invoke-Expression -ParameterFilter { $Command -eq "test-service status" } -Times 1
        }
        
        It "Returns false when a service is not running" {
            # Arrange
            Mock -ModuleName ReadinessChecks Invoke-Expression { throw "Service is not running" } -ParameterFilter { $Command -eq "test-service status" }
            
            # Act
            $result = Test-ServiceRunning -Command "test-service status"
            
            # Assert
            $result | Should -BeFalse
            Should -Invoke -ModuleName ReadinessChecks Invoke-Expression -ParameterFilter { $Command -eq "test-service status" } -Times 1
        }
    }
    
    Context "Test-EndpointPath" {
        It "Returns true when an endpoint is ready" {
            # Arrange
            Mock -ModuleName ReadinessChecks Invoke-WebRequest {
                return @{
                    StatusCode = 200
                    Content = '{"status":"ready"}'
                }
            } -ParameterFilter { $Uri -like "http://test-host:8000/health" }
            
            # Act
            $result = Test-EndpointPath -Host "test-host:8000" -Path "/health"
            
            # Assert
            $result | Should -BeTrue
            Should -Invoke -ModuleName ReadinessChecks Invoke-WebRequest -ParameterFilter { $Uri -like "http://test-host:8000/health" } -Times 1
        }
        
        It "Returns false when an endpoint is not ready" {
            # Arrange
            Mock -ModuleName ReadinessChecks Invoke-WebRequest { throw "Connection failed" } -ParameterFilter { $Uri -like "http://test-host:8000/status" }
            
            # Act
            $result = Test-EndpointPath -Host "test-host:8000" -Path "/status"
            
            # Assert
            $result | Should -BeFalse
            Should -Invoke -ModuleName ReadinessChecks Invoke-WebRequest -ParameterFilter { $Uri -like "http://test-host:8000/status" } -Times 1
        }
    }
}

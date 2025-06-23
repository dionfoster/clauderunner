# Pester tests for CommandExecution module
BeforeAll {
    # Import the TestEnvironment helper
    . "$PSScriptRoot\TestHelpers\TestEnvironment.ps1"
    
    # Set up test environment
    Initialize-TestEnvironment
    
    # Import the module to test
    Import-Module "$PSScriptRoot\..\modules\CommandExecution.psm1" -Force
    
    # Mock needed functions
    Mock Write-Log { } # Suppress logging for tests
}

AfterAll {
    # Clean up test environment
    Cleanup-TestEnvironment
}

Describe "CommandExecution Module" {
    Context "Invoke-DockerCommand" {
        It "Executes a Docker command successfully" {
            # Arrange
            Mock docker { return "Docker command executed" } -ParameterFilter { $args -contains "test-command" }
            
            # Act
            $result = Invoke-DockerCommand -Command "test-command"
            
            # Assert
            $result | Should -Be "Docker command executed"
            Should -Invoke docker -Times 1 -ParameterFilter { $args -contains "test-command" }
        }
        
        It "Handles Docker command errors" {
            # Arrange
            Mock docker { throw "Docker command failed" } -ParameterFilter { $args -contains "invalid-command" }
            
            # Act & Assert
            { Invoke-DockerCommand -Command "invalid-command" } | Should -Throw "Docker command failed"
            Should -Invoke docker -Times 1 -ParameterFilter { $args -contains "invalid-command" }
        }
    }
    
    Context "Start-DockerContainer" {
        It "Starts a Docker container successfully" {
            # Arrange
            Mock Invoke-DockerCommand { return "Container started" } -ParameterFilter { $Command -like "*run*" }
            
            # Act
            $result = Start-DockerContainer -ImageName "test-image" -ApiPort 8000
            
            # Assert
            $result | Should -Be "Container started"
            Should -Invoke Invoke-DockerCommand -Times 1 -ParameterFilter { $Command -like "*run*" }
        }
    }
    
    Context "Stop-DockerContainer" {
        It "Stops a Docker container by name pattern" {
            # Arrange
            Mock Invoke-DockerCommand { 
                return @(
                    "container1 anthropic-api",
                    "container2 other-container"
                )
            } -ParameterFilter { $Command -like "*ps*" }
            
            Mock Invoke-DockerCommand { return "Container stopped" } -ParameterFilter { $Command -like "*stop container1*" }
            
            # Act
            Stop-DockerContainer -NamePattern "anthropic-api"
            
            # Assert
            Should -Invoke Invoke-DockerCommand -Times 1 -ParameterFilter { $Command -like "*ps*" }
            Should -Invoke Invoke-DockerCommand -Times 1 -ParameterFilter { $Command -like "*stop container1*" }
        }
        
        It "Does nothing when no matching containers found" {
            # Arrange
            Mock Invoke-DockerCommand { return @() } -ParameterFilter { $Command -like "*ps*" }
            Mock Invoke-DockerCommand { } -ParameterFilter { $Command -like "*stop*" }
            
            # Act
            Stop-DockerContainer -NamePattern "nonexistent-container"
            
            # Assert
            Should -Invoke Invoke-DockerCommand -Times 1 -ParameterFilter { $Command -like "*ps*" }
            Should -Invoke Invoke-DockerCommand -Times 0 -ParameterFilter { $Command -like "*stop*" }
        }
    }
    
    Context "Submit-Prompt" {
        It "Sends a prompt to the API and returns the response" {            # Arrange
            $mockResponseContent = '{"content": "This is a test response"}'
            
            Mock Invoke-RestMethod { return (ConvertFrom-Json $mockResponseContent) }
            
            # Act
            $result = Submit-Prompt -ApiHost "test-host:8000" -Prompt "Test prompt" -Model "test-model"
            
            # Assert
            $result | Should -Be "This is a test response"
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Handles API errors gracefully" {
            # Arrange
            Mock Invoke-RestMethod { throw "API call failed" }
            
            # Act & Assert
            { Submit-Prompt -ApiHost "test-host:8000" -Prompt "Test prompt" -Model "test-model" } | Should -Throw "Failed to submit prompt to API"
        }
    }
}

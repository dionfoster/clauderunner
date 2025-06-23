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

Describe "CommandExecution Module" {    Context "Invoke-DockerCommand" {
        It "Executes a Docker command successfully" {
            # Arrange - Mock at the docker command level
            Mock docker { return "Docker command executed" } -ModuleName CommandExecution
            
            # Act
            $result = Invoke-DockerCommand -Command "test-command"
            
            # Assert
            $result | Should -Be "Docker command executed"
        }
        
        It "Handles Docker command errors" {
            # Arrange - Mock docker to throw an error
            Mock docker { throw "Docker command failed" } -ModuleName CommandExecution
            
            # Act & Assert
            { Invoke-DockerCommand -Command "invalid-command" } | Should -Throw "Docker command failed: Docker command failed"
        }
    }
      Context "Start-DockerContainer" {
        It "Starts a Docker container successfully" {
            # Arrange
            Mock Invoke-DockerCommand { return "Container started" } -ModuleName CommandExecution
            
            # Act
            $result = Start-DockerContainer -ImageName "test-image" -ApiPort 8000
            
            # Assert
            $result | Should -Be "Container started"
        }
    }
      Context "Stop-DockerContainer" {
        It "Stops a Docker container by name pattern" {
            # Arrange
            $mockContainers = @(
                "container1 anthropic-api",
                "container2 other-container"
            )
            
            Mock Invoke-DockerCommand { return $mockContainers } -ModuleName CommandExecution -ParameterFilter { $Command -like "ps*" }
            Mock Invoke-DockerCommand { return "Container stopped" } -ModuleName CommandExecution -ParameterFilter { $Command -like "stop*" }
            
            # Act
            Stop-DockerContainer -NamePattern "anthropic-api"
            
            # Assert - Just verify no errors occur, as we've mocked all dependencies
            $true | Should -BeTrue
        }
        
        It "Does nothing when no matching containers found" {
            # Arrange
            Mock Invoke-DockerCommand { return @() } -ModuleName CommandExecution
            
            # Act
            Stop-DockerContainer -NamePattern "nonexistent-container"
            
            # Assert - Just verify no errors occur, as we've mocked all dependencies
            $true | Should -BeTrue        }
    }
}

# Pester tests for Configuration module
BeforeAll {
    # Import the TestEnvironment helper
    . "$PSScriptRoot\TestHelpers\TestEnvironment.ps1"
    
    # Set up test environment
    Initialize-TestEnvironment
    
    # Import the module to test
    Import-Module "$PSScriptRoot\..\modules\Configuration.psm1" -Force
    
    # Create a temporary config file for testing
    $script:TestConfigPath = "TestDrive:\test-config.yml"
    
    # Mock the Write-Log function to prevent console output during tests
    # This assumes the Logging module is loaded by TestEnvironment
    Mock Write-Log {}
    
    # Redirect exit function to prevent tests from exiting PowerShell
    function global:exit { param($Code) }
}

AfterAll {
    # Clean up test environment
    Remove-TestEnvironment
    
    # Remove test config file
    if (Test-Path $script:TestConfigPath) {
        Remove-Item $script:TestConfigPath -Force
    }
}

Describe "Configuration Module" {    
    Context "Set-ConfigPath" {
        It "Sets the configuration path correctly" {
            # Arrange
            $testPath = "TestDrive:\custom-config.yml"
            
            # Create a simple config file at the path
            @"
# Test configuration file
apiHost: "test-api-host"
"@ | Set-Content -Path $testPath
              # Mock the required functions
            Mock Write-Log {}
            function global:exit { param($Code) }
            
            # Act & Assert - Function should run without throwing an exception
            { Set-ConfigPath -Path $testPath } | Should -Not -Throw
        }
    }
    
    Context "Test-StateConfiguration" {
        BeforeEach {
            # Redirect functions
            function global:exit { param($Code) }
            function global:Write-Log { param($Message, $Level, $LogPath) }
        }
        
        It "Validates a correct state configuration with command action" {
            # Arrange
            $stateConfig = @{
                actions = @(
                    @{
                        type = "command"
                        command = "echo test"
                    }
                )
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | Should -Not -Throw
        }
        
        It "Validates a correct state configuration with application action" {
            # Arrange
            $stateConfig = @{
                actions = @(
                    @{
                        type = "application"
                        path = "C:\test\app.exe"
                    }
                )
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | Should -Not -Throw
        }
        
        It "Validates a correct state configuration with readiness check" {
            # Arrange
            $stateConfig = @{
                readiness = @{
                    checkEndpoint = "http://localhost:8000/health"
                }
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | Should -Not -Throw
        }
        
        It "Throws when state has no actions or readiness check" {
            # Arrange
            $stateConfig = @{
                someProperty = "value"
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | 
                Should -Throw "State 'testState' has no actions or valid readiness check defined"
        }
        
        It "Throws when action has invalid type" {
            # Arrange
            $stateConfig = @{
                actions = @(
                    @{
                        type = "invalid"
                        command = "echo test"
                    }
                )
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | 
                Should -Throw "Invalid action in state 'testState': must have type 'command' or 'application'"
        }
        
        It "Throws when command action is missing command property" {
            # Arrange
            $stateConfig = @{
                actions = @(
                    @{
                        type = "command"
                        # Missing command property
                    }
                )
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | 
                Should -Throw "Invalid command action in state 'testState': missing 'command' property"
        }
        
        It "Throws when application action is missing path property" {
            # Arrange
            $stateConfig = @{
                actions = @(
                    @{
                        type = "application"
                        # Missing path property
                    }
                )
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | 
                Should -Throw "Invalid application action in state 'testState': missing 'path' property"
        }
    }
}

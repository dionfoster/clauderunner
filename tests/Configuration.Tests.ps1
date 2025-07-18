# Pester tests for Configuration module
BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    $env = Initialize-StandardTestEnvironment -ModulesToImport @("Logging", "Configuration") -TestLogPath $script:TestLogPath
    
    # Create a temporary config file for testing
    $script:TestConfigPath = "TestDrive:\test-config.yml"
    
    # Redirect exit function to prevent tests from exiting PowerShell
    function global:exit { param($Code) }
}

AfterAll {
    # Clean up test log file
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
    
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
    
    Context "Initialize-Environment" {
        It "Runs without throwing when powershell-yaml is already available" {
            # This test verifies the function can be called without throwing
            # In practice, this would skip installation if the module is available
            { Initialize-Environment } | Should -Not -Throw
        }
    }
    
    Context "Get-Configuration" {
        It "Returns null when config file does not exist" {
            # Arrange
            $nonExistentPath = "TestDrive:\non-existent.yml"
            Set-ConfigPath -Path $nonExistentPath
            
            # Act
            $result = Get-Configuration
            
            # Assert
            $result | Should -Be $null
        }
        
        It "Successfully loads and parses valid YAML configuration" {
            # Arrange
            $testConfigPath = "TestDrive:\valid-config.yml"
            $yamlContent = @"
states:
  test:
    actions:
      - type: command
        command: echo test
"@
            Set-Content -Path $testConfigPath -Value $yamlContent
            Set-ConfigPath -Path $testConfigPath
            
            # Act
            $result = Get-Configuration
            
            # Assert
            $result | Should -Not -Be $null
            $result.states | Should -Not -Be $null
            $result.states.test | Should -Not -Be $null
        }
        
        It "Handles YAML parsing errors gracefully" {
            # Arrange
            $testConfigPath = "TestDrive:\invalid-config.yml"
            $invalidYaml = "invalid: yaml: content: [unclosed"
            Set-Content -Path $testConfigPath -Value $invalidYaml
            Set-ConfigPath -Path $testConfigPath
            
            # Act
            $result = Get-Configuration
            
            # Assert
            $result | Should -Be $null
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
        
        It "Validates a correct state configuration with waitEndpoint readiness check" {
            # Arrange
            $stateConfig = @{
                readiness = @{
                    waitEndpoint = "http://localhost:8000/health"
                }
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | Should -Not -Throw
        }
        
        It "Validates a correct state configuration with checkCommand readiness check" {
            # Arrange
            $stateConfig = @{
                readiness = @{
                    checkCommand = "echo ready"
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
        
        It "Throws when state has readiness but no valid check properties" {
            # Arrange
            $stateConfig = @{
                readiness = @{
                    invalidProperty = "value"
                }
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
        
        It "Accepts string actions (legacy format)" {
            # Arrange
            $stateConfig = @{
                actions = @(
                    "echo test"
                )
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | Should -Not -Throw
        }
        
        It "Accepts mixed string and object actions" {
            # Arrange
            $stateConfig = @{
                actions = @(
                    "echo test",
                    @{
                        type = "command"
                        command = "echo test2"
                    }
                )
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | Should -Not -Throw
        }
        
        It "Validates state configuration with both actions and readiness check" {
            # Arrange
            $stateConfig = @{
                actions = @(
                    @{
                        type = "command"
                        command = "echo test"
                    }
                )
                readiness = @{
                    checkEndpoint = "http://localhost:8000/health"
                }
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | Should -Not -Throw
        }
        
        It "Validates empty actions array with readiness check" {
            # Arrange
            $stateConfig = @{
                actions = @()
                readiness = @{
                    checkCommand = "echo ready"
                }
            }
            
            # Act & Assert
            { Test-StateConfiguration -StateConfig $stateConfig -StateName "testState" } | Should -Not -Throw
        }
    }
}

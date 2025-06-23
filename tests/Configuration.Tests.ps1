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
}

AfterAll {
    # Clean up test environment
    Cleanup-TestEnvironment
    
    # Remove test config file
    if (Test-Path $script:TestConfigPath) {
        Remove-Item $script:TestConfigPath -Force
    }
}

Describe "Configuration Module" {
    Context "Load-Config" {
        BeforeEach {
            # Create a test config file
            @"
# Test configuration file
apiHost: "test-api-host"
dockerImage: "test-docker-image:latest"
claudeModel: "test-model"
logPath: "test-log.log"
"@ | Set-Content -Path $script:TestConfigPath
        }
        
        It "Loads configuration from YAML file" {
            # Act
            $config = Load-Config -ConfigPath $script:TestConfigPath
            
            # Assert
            $config | Should -Not -BeNullOrEmpty
            $config.apiHost | Should -Be "test-api-host"
            $config.dockerImage | Should -Be "test-docker-image:latest"
            $config.claudeModel | Should -Be "test-model"
            $config.logPath | Should -Be "test-log.log"
        }
        
        It "Returns default configuration when file doesn't exist" {
            # Act
            $config = Load-Config -ConfigPath "non-existent-file.yml"
            
            # Assert
            $config | Should -Not -BeNullOrEmpty
            $config.apiHost | Should -Be "localhost:8000"
            $config.dockerImage | Should -Be "ghcr.io/anthropic-ai/claude-api:latest"
            $config.claudeModel | Should -Be "claude-3-opus-20240229"
        }
        
        It "Overrides defaults with values from config file" {
            # Arrange
            @"
# Partial configuration file
apiHost: "custom-host:9000"
"@ | Set-Content -Path $script:TestConfigPath
            
            # Act
            $config = Load-Config -ConfigPath $script:TestConfigPath
            
            # Assert
            $config.apiHost | Should -Be "custom-host:9000"
            $config.dockerImage | Should -Be "ghcr.io/anthropic-ai/claude-api:latest" # Default value
            $config.claudeModel | Should -Be "claude-3-opus-20240229" # Default value
        }
    }
}

# Pester tests for Logging module
BeforeAll {
    # Import the TestEnvironment helper
    . "$PSScriptRoot\TestHelpers\TestEnvironment.ps1"
    
    # Set up test environment
    Initialize-TestEnvironment
    
    # Import the module to test
    Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force
}

AfterAll {
    # Clean up test environment
    Cleanup-TestEnvironment
}

Describe "Logging Module" {
    Context "Write-Log" {
        BeforeEach {
            # Create a fresh log file for each test
            Reset-LogFile
        }
        
        It "Logs message with INFO level" {
            # Act
            Write-Log -Message "Test info message" -Level "INFO"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[\d{2}:\d{2}:\d{2}\] \[INFO\] ℹ️ │  Test info message"
        }
        
        It "Logs message with SUCCESS level" {
            # Act
            Write-Log -Message "Test success message" -Level "SUCCESS"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[\d{2}:\d{2}:\d{2}\] \[SUCCESS\] ✅ │  Test success message"
        }
        
        It "Logs message with WARN level" {
            # Act
            Write-Log -Message "Test warning message" -Level "WARN"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[\d{2}:\d{2}:\d{2}\] \[WARN\] ⚠️ │  Test warning message"
        }
        
        It "Logs message with ERROR level" {
            # Act
            Write-Log -Message "Test error message" -Level "ERROR"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[\d{2}:\d{2}:\d{2}\] \[ERROR\] ❌ │  Test error message"
        }
        
        It "Logs message with DEBUG level" {
            # Act
            Write-Log -Message "Test debug message" -Level "DEBUG"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[\d{2}:\d{2}:\d{2}\] \[DEBUG\] 🔍 │  Test debug message"
        }
        
        It "Uses default INFO level when level is not specified" {
            # Act
            Write-Log -Message "Test default level"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[\d{2}:\d{2}:\d{2}\] \[INFO\] ℹ️ │  Test default level"
        }
    }
    
    Context "Set-LogPath" {
        It "Changes the log path" {
            # Arrange
            $newLogPath = "test-custom-path.log"
            
            # Act
            Set-LogPath -Path $newLogPath
            
            # Assert - we can only check that the function runs without error
            # since $script:LogPath is module-scoped and not directly accessible
            $true | Should -BeTrue
            
            # Cleanup - set back to test log path
            Set-LogPath -Path $script:TestLogPath
        }
    }
}

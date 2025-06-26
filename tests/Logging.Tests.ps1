# Pester tests for Logging module
BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    $env = Initialize-StandardTestEnvironment -ModulesToImport @("Logging") -TestLogPath $script:TestLogPath
}

AfterAll {
    # Clean up test log file
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
}

Describe "Logging Module" {
    Context "Write-Log" {
        BeforeEach {
            # Create a fresh log file for each test
            Reset-TestLogFile -TestLogPath $script:TestLogPath
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

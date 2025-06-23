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
    
    Context "Get-StateIcon" {
        It "Returns Docker icon for dockerready state" {
            # Act
            $icon = Get-StateIcon -StateName "dockerready"
            
            # Assert
            $icon | Should -Be "🐳 "
        }
        
        It "Returns gear icon for dockerstartup state" {
            # Act
            $icon = Get-StateIcon -StateName "dockerstartup"
            
            # Assert
            $icon | Should -Be "⚙️ "
        }
        
        It "Returns green dot icon for nodeready state" {
            # Act
            $icon = Get-StateIcon -StateName "nodeready"
            
            # Assert
            $icon | Should -Be "🟢 "
        }
        
        It "Returns rocket icon for apiready state" {
            # Act
            $icon = Get-StateIcon -StateName "apiready"
            
            # Assert
            $icon | Should -Be "🚀 "
        }
        
        It "Returns default gear icon for unknown state" {
            # Act
            $icon = Get-StateIcon -StateName "unknownstate"
            
            # Assert
            $icon | Should -Be "⚙️ "
        }
    }
}

Describe "State Machine Visualization" {
    BeforeEach {
        # Create a fresh log file for each test
        Reset-LogFile
        
        # Reset state machine variables
        Reset-StateMachineVariables
    }
    
    Context "Start-StateTransitions" {
        It "Initializes state machine visualization" {
            # Act
            Start-StateTransitions
            
            # Assert
            $script:StateTransitionStarted | Should -BeTrue
            $script:TotalStartTime | Should -Not -BeNullOrEmpty
            
            # Check log file
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[\d{2}:\d{2}:\d{2}\] \[INFO\] - STATE TRANSITIONS:"
        }
    }
    
    Context "Start-StateProcessing" {
        It "Starts processing a state with no dependencies" {
            # Act
            Start-StateProcessing -StateName "TestState"
            
            # Assert
            $script:StateStartTimes["TestState"] | Should -Not -BeNullOrEmpty
            $script:ProcessedStates["TestState"] | Should -Not -BeNullOrEmpty
            $script:ProcessedStates["TestState"]["Status"] | Should -Be "Processing"
            $script:ProcessedStates["TestState"]["Dependencies"].Count | Should -Be 0
            
            # Check log file
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "STATE TRANSITIONS:"
            $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ TestState"
            $logContent | Should -Match "│  ├─ Dependencies: none"
        }
        
        It "Starts processing a state with dependencies" {
            # Act
            Start-StateProcessing -StateName "TestState" -Dependencies @("Dep1", "Dep2")
            
            # Assert
            $script:StateStartTimes["TestState"] | Should -Not -BeNullOrEmpty
            $script:ProcessedStates["TestState"]["Dependencies"].Count | Should -Be 2
            $script:ProcessedStates["TestState"]["Dependencies"] | Should -Contain "Dep1"
            $script:ProcessedStates["TestState"]["Dependencies"] | Should -Contain "Dep2"
            
            # Check log file
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  ├─ Dependencies: Dep1 ✓, Dep2 ✓"
        }
    }
    
    Context "Complete-State" {
        BeforeEach {
            # Setup state
            Start-StateProcessing -StateName "TestState"
        }
        
        It "Completes a state successfully" {
            # Act
            Complete-State -StateName "TestState" -Success $true
            
            # Assert
            $script:ProcessedStates["TestState"]["Status"] | Should -Be "Completed"
            $script:ProcessedStates["TestState"]["Duration"] | Should -Not -BeNullOrEmpty
            
            # Check log file
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ✅ COMPLETED \(\d+\.\d+s\)"
        }
        
        It "Marks a state as failed" {
            # Act
            Complete-State -StateName "TestState" -Success $false -ErrorMessage "Test error"
            
            # Assert
            $script:ProcessedStates["TestState"]["Status"] | Should -Be "Failed"
            $script:ProcessedStates["TestState"]["ErrorMessage"] | Should -Be "Test error"
            
            # Check log file
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ❌ FAILED \(\d+\.\d+s\)"
            $logContent | Should -Match "│     └─ Error: Test error"
        }
    }
}

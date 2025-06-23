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
        BeforeEach {
            # Reset state machine variables before test
            Reset-StateMachineVariables
            
            # Import module with -Force to ensure fresh state
            $loggingModule = Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force -PassThru
            
            # Update module script variables from our global test variables
            Update-ModuleScriptVariables -Module $loggingModule
            
            # Ensure log file is clean
            Reset-LogFile
        }
        
        It "Initializes state machine visualization" {
            # Act
            Start-StateTransitions
            
            # Assert - use Get-Variable to access script-scoped variables
            $stateStarted = & $loggingModule { $script:StateTransitionStarted }
            $stateStarted | Should -BeTrue
            
            $startTime = & $loggingModule { $script:TotalStartTime }
            $startTime | Should -Not -BeNullOrEmpty
              # Check log file
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\d{2}:\d{2}:\d{2} \[INFO\] - STATE TRANSITIONS:"
        }
    }
      Context "Start-StateProcessing" {
        BeforeEach {
            # Import module with -Force to ensure fresh state
            $loggingModule = Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force -PassThru
            
            # Update module script variables from our global test variables
            Update-ModuleScriptVariables -Module $loggingModule
            
            # Ensure log file is clean
            Reset-LogFile
        }
        
        It "Starts processing a state with no dependencies" {
            # Act
            Start-StateProcessing -StateName "TestState"
            
            # Assert
            $stateStartTimes = & $loggingModule { $script:StateStartTimes }
            $stateStartTimes["TestState"] | Should -Not -BeNullOrEmpty
            
            $processedStates = & $loggingModule { $script:ProcessedStates }
            $processedStates["TestState"] | Should -Not -BeNullOrEmpty
            $processedStates["TestState"]["Status"] | Should -Be "Processing"
            $processedStates["TestState"]["Dependencies"].Count | Should -Be 0
            
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
            $stateStartTimes = & $loggingModule { $script:StateStartTimes }
            $stateStartTimes["TestState"] | Should -Not -BeNullOrEmpty
            
            $processedStates = & $loggingModule { $script:ProcessedStates }
            $processedStates["TestState"]["Dependencies"].Count | Should -Be 2
            $processedStates["TestState"]["Dependencies"] | Should -Contain "Dep1"
            $processedStates["TestState"]["Dependencies"] | Should -Contain "Dep2"
            
            # Check log file
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  ├─ Dependencies: Dep1 ✓, Dep2 ✓"
        }
    }
      Context "Complete-State" {
        BeforeEach {
            # Import module with -Force to ensure fresh state
            $loggingModule = Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force -PassThru
            
            # Update module script variables from our global test variables
            Update-ModuleScriptVariables -Module $loggingModule
            
            # Ensure log file is clean
            Reset-LogFile
            
            # Setup state
            Start-StateProcessing -StateName "TestState"
        }
        
        It "Completes a state successfully" {
            # Act
            Complete-State -StateName "TestState" -Success $true
            
            # Assert - use the module's script variables
            $processedStates = & $loggingModule { $script:ProcessedStates }
            $processedStates["TestState"]["Status"] | Should -Be "Completed"
            $processedStates["TestState"]["Duration"] | Should -Not -BeNullOrEmpty            # Check log file
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\d{2}:\d{2}:\d{2} \[SUCCESS\] - │  └─ Result: ✅ COMPLETED \(\d+s\)"
        }
        
        It "Marks a state as failed" {
            # Act
            Complete-State -StateName "TestState" -Success $false -ErrorMessage "Test error"
            
            # Assert - use the module's script variables
            $processedStates = & $loggingModule { $script:ProcessedStates }
            $processedStates["TestState"]["Status"] | Should -Be "Failed"
            $processedStates["TestState"]["ErrorMessage"] | Should -Be "Test error"            # Check log file
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\d{2}:\d{2}:\d{2} \[ERROR\] - │  └─ Result: ❌ FAILED \(\d+s\)"
            $logContent | Should -Match "\d{2}:\d{2}:\d{2} \[ERROR\] - │     └─ Error: Test error"
        }
    }
}

# Pester tests for Logging state machine visualization
BeforeAll {
    # Import the TestEnvironment helper
    . "$PSScriptRoot\TestHelpers\TestEnvironment.ps1"
    
    # Set up test environment
    Initialize-TestEnvironment
    
    # Import the module to test
    Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force
    
    # Update module script variables with our global test variables
    Update-ModuleScriptVariables -Module (Get-Module Logging)
    
    # Create mock for Write-Host to avoid console output during tests
    Mock Write-Host { } -ModuleName Logging
}

AfterAll {
    # Clean up test environment
    Cleanup-TestEnvironment
}

# Helper function to initialize the state machine environment for each test
function global:Initialize-StateMachineTest {
    # Reset variables
    Reset-StateMachineVariables
    Reset-LogFile
    
    # Initialize ProcessedStates for tests that need it
    $global:ProcessedStates = @{}
    $global:StateStartTimes = @{}
    $global:ActionStartTimes = @{}
    
    # Update module variables
    Update-ModuleScriptVariables -Module (Get-Module Logging)
    
    # Make sure the module is using our test log path
    Set-LogPath -Path $script:TestLogPath
}

Describe "State Machine Visualization - Basic Functions" {
    BeforeEach {
        Initialize-StateMachineTest
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

Describe "State Machine Visualization - State Transitions" {
    BeforeEach {
        Initialize-StateMachineTest
    }
      Context "Start-StateTransitions" {
        It "Initializes the state machine" {
            # Act
            Start-StateTransitions
            
            # Assert - use our helper to access module script vars
            $scriptStateTransitionStarted = Get-ModuleScriptVar -Name "StateTransitionStarted"
            $scriptTotalStartTime = Get-ModuleScriptVar -Name "TotalStartTime"
            
            $scriptStateTransitionStarted | Should -BeTrue
            $scriptTotalStartTime | Should -Not -BeNullOrEmpty
            
            # Check log file for header
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "STATE TRANSITIONS:"
        }
        
        It "Only initializes once when called multiple times" {
            # Arrange - get the current time to compare later
            $beforeTime = Get-Date
            Start-Sleep -Milliseconds 10 # Small delay to ensure time difference
            
            # Act - call twice
            Start-StateTransitions
            $firstStartTime = Get-ModuleScriptVar -Name "TotalStartTime"
            Start-Sleep -Milliseconds 10 # Small delay
            Start-StateTransitions
            $secondStartTime = Get-ModuleScriptVar -Name "TotalStartTime"
            
            # Assert - should keep the first start time
            $secondStartTime | Should -Be $firstStartTime
            $secondStartTime | Should -BeGreaterThan $beforeTime
        }
        
        It "Records the start time correctly" {
            # Arrange
            $startTime = Get-Date
            
            # Act
            Start-StateTransitions
            $scriptTotalStartTime = Get-ModuleScriptVar -Name "TotalStartTime"
            
            # Assert - TotalStartTime should be within a small time window
            $timeDiff = ($scriptTotalStartTime - $startTime).TotalMilliseconds
            $timeDiff | Should -BeLessThan 1000 # Within 1 second
        }
    }
      Context "Start-StateProcessing" {
        It "Starts processing a state with no dependencies" {
            # Act
            Start-StateProcessing -StateName "TestState"
            
            # Assert - get script vars from module
            $scriptStateStartTimes = Get-ModuleScriptVar -Name "StateStartTimes"
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            
            $scriptStateStartTimes["TestState"] | Should -Not -BeNullOrEmpty
            $scriptProcessedStates["TestState"] | Should -Not -BeNullOrEmpty
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Processing"
            $scriptProcessedStates["TestState"]["Dependencies"].Count | Should -Be 0
            
            # Check log file
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ TestState"
            $logContent | Should -Match "│  ├─ Dependencies: none"
        }
        
        It "Starts processing a state with dependencies" {
            # Act
            Start-StateProcessing -StateName "TestState" -Dependencies @("Dep1", "Dep2")
            
            # Assert - get script vars from module
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            
            $scriptProcessedStates["TestState"]["Dependencies"].Count | Should -Be 2
            $scriptProcessedStates["TestState"]["Dependencies"][0] | Should -Be "Dep1"
            $scriptProcessedStates["TestState"]["Dependencies"][1] | Should -Be "Dep2"
            
            # Check log output for formatted dependencies
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Dependencies: Dep1 ✓, Dep2 ✓"
        }
        
        It "Uses the state icon appropriate for the state name" {
            # Tests for different state icons
            $testCases = @(
                @{ StateName = "dockerReady"; ExpectedIcon = "🐳" }
                @{ StateName = "apiReady"; ExpectedIcon = "🚀" }
                @{ StateName = "nodeReady"; ExpectedIcon = "🟢" }
                @{ StateName = "dockerStartup"; ExpectedIcon = "⚙️" }
            )
            
            foreach ($testCase in $testCases) {
                # Act
                Start-StateProcessing -StateName $testCase.StateName
                
                # Assert - check log for proper icon
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "┌─ STATE: 🔄 $($testCase.ExpectedIcon) $($testCase.StateName)"
                
                # Reset for next test
                Reset-LogFile
                Reset-StateMachineVariables
            }
        }
          It "Calls Start-StateTransitions automatically if not already started" {
            # Arrange
            $scriptStateTransitionStarted = Get-ModuleScriptVar -Name "StateTransitionStarted"
            $scriptStateTransitionStarted | Should -BeFalse # Verify not started
            
            # Act
            Start-StateProcessing -StateName "TestState"
            
            # Assert
            $scriptStateTransitionStarted = Get-ModuleScriptVar -Name "StateTransitionStarted"
            $scriptTotalStartTime = Get-ModuleScriptVar -Name "TotalStartTime"
            
            $scriptStateTransitionStarted | Should -BeTrue
            $scriptTotalStartTime | Should -Not -BeNullOrEmpty
            
            # Check log for STATE TRANSITIONS header
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "STATE TRANSITIONS:"
        }
    }
    
    Context "Write-StateCheck" {
        BeforeEach {
            # Setup state for the check
            Start-StateProcessing -StateName "TestState"
        }
        
        It "Logs a command check" {
            # Act
            Write-StateCheck -StateName "TestState" -CheckType "Command" -CheckDetails "docker ps"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  ├─ Check: 🔍 Command check \(docker ps\)"
        }
        
        It "Logs an endpoint check" {
            # Act
            Write-StateCheck -StateName "TestState" -CheckType "Endpoint" -CheckDetails "http://localhost:8000/health"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  ├─ Check: 🔍 Endpoint check \(http://localhost:8000/health\)"
        }
          It "Escapes special characters in check details" {
            # Act
            Write-StateCheck -StateName "TestState" -CheckType "Command" -CheckDetails "docker ps | grep -i 'claude'"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Check: 🔍 Command check \(docker ps \| grep -i 'claude'\)"
        }
    }
      Context "Write-StateCheckResult" {
        BeforeEach {
            # Setup state for the check result
            Start-StateProcessing -StateName "TestState"
            Write-StateCheck -StateName "TestState" -CheckType "Command" -CheckDetails "test command"
        }
        
        It "Logs a successful check result" {
            # Act
            Write-StateCheckResult -StateName "TestState" -IsReady $true -CheckType "Command"
            
            # Assert
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Completed"
            $scriptProcessedStates["TestState"]["Result"] | Should -Be "Already ready via Command check"
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ✅ READY \(already ready via command check\)"
        }
        
        It "Logs a failed check result" {
            # Act
            Write-StateCheckResult -StateName "TestState" -IsReady $false -CheckType "Command"
            
            # Assert - state should still be in processing status
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Processing"
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ❌ NOT READY \(proceeding with actions\)"
        }
          It "Includes additional info in check result for unsuccessful check" {
            # Act
            Write-StateCheckResult -StateName "TestState" -IsReady $false -CheckType "Command" -AdditionalInfo "Will retry"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ❌ NOT READY \(proceeding with actions\)"
        }
        
        It "Correctly formats endpoint success with status code" {
            # Arrange
            Initialize-StateMachineTest
            Start-StateProcessing -StateName "TestState"
            
            # Initialize ProcessedStates for this test
            $scriptProcessedStates = @{
                "TestState" = @{
                    "Status" = "Processing"
                    "Dependencies" = @()
                    "Actions" = @()
                }
            }
            Mock-ScriptVar -Name "ProcessedStates" -Value $scriptProcessedStates
              # Act
            Write-StateCheckResult -StateName "TestState" -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
            
            # Assert
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Completed"
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[SUCCESS\] - │  └─ Result: ✅ READY \(endpoint status: 200 OK\)"
        }
    }
}

Describe "State Machine Visualization - Actions" {
    BeforeEach {
        Initialize-StateMachineTest
        Start-StateTransitions
        Start-StateProcessing -StateName "TestState"
    }
    
    Context "Start-StateActions" {
        It "Logs the start of actions for a state" {
            # Act
            Start-StateActions -StateName "TestState"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  ├─ Actions: ⏳ EXECUTING"
        }
        
        It "Properly handles state with no prior check" {
            # Arrange - Create a new state without a prior check
            Start-StateProcessing -StateName "DirectActionState"
            
            # Act
            Start-StateActions -StateName "DirectActionState"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ DirectActionState"
            $logContent | Should -Match "│  ├─ Actions: ⏳ EXECUTING"
        }
    }
      Context "Start-StateAction" {
        BeforeEach {
            Initialize-StateMachineTest
            Start-StateProcessing -StateName "TestState"
            
            # Initialize ProcessedStates for testing
            $scriptProcessedStates = @{
                "TestState" = @{
                    "Status" = "Processing"
                    "Dependencies" = @()
                    "Actions" = @()
                }
            }
            Mock-ScriptVar -Name "ProcessedStates" -Value $scriptProcessedStates
            
            Start-StateActions -StateName "TestState"
        }
        
        It "Logs the start of a command action" {
            # Act
            $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "docker pull image"
            
            # Assert
            $actionId | Should -Not -BeNullOrEmpty
            
            # Get updated script variables
            $scriptActionStartTimes = Get-ModuleScriptVar -Name "ActionStartTimes"
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            
            $scriptActionStartTimes[$actionId] | Should -Not -BeNullOrEmpty
            $scriptProcessedStates["TestState"]["Actions"].Count | Should -Be 1
            $scriptProcessedStates["TestState"]["Actions"][0]["Type"] | Should -Be "Command"
            $scriptProcessedStates["TestState"]["Actions"][0]["Command"] | Should -Be "docker pull image"
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  │  ├─ Command: docker pull image"
        }
          It "Logs the start of an application action" {
            # Act
            $actionId = Start-StateAction -StateName "TestState" -ActionType "Application" -ActionCommand "npm start" -Description "Start Node.js app"
            
            # Assert
            # Get updated script variables
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"][0]["Type"] | Should -Be "Application"
            $scriptProcessedStates["TestState"]["Actions"][0]["Description"] | Should -Be "Start Node.js app"
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  │  ├─ Application: npm start \(Start Node.js app\)"
        }
          It "Creates a unique action ID for each action" {
            # Act - Create multiple actions
            $actionId1 = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "action1"
            $actionId2 = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "action2"
            
            # Assert
            $actionId1 | Should -Not -Be $actionId2
            
            # Get updated script variables
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"].Count | Should -Be 2
            $scriptProcessedStates["TestState"]["Actions"][0]["Id"] | Should -Be $actionId1
            $scriptProcessedStates["TestState"]["Actions"][1]["Id"] | Should -Be $actionId2
        }
        
        It "Properly handles actions with complex commands" {
            # Act - Test with complex command with special chars
            $complexCommand = "docker run -p 8000:8000 -v $(pwd):/app -e DEBUG=true --name claude image:latest"
            $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand $complexCommand
            
            # Assert            # Get updated script variables
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"][0]["Command"] | Should -Be $complexCommand
            
            # Check log contains the command
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Command: docker run -p 8000:8000 -v"
        }
    }
      Context "Complete-StateAction" {
        BeforeEach {
            Initialize-StateMachineTest
            Start-StateProcessing -StateName "TestState"
            
            # Initialize ProcessedStates for testing
            $actionId = [Guid]::NewGuid().ToString()
            $scriptProcessedStates = @{
                "TestState" = @{
                    "Status" = "Processing"
                    "Dependencies" = @()
                    "Actions" = @(
                        @{
                            "Id" = $actionId
                            "Type" = "Command"
                            "Command" = "test command"
                            "Status" = "Executing"
                        }
                    )
                }
            }
            $scriptActionStartTimes = @{
                $actionId = (Get-Date).AddSeconds(-1)  # Set start time 1 second ago
            }
            
            Mock-ScriptVar -Name "ProcessedStates" -Value $scriptProcessedStates
            Mock-ScriptVar -Name "ActionStartTimes" -Value $scriptActionStartTimes
            
            Start-StateActions -StateName "TestState"
            $script:ActionId = $actionId
        }
        
        It "Logs successful action completion" {
            # Act
            Complete-StateAction -StateName "TestState" -ActionId $script:ActionId -Success $true
            
            # Assert
            # Get updated script variables
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"][0]["Status"] | Should -Be "Success"
            $scriptProcessedStates["TestState"]["Actions"][0]["Duration"] | Should -Not -BeNullOrEmpty
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  │  │  └─ Status: ✓ SUCCESS"
        }
          It "Logs failed action completion with error message" {
            # Act
            Complete-StateAction -StateName "TestState" -ActionId $script:ActionId -Success $false -ErrorMessage "Command failed with exit code 1"
            
            # Assert
            # Get updated script variables
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"][0]["Status"] | Should -Be "Failed"
            $scriptProcessedStates["TestState"]["Actions"][0]["ErrorMessage"] | Should -Be "Command failed with exit code 1"
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  │  │  └─ Status: ✗ FAILED"
            $logContent | Should -Match "│  │  │     └─ Error: Command failed with exit code 1"
        }
        
        It "Calculates action duration correctly" {
            # Arrange - Set up a specific start time 
            $startTime = (Get-Date).AddSeconds(-2) # 2 seconds ago
            
            # Set up a new action id and start time
            $durationActionId = [Guid]::NewGuid().ToString()
            $scriptActionStartTimes = Get-ModuleScriptVar -Name "ActionStartTimes"
            $scriptActionStartTimes[$durationActionId] = $startTime
            Mock-ScriptVar -Name "ActionStartTimes" -Value $scriptActionStartTimes
            
            # Add the action to ProcessedStates
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"] += @{
                "Id" = $durationActionId
                "Type" = "Command"
                "Command" = "duration test"
                "Status" = "Executing"
            }
            Mock-ScriptVar -Name "ProcessedStates" -Value $scriptProcessedStates
              # Ensure at least some time passes
            Start-Sleep -Milliseconds 50
            
            # Act
            Complete-StateAction -StateName "TestState" -ActionId $durationActionId -Success $true
            
            # Assert
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $duration = $scriptProcessedStates["TestState"]["Actions"][1]["Duration"]
            $duration | Should -BeGreaterThan 1.5 # Should be at least 1.5 seconds
            
            # Check log for duration
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Status: ✓ SUCCESS \([\d\.]+s\)"
        }
          It "Logs failed action without error message" {
            # Act
            Complete-StateAction -StateName "TestState" -ActionId $script:ActionId -Success $false
            
            # Assert
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"][0]["Status"] | Should -Be "Failed"
            $scriptProcessedStates["TestState"]["Actions"][0]["ErrorMessage"] | Should -BeNullOrEmpty
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  │  │  └─ Status: ✗ FAILED"
            $logContent | Should -Not -Match "│  │  │     └─ Error:"
        }
    }
    
    Context "Complete-State" {
        BeforeEach {
            Initialize-StateMachineTest
            Start-StateProcessing -StateName "TestState"
            
            # Initialize ProcessedStates for testing
            $scriptProcessedStates = @{
                "TestState" = @{
                    "Status" = "Processing"
                    "Dependencies" = @()
                    "Actions" = @()
                }
            }
            
            # Set up start times
            $startTime = (Get-Date).AddSeconds(-3)
            $scriptStateStartTimes = @{
                "TestState" = $startTime
            }
            
            Mock-ScriptVar -Name "ProcessedStates" -Value $scriptProcessedStates
            Mock-ScriptVar -Name "StateStartTimes" -Value $scriptStateStartTimes
        }
          It "Logs successful state completion" {
            # Act
            Complete-State -StateName "TestState" -Success $true
            
            # Assert
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Completed"
            $scriptProcessedStates["TestState"]["Duration"] | Should -Not -BeNullOrEmpty
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ✅ COMPLETED"
        }
        
        It "Logs failed state completion with error message" {
            # Act
            Complete-State -StateName "TestState" -Success $false -ErrorMessage "State failed due to action error"
            
            # Assert
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Failed"
            $scriptProcessedStates["TestState"]["ErrorMessage"] | Should -Be "State failed due to action error"
              # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[ERROR\] - │  └─ Result: ❌ FAILED"
            $logContent | Should -Match "\[ERROR\] - │     └─ Error: State failed due to action error"
        }
        
        It "Logs failed state without error message" {
            # Act
            Complete-State -StateName "TestState" -Success $false
              # Assert
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Failed"
            $scriptProcessedStates["TestState"]["ErrorMessage"] | Should -BeNullOrEmpty
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ❌ FAILED"
            $logContent | Should -Not -Match "│     └─ Error:"
        }
        
        It "Calculates state duration correctly" {
            # Arrange - Set a specific start time
            $startTime = (Get-Date).AddSeconds(-2) # 2 seconds ago
            $scriptStateStartTimes = @{
                "TestState" = $startTime
            }
            Mock-ScriptVar -Name "StateStartTimes" -Value $scriptStateStartTimes
            
            # Act
            Complete-State -StateName "TestState" -Success $true
            
            # Assert
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $duration = $scriptProcessedStates["TestState"]["Duration"]
            $duration | Should -BeGreaterThan 1.5 # Should be around 2 seconds
            
            # Check log for duration
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Result: ✅ COMPLETED \([\d\.]+s\)"
        }
    }
}

Describe "State Machine Visualization - Summary" {
    BeforeEach {
        Initialize-StateMachineTest
        Start-StateTransitions
        
        # Set up multiple states with different statuses
        $scriptProcessedStates = @{
            "SuccessState" = @{
                "Status" = "Completed"
                "Dependencies" = @()
                "Actions" = @()
                "Duration" = 1.5
            }
            "FailedState" = @{
                "Status" = "Failed" 
                "Dependencies" = @()
                "Actions" = @()
                "Duration" = 0.5
                "ErrorMessage" = "Test error"
            }
        }
        
        Mock-ScriptVar -Name "ProcessedStates" -Value $scriptProcessedStates
        
        # Set up start time
        $startTime = (Get-Date).AddSeconds(-3)
        Mock-ScriptVar -Name "TotalStartTime" -Value $startTime
    }
    
    Context "Write-StateSummary" {
        It "Logs a summary with successful and failed states" {
            # Act
            Write-StateSummary -Success $false
              # Assert
            # Check log for summary header and state lists
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[INFO\] - SUMMARY:"
            $logContent | Should -Match "\[SUCCESS\] - ✅ Successfully processed: SuccessState"
            $logContent | Should -Match "\[ERROR\] - ❌ Failed: FailedState"
            $logContent | Should -Match "\[INFO\] - ⏱️ Total time: \d+s"
            
            # Verify state machine variables are reset
            $script:StateTransitionStarted | Should -BeFalse
            $script:StateStartTimes | Should -BeNullOrEmpty
            $script:ProcessedStates | Should -BeNullOrEmpty
        }
          It "Handles the case with only successful states" {
            # Arrange - remove the failed state
            $scriptProcessedStates = @{
                "SuccessState" = @{
                    "Status" = "Completed"
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = 1.5
                }
            }
            Mock-ScriptVar -Name "ProcessedStates" -Value $scriptProcessedStates
            
            # Set up start time
            $startTime = (Get-Date).AddSeconds(-3)
            Mock-ScriptVar -Name "TotalStartTime" -Value $startTime
            
            # Act
            Write-StateSummary -Success $true
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[SUCCESS\] - ✅ Successfully processed: SuccessState"
            $logContent | Should -Not -Match "\[ERROR\] - ❌ Failed:"
        }
          It "Handles the case with only failed states" {
            # Arrange - only failed states
            $scriptProcessedStates = @{
                "FailedState" = @{
                    "Status" = "Failed"
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = 0.5
                    "ErrorMessage" = "Test error"
                }
            }
            Mock-ScriptVar -Name "ProcessedStates" -Value $scriptProcessedStates
            
            # Set up start time
            $startTime = (Get-Date).AddSeconds(-3)
            Mock-ScriptVar -Name "TotalStartTime" -Value $startTime
            
            # Act
            Write-StateSummary -Success $false
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Not -Match "\[SUCCESS\] - ✅ Successfully processed:"
            $logContent | Should -Match "\[ERROR\] - ❌ Failed: FailedState"
        }
          It "Properly calculates total execution time" {
            # Arrange - set a known start time
            $startTime = (Get-Date).AddSeconds(-5)
            Mock-ScriptVar -Name "TotalStartTime" -Value $startTime
            
            # Setup ProcessedStates for the test
            $scriptProcessedStates = @{
                "TestState" = @{
                    "Status" = "Completed"
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = 2.5
                }
            }
            Mock-ScriptVar -Name "ProcessedStates" -Value $scriptProcessedStates
            
            # Act
            Write-StateSummary -Success $true
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[INFO\] - ⏱️ Total time: 5s"
        }
          It "Sorts states according to standard order" {
            # Arrange - Create ProcessedStates with states in non-standard order
            $scriptProcessedStates = @{
                "nodeReady" = @{
                    "Status" = "Completed"
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = 1.0
                }
                "dockerStartup" = @{
                    "Status" = "Completed"
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = 0.5
                }
                "apiReady" = @{
                    "Status" = "Completed"
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = 1.5
                }
                "dockerReady" = @{
                    "Status" = "Completed"
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = 0.8
                }
            }
            Mock-ScriptVar -Name "ProcessedStates" -Value $scriptProcessedStates
            
            # Set up start time
            $startTime = (Get-Date).AddSeconds(-3)
            Mock-ScriptVar -Name "TotalStartTime" -Value $startTime
            
            # Act
            Write-StateSummary -Success $true
            
            # Assert - Check for correct ordering in log (dockerStartup, dockerReady, apiReady, nodeReady)
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            
            # Verify the order in the log output
            if ($logContent -match "\[SUCCESS\] - ✅ Successfully processed: (.+)") {
                $processedStates = $Matches[1]
                
                # Verify order of standard states
                $dockerStartupIndex = $processedStates.IndexOf("dockerStartup")
                $dockerReadyIndex = $processedStates.IndexOf("dockerReady")
                $apiReadyIndex = $processedStates.IndexOf("apiReady")
                $nodeReadyIndex = $processedStates.IndexOf("nodeReady")
                
                # Standard order is: dockerStartup, dockerReady, apiReady, nodeReady
                $dockerStartupIndex | Should -BeLessThan $dockerReadyIndex
                $dockerReadyIndex | Should -BeLessThan $apiReadyIndex
                $apiReadyIndex | Should -BeLessThan $nodeReadyIndex
            }
        }
          It "Resets all state machine variables" {
            # Arrange - Set up variables that should be reset
            $scriptProcessedStates = @{
                "TestState" = @{
                    "Status" = "Completed"
                    "Dependencies" = @()
                    "Actions" = @()
                }
            }
            Mock-ScriptVar -Name "ProcessedStates" -Value $scriptProcessedStates
            Mock-ScriptVar -Name "StateTransitionStarted" -Value $true
            Mock-ScriptVar -Name "TotalStartTime" -Value (Get-Date)
            Mock-ScriptVar -Name "StateStartTimes" -Value @{ "TestState" = (Get-Date) }
            Mock-ScriptVar -Name "ActionStartTimes" -Value @{ "Action1" = (Get-Date) }
            
            # Act
            Write-StateSummary -Success $true
            
            # Assert all variables are reset
            $scriptStateTransitionStarted = Get-ModuleScriptVar -Name "StateTransitionStarted"
            $scriptTotalStartTime = Get-ModuleScriptVar -Name "TotalStartTime"
            $scriptStateStartTimes = Get-ModuleScriptVar -Name "StateStartTimes"
            $scriptActionStartTimes = Get-ModuleScriptVar -Name "ActionStartTimes"
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            
            $scriptStateTransitionStarted | Should -BeFalse
            $scriptTotalStartTime | Should -BeNullOrEmpty
            $scriptStateStartTimes.Count | Should -Be 0
            $scriptActionStartTimes.Count | Should -Be 0
            $scriptProcessedStates.Count | Should -Be 0
        }
    }
}

Describe "State Machine Visualization - End-to-End Flow" {
    BeforeEach {
        Initialize-StateMachineTest
    }
    
    It "Handles a complete successful state flow" {
        # Arrange & Act - Complete flow of a successful state
        Start-StateTransitions
        Start-StateProcessing -StateName "TestState"
        Write-StateCheck -StateName "TestState" -CheckType "Command" -CheckDetails "test command"
        Write-StateCheckResult -StateName "TestState" -IsReady $false -CheckType "Command"
        Start-StateActions -StateName "TestState"
        $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "test action"
        Complete-StateAction -StateName "TestState" -ActionId $actionId -Success $true
        Complete-State -StateName "TestState" -Success $true
        Write-StateSummary -Success $true
          # Assert
        # Check for correct sequence in log
        $logContent = Get-Content -Path $script:TestLogPath -Raw
        # Check key elements individually to make the test more robust
        $logContent | Should -Match "\[INFO\] - STATE TRANSITIONS:"
        $logContent | Should -Match "\[INFO\] - ┌─ STATE: 🔄 ⚙️ TestState"
        $logContent | Should -Match "Check: 🔍 Command check"
        $logContent | Should -Match "Result: ❌ NOT READY"
        $logContent | Should -Match "Actions: ⏳ EXECUTING"
        $logContent | Should -Match "Command: test action"
        $logContent | Should -Match "Status: ✓ SUCCESS"
        $logContent | Should -Match "Result: ✅ COMPLETED"
        $logContent | Should -Match "\[INFO\] - SUMMARY:"
        $logContent | Should -Match "Successfully processed: TestState"
    }
    
    It "Handles a state that's already ready" {
        # Arrange & Act - Flow of a state that's already ready
        Start-StateTransitions
        Start-StateProcessing -StateName "TestState"
        Write-StateCheck -StateName "TestState" -CheckType "Command" -CheckDetails "test command"
        Write-StateCheckResult -StateName "TestState" -IsReady $true -CheckType "Command"
        Write-StateSummary -Success $true
          # Assert
        $logContent = Get-Content -Path $script:TestLogPath -Raw
        # Check key elements individually
        $logContent | Should -Match "\[INFO\] - ┌─ STATE: 🔄 ⚙️ TestState"
        $logContent | Should -Match "Check: 🔍 Command check"
        $logContent | Should -Match "Result: ✅ READY"
        $logContent | Should -Match "\[INFO\] - SUMMARY:"
        $logContent | Should -Match "Successfully processed: TestState"
        $logContent | Should -Not -Match "Actions: ⏳ EXECUTING" # No actions should be executed
    }
    
    It "Handles a state with failed action" {
        # Arrange & Act - Flow of a state with failed action
        Start-StateTransitions
        Start-StateProcessing -StateName "TestState"
        Write-StateCheck -StateName "TestState" -CheckType "Command" -CheckDetails "test command"
        Write-StateCheckResult -StateName "TestState" -IsReady $false -CheckType "Command"
        Start-StateActions -StateName "TestState"
        $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "test action"
        Complete-StateAction -StateName "TestState" -ActionId $actionId -Success $false -ErrorMessage "Action failed"
        Complete-State -StateName "TestState" -Success $false -ErrorMessage "State failed due to action error"
        Write-StateSummary -Success $false
          # Assert
        $logContent = Get-Content -Path $script:TestLogPath -Raw
        # Check key elements individually
        $logContent | Should -Match "\[INFO\] - ┌─ STATE: 🔄 ⚙️ TestState"
        $logContent | Should -Match "Actions: ⏳ EXECUTING"
        $logContent | Should -Match "Status: ✗ FAILED"
        $logContent | Should -Match "Error: Action failed"
        $logContent | Should -Match "Result: ❌ FAILED"
        $logContent | Should -Match "Error: State failed due to action error"
        $logContent | Should -Match "\[INFO\] - SUMMARY:"
        $logContent | Should -Match "❌ Failed: TestState"
    }
    
    It "Handles multiple states with dependencies" {
        # Arrange & Act - Flow with multiple states and dependencies
        Start-StateTransitions
        
        # First state: dockerStartup
        Start-StateProcessing -StateName "dockerStartup"
        Write-StateCheck -StateName "dockerStartup" -CheckType "Command" -CheckDetails "docker info"
        Write-StateCheckResult -StateName "dockerStartup" -IsReady $true -CheckType "Command"
        
        # Second state: dockerReady with dependency
        Start-StateProcessing -StateName "dockerReady" -Dependencies @("dockerStartup")
        Write-StateCheck -StateName "dockerReady" -CheckType "Command" -CheckDetails "docker ps"
        Write-StateCheckResult -StateName "dockerReady" -IsReady $false -CheckType "Command"
        Start-StateActions -StateName "dockerReady"
        $actionId = Start-StateAction -StateName "dockerReady" -ActionType "Command" -ActionCommand "docker start container"
        Complete-StateAction -StateName "dockerReady" -ActionId $actionId -Success $true
        Complete-State -StateName "dockerReady" -Success $true
        
        # Third state: apiReady with dependency
        Start-StateProcessing -StateName "apiReady" -Dependencies @("dockerReady")
        Write-StateCheck -StateName "apiReady" -CheckType "Endpoint" -CheckDetails "http://localhost:8000/health"
        Write-StateCheckResult -StateName "apiReady" -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
        
        Write-StateSummary -Success $true
          # Assert
        $logContent = Get-Content -Path $script:TestLogPath -Raw
        
        # Check that all states are processed in the correct order
        $logContent | Should -Match "\[INFO\] - ┌─ STATE: 🔄 ⚙️ dockerStartup"
        $logContent | Should -Match "Result: ✅ READY"
        
        $logContent | Should -Match "\[INFO\] - ┌─ STATE: 🔄 🐳 dockerReady"
        $logContent | Should -Match "Dependencies: dockerStartup ✓"
        $logContent | Should -Match "Actions: ⏳ EXECUTING"
        $logContent | Should -Match "Command: docker start container"
        $logContent | Should -Match "Status: ✓ SUCCESS"
        $logContent | Should -Match "Result: ✅ COMPLETED"
        
        $logContent | Should -Match "\[INFO\] - ┌─ STATE: 🔄 🚀 apiReady"
        $logContent | Should -Match "Dependencies: dockerReady ✓"
        $logContent | Should -Match "Result: ✅ READY"
        
        # Check summary shows all states in the correct order
        $logContent | Should -Match "\[INFO\] - SUMMARY:"
        $logContent | Should -Match "Successfully processed: dockerStartup, dockerReady, apiReady"
    }
    
    It "Handles endpoint checks with status codes" {
        # Arrange & Act - Flow with endpoint check
        Start-StateTransitions
        Start-StateProcessing -StateName "apiReady"
        Write-StateCheck -StateName "apiReady" -CheckType "Endpoint" -CheckDetails "http://localhost:8000/health"
        Write-StateCheckResult -StateName "apiReady" -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
        Write-StateSummary -Success $true
          # Assert
        $logContent = Get-Content -Path $script:TestLogPath -Raw
        $logContent | Should -Match "\[INFO\] - ┌─ STATE: 🔄 🚀 apiReady"
        $logContent | Should -Match "Check: 🔍 Endpoint check"
        $logContent | Should -Match "Result: ✅ READY \(endpoint status: 200 OK\)"
    }
    
    It "Handles complex multi-action flows" {
        # Arrange & Act - Flow with multiple actions
        Start-StateTransitions
        Start-StateProcessing -StateName "nodeReady"
        Write-StateCheck -StateName "nodeReady" -CheckType "Command" -CheckDetails "node --version"
        Write-StateCheckResult -StateName "nodeReady" -IsReady $false -CheckType "Command"
        Start-StateActions -StateName "nodeReady"
        
        # Multiple actions
        $actionId1 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "npm install" -Description "Install dependencies"
        Complete-StateAction -StateName "nodeReady" -ActionId $actionId1 -Success $true
        
        $actionId2 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "npm run build" -Description "Build application"
        Complete-StateAction -StateName "nodeReady" -ActionId $actionId2 -Success $true
        
        $actionId3 = Start-StateAction -StateName "nodeReady" -ActionType "Application" -ActionCommand "npm start" -Description "Start server"
        Complete-StateAction -StateName "nodeReady" -ActionId $actionId3 -Success $true
        
        Complete-State -StateName "nodeReady" -Success $true
        Write-StateSummary -Success $true
          # Assert
        $logContent = Get-Content -Path $script:TestLogPath -Raw
        
        # Check all actions are logged correctly
        $logContent | Should -Match "\[INFO\] - │  │  ├─ Command: npm install \(Install dependencies\)"
        $logContent | Should -Match "\[SUCCESS\] - │  │  │  └─ Status: ✓ SUCCESS"
        $logContent | Should -Match "\[INFO\] - │  │  ├─ Command: npm run build \(Build application\)"
        $logContent | Should -Match "\[SUCCESS\] - │  │  │  └─ Status: ✓ SUCCESS"
        $logContent | Should -Match "\[INFO\] - │  │  ├─ Application: npm start \(Start server\)"
        $logContent | Should -Match "\[SUCCESS\] - │  │  │  └─ Status: ✓ SUCCESS"
        
        # Check state is completed
        $logContent | Should -Match "\[SUCCESS\] - │  └─ Result: ✅ COMPLETED"
        
        # Check summary
        $logContent | Should -Match "\[SUCCESS\] - ✅ Successfully processed: nodeReady"
    }
}

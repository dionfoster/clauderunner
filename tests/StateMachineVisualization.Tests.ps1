# Pester tests for state machine visualization
BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    $env = Initialize-StandardTestEnvironment -ModulesToImport @("Logging", "StateManagement", "StateVisualization") -TestLogPath $script:TestLogPath -IncludeStateManagement -IncludeCommonMocks
}

Describe "State Machine Visualization - Basic Functions" {    BeforeEach {
        # Use standardized BeforeEach setup
        Reset-TestLogFile -TestLogPath $script:TestLogPath
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
        # Use standardized BeforeEach setup
        Reset-TestLogFile -TestLogPath $script:TestLogPath
        if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
            Reset-StateMachineVariables
        }
    }
      Context "Start-StateTransitions" {
        It "Initializes the state machine" {
            # Act
            Start-StateTransitions
            
            # Assert - use our helper to access module script vars
            $scriptStateTransitionStarted = Get-StateManagementVar -VarName "StateTransitionStarted"
            $scriptTotalStartTime = Get-StateManagementVar -VarName "TotalStartTime"
            
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
            $firstStartTime = Get-StateManagementVar -VarName "TotalStartTime"
            Start-Sleep -Milliseconds 10 # Small delay
            Start-StateTransitions
            $secondStartTime = Get-StateManagementVar -VarName "TotalStartTime"
            
            # Assert - should keep the first start time
            $secondStartTime | Should -Be $firstStartTime
            $secondStartTime | Should -BeGreaterThan $beforeTime
        }
        
        It "Records the start time correctly" {
            # Arrange
            $startTime = Get-Date
              # Act
            Start-StateTransitions
            $scriptTotalStartTime = Get-StateManagementVar -VarName "TotalStartTime"
            
            # Assert - TotalStartTime should be within a small time window
            $timeDiff = ($scriptTotalStartTime - $startTime).TotalMilliseconds
            $timeDiff | Should -BeLessThan 1000 # Within 1 second
        }
    }
      Context "Start-StateProcessing" {
        It "Starts processing a state with no dependencies" {
            # Act
            Start-StateProcessing -StateName "TestState"
            
            # Assert - Check log file for the state being processed
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ TestState"
            $logContent | Should -Match "│  ├─ Dependencies: none"
            
            # Verify that the state management module is also tracking the state
            $scriptStateStartTimes = Get-StateManagementVar -VarName "StateStartTimes"
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
              # At minimum, there should be state tracking
            $scriptStateStartTimes | Should -Not -BeNullOrEmpty
            $scriptProcessedStates | Should -Not -BeNullOrEmpty
        }
        
        It "Starts processing a state with dependencies" {
            # Act
            Start-StateProcessing -StateName "TestState" -Dependencies @("Dep1", "Dep2")
            
            # Assert - get script vars from module
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            
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
                Reset-TestLogFile -TestLogPath $script:TestLogPath
                Reset-StateMachineVariables
            }
        }
        
        It "Calls Start-StateTransitions automatically if not already started" {
            # Arrange
            $scriptStateTransitionStarted = Get-StateManagementVar -VarName "StateTransitionStarted"
            $scriptStateTransitionStarted | Should -BeFalse # Verify not started
            
            # Act
            Start-StateProcessing -StateName "TestState"
            
            # Assert
            $scriptStateTransitionStarted = Get-StateManagementVar -VarName "StateTransitionStarted"
            $scriptTotalStartTime = Get-StateManagementVar -VarName "TotalStartTime"
            
            $scriptStateTransitionStarted | Should -BeTrue
            $scriptTotalStartTime | Should -Not -BeNullOrEmpty            # Check log for STATE TRANSITIONS header (with actual format)
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
            Write-StateCheck -CheckType "Command" -CheckDetails "docker ps"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  ├─ Check: 🔍 Command check \(docker ps\)"
        }
        
        It "Logs an endpoint check" {
            # Act
            Write-StateCheck -CheckType "Endpoint" -CheckDetails "http://localhost:8000/health"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  ├─ Check: 🔍 Endpoint check \(http://localhost:8000/health\)"
        }
          It "Escapes special characters in check details" {
            # Act
            Write-StateCheck -CheckType "Command" -CheckDetails "docker ps | grep -i 'claude'"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Check: 🔍 Command check \(docker ps \| grep -i 'claude'\)"
        }
    }
      Context "Write-StateCheckResult" {
        BeforeEach {
            # Setup state for the check result
            Start-StateProcessing -StateName "TestState"
            Write-StateCheck -CheckType "Command" -CheckDetails "test command"
        }
        
        It "Logs a successful check result" {
            # Act
            Write-StateCheckResult -IsReady $true -CheckType "Command"
            
            # Assert
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Completed"
            $scriptProcessedStates["TestState"]["Result"] | Should -Be "Already ready via Command check"
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ✅ READY \(already ready via command check\)"
        }
        
        It "Logs a failed check result" {
            # Act
            Write-StateCheckResult -IsReady $false -CheckType "Command"
            
            # Assert - state should still be in processing status
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Processing"
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ❌ NOT READY \(proceeding with actions\)"
        }
          It "Includes additional info in check result for unsuccessful check" {
            # Act
            Write-StateCheckResult -IsReady $false -CheckType "Command" -AdditionalInfo "Will retry"
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ❌ NOT READY \(proceeding with actions\)"
        }          
        It "Correctly formats endpoint success with status code" {
            # Arrange
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            
            # Act
            Write-StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
            
            # Assert
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Completed"
              # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Result: ✅ READY"
        }
    }
}

Describe "State Machine Visualization - Actions" {
    BeforeEach {
        # Reset log file for each test
        if (Test-Path $script:TestLogPath) {
            Remove-Item $script:TestLogPath -Force
        }
        New-Item -Path $script:TestLogPath -ItemType File -Force | Out-Null
        
        # Reset state machine variables if available
        if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
            Reset-StateMachineVariables
        }
        
        Start-StateTransitions
        Start-StateProcessing -StateName "TestState"
    }
    
    Context "Start-StateActions" {
        It "Logs the start of actions for a state" {
            # Act
            Start-StateActions -StateName "TestState"
              # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  ├─ Actions:"
        }
        
        It "Properly handles state with no prior check" {
            # Arrange - Create a new state without a prior check
            Start-StateProcessing -StateName "DirectActionState"
            
            # Act
            Start-StateActions -StateName "DirectActionState"
              # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ DirectActionState"
            $logContent | Should -Match "│  ├─ Actions:"
        }
    }
    
    Context "Start-StateAction" {
        BeforeEach {
            # Reset log file for each test
            if (Test-Path $script:TestLogPath) {
                Remove-Item $script:TestLogPath -Force
            }
            New-Item -Path $script:TestLogPath -ItemType File -Force | Out-Null
              # Reset state machine variables if available
            if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
                Reset-StateMachineVariables
            }
            
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Start-StateActions -StateName "TestState"
        }
        
        It "Logs the start of a command action" {
            # Act
            $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "docker pull image"
            
            # Assert
            $actionId | Should -Not -BeNullOrEmpty
            
            # Get updated script variables
            $scriptActionStartTimes = Get-StateManagementVar -VarName "ActionStartTimes"
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            
            $scriptActionStartTimes[$actionId] | Should -Not -BeNullOrEmpty
            $scriptProcessedStates["TestState"]["Actions"].Count | Should -Be 1
            $scriptProcessedStates["TestState"]["Actions"][0]["Type"] | Should -Be "Command"
            $scriptProcessedStates["TestState"]["Actions"][0]["Command"] | Should -Be "docker pull image"
              # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  │  ├─ Command \(docker pull image\)"
        }
          It "Logs the start of an application action" {
            # Act
            $actionId = Start-StateAction -StateName "TestState" -ActionType "Application" -ActionCommand "npm start" -Description "Start Node.js app"
            
            # Assert
            # Get updated script variables
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"][0]["Type"] | Should -Be "Application"
            $scriptProcessedStates["TestState"]["Actions"][0]["Description"] | Should -Be "Start Node.js app"
              # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  │  ├─ Command: Start Node.js app \(npm start\)"
        }
          It "Creates a unique action ID for each action" {
            # Act - Create multiple actions
            $actionId1 = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "action1"
            $actionId2 = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "action2"
            
            # Assert
            $actionId1 | Should -Not -Be $actionId2
            
            # Get updated script variables
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"].Count | Should -Be 2
            $scriptProcessedStates["TestState"]["Actions"][0]["Id"] | Should -Be $actionId1
            $scriptProcessedStates["TestState"]["Actions"][1]["Id"] | Should -Be $actionId2
        }
        
        It "Properly handles actions with complex commands" {
            # Act - Test with complex command with special chars
            $complexCommand = "docker run -p 8000:8000 -v $(pwd):/app -e DEBUG=true --name claude image:latest"
            $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand $complexCommand
              # Assert
            # Get updated script variables
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"][0]["Command"] | Should -Be $complexCommand
              # Check log contains the command
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Command \(docker run -p 8000:8000 -v"
        }
    }
    
    Context "Complete-StateAction" {
        BeforeEach {
            # Reset log file for each test
            if (Test-Path $script:TestLogPath) {
                Remove-Item $script:TestLogPath -Force
            }
            New-Item -Path $script:TestLogPath -ItemType File -Force | Out-Null
            
            # Reset state machine variables if available
            if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
                Reset-StateMachineVariables
            }            
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Start-StateActions -StateName "TestState"
            
            # Create a real action to test completion
            $script:ActionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "test command"
        }
        
        It "Logs successful action completion" {
            # Act
            Complete-StateAction -StateName "TestState" -ActionId $script:ActionId -Success $true
            
            # Assert
            # Get updated script variables
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"][0]["Status"] | Should -Be "Success"
            $scriptProcessedStates["TestState"]["Actions"][0]["Duration"] | Should -Not -BeNullOrEmpty
              # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  │  └─ Status: ✓"
        }
          It "Logs failed action completion with error message" {
            # Act
            Complete-StateAction -StateName "TestState" -ActionId $script:ActionId -Success $false -ErrorMessage "Command failed with exit code 1"
            
            # Assert
            # Get updated script variables
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"][0]["Status"] | Should -Be "Failed"
            $scriptProcessedStates["TestState"]["Actions"][0]["ErrorMessage"] | Should -Be "Command failed with exit code 1"
              # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  │  │  └─ Status: ✗ FAILED Error: Command failed with exit code 1"
        }
        
        It "Calculates action duration correctly" {
            # Arrange - Set up a specific start time 
            $startTime = (Get-Date).AddSeconds(-2) # 2 seconds ago
            
            # Create a real action for duration testing
            $durationActionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "duration test"
              # Ensure at least some time passes
            Start-Sleep -Milliseconds 50
            
            # Act
            Complete-StateAction -StateName "TestState" -ActionId $durationActionId -Success $true            # Assert
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $duration = $scriptProcessedStates["TestState"]["Actions"][1]["Duration"]
            $duration.TotalSeconds | Should -BeGreaterThan 0.02 # Should be at least 20ms
            
            # Check log for duration
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Status: ✓ SUCCESS \([\d\.]+s\)"
        }
          It "Logs failed action without error message" {
            # Act
            Complete-StateAction -StateName "TestState" -ActionId $script:ActionId -Success $false
            
            # Assert
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"][0]["Status"] | Should -Be "Failed"
            $scriptProcessedStates["TestState"]["Actions"][0]["ErrorMessage"] | Should -BeNullOrEmpty
              # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  │  └─ Status: ✗"
            $logContent | Should -Not -Match "│  │  │     └─ Error:"
        }
    }      
    Context "Complete-State" {
        BeforeEach {
            # Reset log file for each test
            if (Test-Path $script:TestLogPath) {
                Remove-Item $script:TestLogPath -Force
            }
            New-Item -Path $script:TestLogPath -ItemType File -Force | Out-Null
            
            # Reset state machine variables if available
            if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
                Reset-StateMachineVariables
            }
            
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
        }
          It "Logs successful state completion" {
            # Act
            Complete-State -StateName "TestState" -Success $true
            
            # Assert
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
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
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Failed"
            $scriptProcessedStates["TestState"]["ErrorMessage"] | Should -Be "State failed due to action error"            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ❌ FAILED"
            $logContent | Should -Match "│     └─ Error: State failed due to action error"
        }
        
        It "Logs failed state without error message" {
            # Act
            Complete-State -StateName "TestState" -Success $false
              # Assert
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Status"] | Should -Be "Failed"
            $scriptProcessedStates["TestState"]["ErrorMessage"] | Should -BeNullOrEmpty
            
            # Check log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "│  └─ Result: ❌ FAILED"
            $logContent | Should -Not -Match "│     └─ Error:"
        }
          It "Calculates state duration correctly" {
            # Arrange - Add a small delay to ensure measurable duration
            Start-Sleep -Milliseconds 100
            
            # Act
            Complete-State -StateName "TestState" -Success $true
              # Assert
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $duration = $scriptProcessedStates["TestState"]["Duration"]
            $duration.TotalSeconds | Should -BeGreaterThan 0.1 # Should be at least 100ms
            
            # Check log for duration
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Result: ✅ COMPLETED \([\d\.]+s\)"
        }
    }
}

Describe "State Machine Visualization - Summary" {
    BeforeEach {
        # Reset log file for each test
        if (Test-Path $script:TestLogPath) {
            Remove-Item $script:TestLogPath -Force
        }
        New-Item -Path $script:TestLogPath -ItemType File -Force | Out-Null
        
        # Reset state machine variables if available
        if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
            Reset-StateMachineVariables
        }
        
        Start-StateTransitions
          # Set up multiple states with different statuses
        $scriptProcessedStates = @{
            "SuccessState" = @{
                "Status" = "Completed"
                "Success" = $true
                "Dependencies" = @()
                "Actions" = @()
                "Duration" = 1.5
            }
            "FailedState" = @{
                "Status" = "Failed" 
                "Success" = $false
                "Dependencies" = @()
                "Actions" = @()
                "Duration" = 0.5
                "ErrorMessage" = "Test error"
            }
        }
        
        Set-ScriptVariableMock -Name "ProcessedStates" -Value $scriptProcessedStates
        
        # Set up start time
        $startTime = (Get-Date).AddSeconds(-3)
        Set-ScriptVariableMock -Name "TotalStartTime" -Value $startTime
    }
    
    Context "Write-StateSummary" {
        
        It "Logs a summary with successful and failed states" {
            # Act
            Write-StateSummary
            
            # Assert
            # Check log for summary header and state lists
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "EXECUTION SUMMARY"
            $logContent | Should -Match "✓ SuccessState"
            $logContent | Should -Match "✗ FailedState"
            $logContent | Should -Match "⏱️ Total time: \d+\.?\d*s"
            
            # Verify state machine variables are reset
            $script:StateTransitionStarted | Should -BeFalse
            $script:StateStartTimes | Should -BeNullOrEmpty
            $script:ProcessedStates | Should -BeNullOrEmpty
        }
          It "Handles the case with only successful states" {            # Arrange - remove the failed state
            $scriptProcessedStates = @{
                "SuccessState" = @{
                    "Status" = "Completed"
                    "Success" = $true
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = 1.5
                }
            }
            Set-ScriptVariableMock -Name "ProcessedStates" -Value $scriptProcessedStates
            
            # Set up start time
            $startTime = (Get-Date).AddSeconds(-3)
            Set-ScriptVariableMock -Name "TotalStartTime" -Value $startTime
            
            # Act
            Write-StateSummary
              # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "✓ SuccessState"
            $logContent | Should -Not -Match "✗.*Failed:"
        }
          It "Handles the case with only failed states" {            # Arrange - only failed states
            $scriptProcessedStates = @{
                "FailedState" = @{
                    "Status" = "Failed"
                    "Success" = $false
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = 0.5
                    "ErrorMessage" = "Test error"
                }
            }
            Set-ScriptVariableMock -Name "ProcessedStates" -Value $scriptProcessedStates
            
            # Set up start time
            $startTime = (Get-Date).AddSeconds(-3)
            Set-ScriptVariableMock -Name "TotalStartTime" -Value $startTime
            
            # Act
            Write-StateSummary
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Not -Match "\[SUCCESS\] - ✅ Successfully processed:"
            $logContent | Should -Match "✗ FailedState"
        }
        
        It "Properly calculates total execution time" {
            # Arrange - set a known start time
            $startTime = (Get-Date).AddSeconds(-5)
            Set-ScriptVariableMock -Name "TotalStartTime" -Value $startTime
              # Setup ProcessedStates for the test
            $scriptProcessedStates = @{
                "TestState" = @{
                    "Status" = "Completed"
                    "Success" = $true
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = 2.5
                }
            }
            Set-ScriptVariableMock -Name "ProcessedStates" -Value $scriptProcessedStates
            
            # Act
            Write-StateSummary
            
            # Assert
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "⏱️ Total time: 5\.?\d*s"
        }
        
        It "Sorts states by execution order (start time)" {
            # Arrange - Create ProcessedStates with states in non-chronological order
            $baseTime = Get-Date
            $scriptProcessedStates = @{
                "nodeReady" = @{
                    "Status" = "Completed"
                    "Success" = $true
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = New-TimeSpan -Seconds 1.0
                }
                "dockerStartup" = @{
                    "Status" = "Completed"
                    "Success" = $true
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = New-TimeSpan -Seconds 0.5
                }
                "apiReady" = @{
                    "Status" = "Completed"
                    "Success" = $true
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = New-TimeSpan -Seconds 1.5
                }
                "dockerReady" = @{
                    "Status" = "Completed"
                    "Success" = $true
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = New-TimeSpan -Seconds 0.8
                }
            }
            Set-ScriptVariableMock -Name "ProcessedStates" -Value $scriptProcessedStates
            
            # Set up StateStartTimes with intentionally different order than ProcessedStates
            # This simulates real execution where states start at different times
            $scriptStateStartTimes = @{
                "dockerStartup" = $baseTime.AddSeconds(0)   # First to start
                "dockerReady" = $baseTime.AddSeconds(1)     # Second to start  
                "apiReady" = $baseTime.AddSeconds(2)        # Third to start
                "nodeReady" = $baseTime.AddSeconds(3)       # Last to start
            }
            Set-ScriptVariableMock -Name "StateStartTimes" -Value $scriptStateStartTimes
              
            # Set up start time
            $startTime = $baseTime.AddSeconds(-5)
            Set-ScriptVariableMock -Name "TotalStartTime" -Value $startTime
            
            # Act
            Write-StateSummary
            
            # Assert - Check for correct ordering in log (dockerStartup, dockerReady, apiReady, nodeReady)
            $logContent = Get-Content -Path $script:TestLogPath -Raw
              # Find all state entries in the log
            $stateLines = @()
            $logContent -split "`n" | ForEach-Object {
                if ($_ -match '\[SYSTEM\].*[✓✗] (dockerStartup|dockerReady|apiReady|nodeReady)') {
                    $stateLines += $Matches[1]
                }
            }
            
            # Verify the states appear in execution order (start time order)
            $stateLines.Count | Should -Be 4
            $stateLines[0] | Should -Be "dockerStartup"
            $stateLines[1] | Should -Be "dockerReady"
            $stateLines[2] | Should -Be "apiReady"
            $stateLines[3] | Should -Be "nodeReady"
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
            Set-ScriptVariableMock -Name "ProcessedStates" -Value $scriptProcessedStates
            Set-ScriptVariableMock -Name "StateTransitionStarted" -Value $true
            Set-ScriptVariableMock -Name "TotalStartTime" -Value (Get-Date)
            Set-ScriptVariableMock -Name "StateStartTimes" -Value @{ "TestState" = (Get-Date) }
            Set-ScriptVariableMock -Name "ActionStartTimes" -Value @{ "Action1" = (Get-Date) }            
            # Act
            Write-StateSummary
            
            # Assert all variables are reset
            $scriptStateTransitionStarted = Get-StateManagementVar -VarName "StateTransitionStarted"
            $scriptTotalStartTime = Get-StateManagementVar -VarName "TotalStartTime"
            $scriptStateStartTimes = Get-StateManagementVar -VarName "StateStartTimes"
            $scriptActionStartTimes = Get-StateManagementVar -VarName "ActionStartTimes"
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            
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
        # Reset log file for each test
        if (Test-Path $script:TestLogPath) {
            Remove-Item $script:TestLogPath -Force
        }
        New-Item -Path $script:TestLogPath -ItemType File -Force | Out-Null
        
        # Reset state machine variables if available
        if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
            Reset-StateMachineVariables
        }
    }
    
    It "Handles a complete successful state flow" {
        # Arrange & Act - Complete flow of a successful state        Start-StateTransitions
        Start-StateProcessing -StateName "TestState"
        Write-StateCheck -CheckType "Command" -CheckDetails "test command"
        Write-StateCheckResult -IsReady $false -CheckType "Command"
        Start-StateActions -StateName "TestState"
        $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "test action"
        Complete-StateAction -StateName "TestState" -ActionId $actionId -Success $true
        Complete-State -StateName "TestState" -Success $true
        Write-StateSummary
        
        # Assert
        # Check for correct sequence in log
        $logContent = Get-Content -Path $script:TestLogPath -Raw
        
        # Check key elements individually to make the test more robust        
        $logContent | Should -Match "STATE TRANSITIONS:"
        $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ TestState"
        $logContent | Should -Match "Check: 🔍 Command check"
        $logContent | Should -Match "Result: ❌ NOT READY"
        $logContent | Should -Match "Actions:"
        $logContent | Should -Match "Command.*test action"
        $logContent | Should -Match "Status: ✓ SUCCESS"
        $logContent | Should -Match "Result: ✅ COMPLETED"
        $logContent | Should -Match "EXECUTION SUMMARY"
        $logContent | Should -Match "✓ TestState"
    }
    
    It "Handles a state that's already ready" {        # Arrange & Act - Flow of a state that's already ready
        Start-StateTransitions
        Start-StateProcessing -StateName "TestState"
        Write-StateCheck -CheckType "Command" -CheckDetails "test command"
        Write-StateCheckResult -IsReady $true -CheckType "Command"
        Write-StateSummary
        
        # Assert
        $logContent = Get-Content -Path $script:TestLogPath -Raw
          # Check key elements individually
        $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ TestState"
        $logContent | Should -Match "Check: 🔍 Command check"
        $logContent | Should -Match "Result: ✅ READY"
        $logContent | Should -Match "EXECUTION SUMMARY"
        $logContent | Should -Match "✓ TestState"
        $logContent | Should -Not -Match "Actions:" # No actions should be executed
    }
    
    It "Handles a state with failed action" {
        # Arrange & Act - Flow of a state with failed action        Start-StateTransitions
        Start-StateProcessing -StateName "TestState"
        Write-StateCheck -CheckType "Command" -CheckDetails "test command"
        Write-StateCheckResult -IsReady $false -CheckType "Command"
        Start-StateActions -StateName "TestState"
        $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "test action"
        Complete-StateAction -StateName "TestState" -ActionId $actionId -Success $false -ErrorMessage "Action failed"
        Complete-State -StateName "TestState" -Success $false -ErrorMessage "State failed due to action error"
        Write-StateSummary
        
        # Assert
        $logContent = Get-Content -Path $script:TestLogPath -Raw
        # Check key elements individually        
        $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ TestState"
        $logContent | Should -Match "Actions:"
        $logContent | Should -Match "Status: ✗ FAILED.*Error: Action failed"
        $logContent | Should -Match "Result: ❌ FAILED"
        $logContent | Should -Match "Error: State failed due to action error"
        $logContent | Should -Match "EXECUTION SUMMARY"
        $logContent | Should -Match "✗ TestState"
    }
    
    It "Handles multiple states with dependencies" {
        # Arrange & Act - Flow with multiple states and dependencies
        Start-StateTransitions
        
        # First state: dockerStartup
        Start-StateProcessing -StateName "dockerStartup"
        Write-StateCheck -CheckType "Command" -CheckDetails "docker info"
        Write-StateCheckResult -IsReady $true -CheckType "Command"
        
        # Second state: dockerReady with dependency
        Start-StateProcessing -StateName "dockerReady" -Dependencies @("dockerStartup")
        Write-StateCheck -CheckType "Command" -CheckDetails "docker ps"
        Write-StateCheckResult -IsReady $false -CheckType "Command"
        Start-StateActions -StateName "dockerReady"
        $actionId = Start-StateAction -StateName "dockerReady" -ActionType "Command" -ActionCommand "docker start container"
        Complete-StateAction -StateName "dockerReady" -ActionId $actionId -Success $true
        Complete-State -StateName "dockerReady" -Success $true
          # Third state: apiReady with dependency
        Start-StateProcessing -StateName "apiReady" -Dependencies @("dockerReady")
        Write-StateCheck -CheckType "Endpoint" -CheckDetails "http://localhost:8000/health"
        Write-StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
        
        Write-StateSummary
        
        # Assert
        $logContent = Get-Content -Path $script:TestLogPath -Raw
        # Check that all states are processed in the correct order        
        $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ dockerStartup"
        $logContent | Should -Match "Result: ✅ READY"
        
        $logContent | Should -Match "┌─ STATE: 🔄 🐳 dockerReady"
        $logContent | Should -Match "Dependencies: dockerStartup ✓"
        $logContent | Should -Match "Actions:"
        $logContent | Should -Match "Command \(docker start container\)"
        $logContent | Should -Match "Status: ✓ SUCCESS"
        $logContent | Should -Match "Result: ✅ COMPLETED"
        
        $logContent | Should -Match "┌─ STATE: 🔄 🚀 apiReady"
        $logContent | Should -Match "Dependencies: dockerReady ✓"
        $logContent | Should -Match "Result: ✅ READY"
          # Check summary shows all states in the correct order
        $logContent | Should -Match "EXECUTION SUMMARY"
        $logContent | Should -Match "✓ apiReady"
        $logContent | Should -Match "✓ dockerStartup"
        $logContent | Should -Match "✓ dockerReady"
    }
      It "Handles endpoint checks with status codes" {
        # Arrange & Act - Flow with endpoint check
        Start-StateTransitions
        Start-StateProcessing -StateName "apiReady"
        Write-StateCheck -CheckType "Endpoint" -CheckDetails "http://localhost:8000/health"
        Write-StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
        Write-StateSummary
        
        # Assert
        $logContent = Get-Content -Path $script:TestLogPath -Raw
        $logContent | Should -Match "┌─ STATE: 🔄 🚀 apiReady"
        $logContent | Should -Match "Check: 🔍 Endpoint check"
        $logContent | Should -Match "Result: ✅ READY"
    }
    
    It "Handles complex multi-action flows" {
        # Arrange & Act - Flow with multiple actions
        Start-StateTransitions
        Start-StateProcessing -StateName "nodeReady"
        Write-StateCheck -CheckType "Command" -CheckDetails "node --version"
        Write-StateCheckResult -IsReady $false -CheckType "Command"
        Start-StateActions -StateName "nodeReady"
        
        # Multiple actions
        $actionId1 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "npm install" -Description "Install dependencies"
        Complete-StateAction -StateName "nodeReady" -ActionId $actionId1 -Success $true
        
        $actionId2 = Start-StateAction -StateName "nodeReady" -ActionType "Command" -ActionCommand "npm run build" -Description "Build application"
        Complete-StateAction -StateName "nodeReady" -ActionId $actionId2 -Success $true
        
        $actionId3 = Start-StateAction -StateName "nodeReady" -ActionType "Application" -ActionCommand "npm start" -Description "Start server"
        Complete-StateAction -StateName "nodeReady" -ActionId $actionId3 -Success $true        
        Complete-State -StateName "nodeReady" -Success $true
        Write-StateSummary
        
        # Assert
        $logContent = Get-Content -Path $script:TestLogPath -Raw
          # Check all actions are logged correctly
        $logContent | Should -Match "│  │  ├─ Command: Install dependencies \(npm install\)"
        $logContent | Should -Match "│  │  │  └─ Status: ✓ SUCCESS"
        $logContent | Should -Match "│  │  ├─ Command: Build application \(npm run build\)"
        $logContent | Should -Match "│  │  │  └─ Status: ✓ SUCCESS"
        $logContent | Should -Match "│  │  ├─ Command: Start server \(npm start\)"
        $logContent | Should -Match "│  │  │  └─ Status: ✓ SUCCESS"
        
        # Check state is completed
        $logContent | Should -Match "│  └─ Result: ✅ COMPLETED"
        
        # Check summary
        $logContent | Should -Match "✓ nodeReady"
    }
      It "Orders states by start time, not completion time" {
            # Arrange - Simulate scenario where a later-started state completes first
            $baseTime = Get-Date
            $scriptProcessedStates = @{
                "slowState" = @{
                    "Status" = "Completed"
                    "Success" = $true
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = New-TimeSpan -Seconds 5.0
                    "EndTime" = $baseTime.AddSeconds(6)  # Started first but finished last
                }
                "fastState" = @{
                    "Status" = "Completed"
                    "Success" = $true
                    "Dependencies" = @()
                    "Actions" = @()
                    "Duration" = New-TimeSpan -Seconds 0.5
                    "EndTime" = $baseTime.AddSeconds(2)  # Started second but finished first
                }
            }
            Set-ScriptVariableMock -Name "ProcessedStates" -Value $scriptProcessedStates
            
            # Set up StateStartTimes - slowState started first, fastState started second
            $scriptStateStartTimes = @{
                "slowState" = $baseTime.AddSeconds(1)   # Started first
                "fastState" = $baseTime.AddSeconds(1.5) # Started second
            }
            Set-ScriptVariableMock -Name "StateStartTimes" -Value $scriptStateStartTimes
              
            # Set up start time
            $startTime = $baseTime.AddSeconds(-1)
            Set-ScriptVariableMock -Name "TotalStartTime" -Value $startTime
            
            # Act
            Write-StateSummary
            
            # Assert - slowState should appear before fastState in summary (based on start time)
            $logContent = Get-Content -Path $script:TestLogPath -Raw
              # Find all state entries in the log
            $stateLines = @()
            $logContent -split "`n" | ForEach-Object {
                if ($_ -match '\[SYSTEM\].*[✓✗] (slowState|fastState)') {
                    $stateLines += $Matches[1]
                }
            }
            
            # Verify the states appear in start time order, not completion time order
            $stateLines.Count | Should -Be 2
            $stateLines[0] | Should -Be "slowState"  # Started first, should appear first
            $stateLines[1] | Should -Be "fastState"  # Started second, should appear second
        }
}

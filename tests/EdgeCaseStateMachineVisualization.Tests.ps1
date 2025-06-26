# Additional edge case tests for state machine visualization

BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    $env = Initialize-StandardTestEnvironment -ModulesToImport @("Logging", "StateManagement", "StateVisualization") -TestLogPath $script:TestLogPath -IncludeStateManagement -IncludeCommonMocks
}

Describe "State Machine Visualization - Edge Cases" {    BeforeEach {
        # Use standardized BeforeEach setup
        Reset-TestLogFile -TestLogPath $script:TestLogPath
        if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
            Reset-StateMachineVariables
        }
    }
    
    Context "Empty or invalid state names" {
        It "Handles empty state name gracefully" {
            # Since PowerShell enforces parameter validation, this should throw an error
            { Start-StateProcessing -StateName "" } | Should -Throw
        }
        
        It "Uses default icon for state name with special characters" {
            # Act
            $icon = Get-StateIcon -StateName "special!@#$%^&*()_+"
            
            # Assert - should use default icon
            $icon | Should -Be "⚙️ "
        }
    }
      Context "Timing edge cases" {
        It "Handles zero-duration actions" {
            # Arrange
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Start-StateActions -StateName "TestState"
            
            # Create action and complete it immediately
            $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "instant action"
            
            # Act - complete the action immediately
            Complete-StateAction -StateName "TestState" -ActionId $actionId -Success $true            # Assert
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"] | Should -Not -BeNullOrEmpty
            $scriptProcessedStates["TestState"]["Actions"].Count | Should -BeGreaterThan 0
            $action = $scriptProcessedStates["TestState"]["Actions"][0]
            $action | Should -Not -BeNull
            $action.Duration | Should -Not -BeNull
            
            # Duration should be very small (but not necessarily 0 due to processing time)
            $action.Duration.TotalSeconds | Should -BeLessThan 1
            
            # Check log - should show the action was executed
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "⏳ Command \(instant action\)"
        }
    }
    
    Context "Complex state dependencies" {
        It "Handles multiple dependencies with mixed status" {
            # Arrange
            Start-StateTransitions
            
            # Setup dependencies with different states
            Start-StateProcessing -StateName "DepState1"
            Complete-State -StateName "DepState1" -Success $true
            
            Start-StateProcessing -StateName "DepState2"
            Complete-State -StateName "DepState2" -Success $false -ErrorMessage "Dependency failed"
            
            # Act - state with mixed dependencies
            Start-StateProcessing -StateName "TestState" -Dependencies @("DepState1", "DepState2")
            
            # Assert - log should show dependencies
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Dependencies: DepState1 ✓, DepState2 ✓"
        }
    }
    
    Context "State machine reset" {        It "Properly resets all state after Write-StateSummary" {
            # Arrange - perform a complete state flow
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Write-StateCheck -CheckType "Command" -CheckDetails "test"
            Write-StateCheckResult -IsReady $true -CheckType "Command"
            
            # Act - write summary
            Write-StateSummary
            
            # Assert - check that summary was written
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "EXECUTION SUMMARY"
            
            # Retrieve all the script variables to check reset state
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptStateTransitionStarted = Get-StateManagementVar -VarName "StateTransitionStarted"
            $scriptTotalStartTime = Get-StateManagementVar -VarName "TotalStartTime"
            $scriptStateStartTimes = Get-StateManagementVar -VarName "StateStartTimes"
            $scriptActionStartTimes = Get-StateManagementVar -VarName "ActionStartTimes"
            
            $scriptStateTransitionStarted | Should -BeFalse
            $scriptTotalStartTime | Should -BeNullOrEmpty
            $scriptStateStartTimes.Count | Should -Be 0
            $scriptActionStartTimes.Count | Should -Be 0
            $scriptProcessedStates.Count | Should -Be 0
            
            # We should be able to start a new state machine flow
            Start-StateTransitions
            Start-StateProcessing -StateName "NewState"            # Check log - should show new state after reset
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[SYSTEM\].*STATE TRANSITIONS:"
            $logContent | Should -Match "\[SYSTEM\].*┌─ STATE: 🔄 ⚙️ NewState"
        }
    }
      Context "Special status codes and responses" {
        It "Handles non-standard HTTP status codes properly" {
            # Arrange
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Write-StateCheck -CheckType "Endpoint" -CheckDetails "http://example.com/api"
            
            # Act - use non-standard status code
            Write-StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 418"
            
            # Assert - should format the status code correctly
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Status: ✅ Ready - Endpoint \(Status: 418\)"
        }
        
        It "Handles endpoint check with no status code in additional info" {
            # Arrange
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Write-StateCheck -CheckType "Endpoint" -CheckDetails "http://example.com/api"
            
            # Act - no status code in additional info
            Write-StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Connection successful"
            
            # Assert - should fall back to generic ready message
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Status: ✅ Ready - Endpoint \(Connection successful\)"
        }
    }
    
    Context "Action type handling" {        It "Accepts and displays any action type" {
            # Arrange
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Start-StateActions -StateName "TestState"
            
            # Act - should accept any action type
            $actionId = Start-StateAction -StateName "TestState" -ActionType "CustomType" -ActionCommand "test"
            
            # Assert - should display the custom action type
            $actionId | Should -Not -BeNullOrEmpty
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "⏳ CustomType \(test\)"
        }
        
        It "Correctly displays description when provided for Command action type" {
            # Arrange
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Start-StateActions -StateName "TestState"
            
            # Act
            Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "test command" -Description "Test description"
              # Assert - should include description in log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Command: Test description \(test command\)"
        }
    }
    
    Context "Multiple actions with same command" {
        It "Handles multiple actions with identical commands" {
            # Arrange
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Start-StateActions -StateName "TestState"
            
            # Act - create two actions with same command
            $actionId1 = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "identical command"
            $actionId2 = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "identical command"
              # Assert - should create unique IDs and separate action entries
            $actionId1 | Should -Not -Be $actionId2
            
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"].Count | Should -Be 2              # Both actions should be in the log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $matchResults = [regex]::Matches($logContent, [regex]::Escape("Command (identical command)"))
            $matchResults.Count | Should -Be 2
        }
    }
    
    Context "Very long command and state names" {
        It "Handles very long state names" {
            # Arrange & Act
            $longStateName = "This_is_an_extremely_long_state_name_that_tests_the_robustness_of_the_state_machine_visualization_function_with_excessive_length"
            Start-StateProcessing -StateName $longStateName
            
            # Assert - should properly format the state
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ $longStateName"
        }
          It "Handles very long command details" {
            # Arrange
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            
            # Act
            $longCommand = "docker run --name claude-runner -v /data:/app/data -p 8000:8000 -e NODE_ENV=production -e DEBUG=true -e API_KEY=12345 --restart always --network=host --log-driver=json-file --log-opt max-size=10m --log-opt max-file=3 --user 1000:1000 --rm -d claude-image:latest"
            Write-StateCheck -CheckType "Command" -CheckDetails $longCommand
            
            # Assert - should display the long command
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Command check \(docker run --name claude-runner"
        }
    }
}

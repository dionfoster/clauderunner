# Additional edge case tests for state machine visualization

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

Describe "State Machine Visualization - Edge Cases" {
    BeforeEach {
        Initialize-StateMachineTest
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
            
            # Manually set the start time to be the same as completion time
            $now = Get-Date
            
            $scriptActionStartTimes = Get-ModuleScriptVar -Name "ActionStartTimes"
            $scriptActionStartTimes[$actionId] = $now
            Mock-ScriptVar -Name "ActionStartTimes" -Value $scriptActionStartTimes
            
            # Act - complete the action
            Complete-StateAction -StateName "TestState" -ActionId $actionId -Success $true
            
            # Assert
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $duration = $scriptProcessedStates["TestState"]["Actions"][0]["Duration"]
            
            # Duration should be 0 or very close to it
            $duration | Should -BeLessThan 0.1
            
            # Check log - should show duration close to 0
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Status: ✓ SUCCESS \(0(\.\d+)?s\)"
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
    
    Context "State machine reset" {
        It "Properly resets all state after Write-StateSummary" {
            # Arrange - perform a complete state flow
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Write-StateCheck -StateName "TestState" -CheckType "Command" -CheckDetails "test"
            Write-StateCheckResult -StateName "TestState" -IsReady $true -CheckType "Command"
            
            # Act - write summary (which should reset state)
            Write-StateSummary -Success $true
            
            # Assert - all variables should be reset
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
            
            # We should be able to start a new state machine flow
            Start-StateTransitions
            Start-StateProcessing -StateName "NewState"
              # Check log - should show new state after reset
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "\[INFO\] - STATE TRANSITIONS:"
            $logContent | Should -Match "\[INFO\] - ┌─ STATE: 🔄 ⚙️ NewState"
        }
    }
    
    Context "Special status codes and responses" {
        It "Handles non-standard HTTP status codes properly" {
            # Arrange
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Write-StateCheck -StateName "TestState" -CheckType "Endpoint" -CheckDetails "http://example.com/api"
            
            # Act - use non-standard status code
            Write-StateCheckResult -StateName "TestState" -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 418"
            
            # Assert - should format the status code correctly
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Result: ✅ READY \(endpoint status: 418 OK\)"
        }
        
        It "Handles endpoint check with no status code in additional info" {
            # Arrange
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Write-StateCheck -StateName "TestState" -CheckType "Endpoint" -CheckDetails "http://example.com/api"
            
            # Act - no status code in additional info
            Write-StateCheckResult -StateName "TestState" -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Connection successful"
              # Assert - should fall back to generic ready message
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Result: ✅ READY \(already ready via endpoint check"
        }
    }
    
    Context "Action type handling" {
        It "Throws error on invalid action type" {
            # Arrange
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Start-StateActions -StateName "TestState"
            
            # Act & Assert - should throw error on invalid action type
            { Start-StateAction -StateName "TestState" -ActionType "InvalidType" -ActionCommand "test" } | Should -Throw
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
            $logContent | Should -Match "Command: test command \(Test description\)"
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
            
            $scriptProcessedStates = Get-ModuleScriptVar -Name "ProcessedStates"
            $scriptProcessedStates["TestState"]["Actions"].Count | Should -Be 2
              # Both actions should be in the log
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $matchResults = [regex]::Matches($logContent, [regex]::Escape("Command: identical command"))
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
            Write-StateCheck -StateName "TestState" -CheckType "Command" -CheckDetails $longCommand
            
            # Assert - should display the long command
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $logContent | Should -Match "Command check \(docker run --name claude-runner"
        }
    }
}

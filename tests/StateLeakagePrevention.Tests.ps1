# StateLeakagePrevention.Tests.ps1 - Tests to verify no state leakage between script runs

BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    Initialize-StandardTestEnvironment -ModulesToImport @("Logging", "StateManagement", "StateVisualization") -TestLogPath $script:TestLogPath -IncludeStateManagement -IncludeCommonMocks | Out-Null
}

AfterAll {
    # Clean up test log file
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
}

Describe "State Leakage Prevention" {
    
    Context "StateManagement Module State Reset" {
        BeforeEach {
            Reset-TestLogFile -TestLogPath $script:TestLogPath
        }
        
        It "Reset-StateMachineVariables clears all state variables" {
            # Arrange - set up some state
            Start-StateTransitions
            Start-StateProcessing -StateName "TestState"
            Register-StateAction -StateName "TestState" -ActionType "Test"
            
            # Verify state exists
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptStateStartTimes = Get-StateManagementVar -VarName "StateStartTimes"
            $scriptActionStartTimes = Get-StateManagementVar -VarName "ActionStartTimes"
            $scriptTotalStartTime = Get-StateManagementVar -VarName "TotalStartTime"
            $scriptStateTransitionStarted = Get-StateManagementVar -VarName "StateTransitionStarted"
            
            $scriptProcessedStates.Count | Should -BeGreaterThan 0
            $scriptStateStartTimes.Count | Should -BeGreaterThan 0
            $scriptActionStartTimes.Count | Should -BeGreaterThan 0
            $scriptTotalStartTime | Should -Not -BeNullOrEmpty
            $scriptStateTransitionStarted | Should -BeTrue
            
            # Act - reset state
            Reset-StateMachineVariables
            
            # Assert - verify all variables are reset
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptStateStartTimes = Get-StateManagementVar -VarName "StateStartTimes"
            $scriptActionStartTimes = Get-StateManagementVar -VarName "ActionStartTimes"
            $scriptTotalStartTime = Get-StateManagementVar -VarName "TotalStartTime"
            $scriptStateTransitionStarted = Get-StateManagementVar -VarName "StateTransitionStarted"
            
            $scriptProcessedStates.Count | Should -Be 0
            $scriptStateStartTimes.Count | Should -Be 0
            $scriptActionStartTimes.Count | Should -Be 0
            $scriptTotalStartTime | Should -BeNullOrEmpty
            $scriptStateTransitionStarted | Should -BeFalse
        }
        
        It "State variables remain reset after multiple operations" {
            # Arrange - reset state
            Reset-StateMachineVariables
            
            # Act - perform multiple operations
            Start-StateTransitions
            Start-StateProcessing -StateName "State1"
            Complete-State -StateName "State1" -Success $true
            
            Start-StateProcessing -StateName "State2"
            Complete-State -StateName "State2" -Success $false
            
            # Reset again
            Reset-StateMachineVariables
            
            # Assert - verify clean state
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $scriptStateStartTimes = Get-StateManagementVar -VarName "StateStartTimes"
            $scriptTotalStartTime = Get-StateManagementVar -VarName "TotalStartTime"
            
            $scriptProcessedStates.Count | Should -Be 0
            $scriptStateStartTimes.Count | Should -Be 0
            $scriptTotalStartTime | Should -BeNullOrEmpty
        }
    }
    
    Context "StateVisualization Module State Reset" {
        BeforeEach {
            Reset-TestLogFile -TestLogPath $script:TestLogPath
        }
        
        It "Reset-VisualizationState clears all visualization variables" {
            # Arrange - set up visualization state
            Set-OutputFormat -OutputFormat "Elaborate"
            Set-TargetState -TargetState "testTarget"
            
            # Verify state is set (need to access via module scope)
            $module = Get-Module StateVisualization
            $currentFormat = & $module { $script:CurrentOutputFormat }
            $targetState = & $module { $script:TargetState }
            $realtimeFormatters = & $module { $script:RealtimeFormatters }
            
            $currentFormat | Should -Be "Elaborate"
            $targetState | Should -Be "testTarget" 
            $realtimeFormatters | Should -Not -BeNullOrEmpty
            
            # Act - reset state
            Reset-VisualizationState
            
            # Assert - verify variables are reset
            $currentFormat = & $module { $script:CurrentOutputFormat }
            $targetState = & $module { $script:TargetState }
            $realtimeFormatters = & $module { $script:RealtimeFormatters }
            
            $currentFormat | Should -Be "Default"
            $targetState | Should -BeNullOrEmpty
            $realtimeFormatters | Should -BeNullOrEmpty
        }
        
        It "Visualization state remains clean after reset" {
            # Arrange - reset state
            Reset-VisualizationState
            
            # Act - set state again and reset
            Set-OutputFormat -OutputFormat "Medium"
            Set-TargetState -TargetState "anotherTarget"
            Reset-VisualizationState
            
            # Assert - verify clean state
            $module = Get-Module StateVisualization
            $currentFormat = & $module { $script:CurrentOutputFormat }
            $targetState = & $module { $script:TargetState }
            $realtimeFormatters = & $module { $script:RealtimeFormatters }
            
            $currentFormat | Should -Be "Default"
            $targetState | Should -BeNullOrEmpty
            $realtimeFormatters | Should -BeNullOrEmpty
        }
    }
    
    Context "Global Variable Cleanup" {
        It "Global Verbose variable can be removed safely" {
            # Arrange - set global variable
            $global:Verbose = $true
            
            # Verify it exists
            Get-Variable -Name "Verbose" -Scope Global | Should -Not -BeNullOrEmpty
            
            # Act - remove it
            Remove-Variable -Name "Verbose" -Scope Global -ErrorAction SilentlyContinue
            
            # Assert - verify it's gone
            { Get-Variable -Name "Verbose" -Scope Global -ErrorAction Stop } | Should -Throw
        }
        
        It "Global variable removal handles non-existent variables gracefully" {
            # Arrange - ensure variable doesn't exist
            Remove-Variable -Name "NonExistentVariable" -Scope Global -ErrorAction SilentlyContinue
            
            # Act & Assert - should not throw
            { Remove-Variable -Name "NonExistentVariable" -Scope Global -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
    
    Context "Complete State Reset Integration" {
        It "Complete reset clears all state across modules" {
            # Arrange - set up state in both modules
            Start-StateTransitions
            Start-StateProcessing -StateName "IntegrationTest"
            Set-OutputFormat -OutputFormat "Elaborate"
            Set-TargetState -TargetState "integrationTarget"
            $global:TestVariable = "shouldBeRemoved"
            
            # Verify state exists
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $module = Get-Module StateVisualization
            $currentFormat = & $module { $script:CurrentOutputFormat }
            
            $scriptProcessedStates.Count | Should -BeGreaterThan 0
            $currentFormat | Should -Be "Elaborate"
            Get-Variable -Name "TestVariable" -Scope Global | Should -Not -BeNullOrEmpty
            
            # Act - perform complete reset (simulate script cleanup)
            Reset-StateMachineVariables
            Reset-VisualizationState
            Remove-Variable -Name "TestVariable" -Scope Global -ErrorAction SilentlyContinue
            
            # Assert - verify all state is clean
            $scriptProcessedStates = Get-StateManagementVar -VarName "ProcessedStates"
            $currentFormat = & $module { $script:CurrentOutputFormat }
            
            $scriptProcessedStates.Count | Should -Be 0
            $currentFormat | Should -Be "Default"
            { Get-Variable -Name "TestVariable" -Scope Global -ErrorAction Stop } | Should -Throw
        }
    }
}

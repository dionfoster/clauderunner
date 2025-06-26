# Pester tests for StateManagement module
BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    $env = Initialize-StandardTestEnvironment -ModulesToImport @("StateManagement") -TestLogPath $script:TestLogPath
}

Describe "State Management Module" {
    BeforeEach {
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
        
        It "Returns default gear icon for unknown state" {
            # Act
            $icon = Get-StateIcon -StateName "unknownstate"
            
            # Assert
            $icon | Should -Be "⚙️ "
        }
    }

    Context "State Tracking" {
        It "Initializes state transitions" {
            # Act
            Start-StateTransitions
            
            # Get internal state through Get-StateSummary
            $summary = Get-StateSummary
            
            # Assert
            $summary.TotalStartTime | Should -Not -BeNullOrEmpty
        }
        
        It "Tracks a complete state lifecycle" {
            # Arrange
            $stateName = "TestState"
            
            # Act - Start state
            Start-StateProcessing -StateName $stateName
            
            # Register an action
            $actionId = Register-StateAction -StateName $stateName -ActionType "Test"
            
            # Complete action successfully
            Complete-StateAction -StateName $stateName -ActionId $actionId -Success $true
            
            # Complete state successfully
            Complete-State -StateName $stateName -Success $true
            
            # Get summary
            $summary = Get-StateSummary
            
            # Assert
            $summary.States[$stateName] | Should -Not -BeNullOrEmpty
            $summary.States[$stateName].Success | Should -BeTrue
            $summary.States[$stateName].Actions[0].Success | Should -BeTrue
            $summary.States[$stateName].Actions[0].Duration | Should -Not -BeNullOrEmpty
        }
    }
}

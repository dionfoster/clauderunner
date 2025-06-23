# Pester tests for Logging state machine visualization
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

# Create separate functions to properly set up the state machine environment
function Setup-StateMachine {
    # Set script-level variables for testing state machine functions
    $script:StateTransitionStarted = $false
    $script:StateStartTimes = @{}
    $script:ActionStartTimes = @{}
    $script:ProcessedStates = @{}
    $script:TotalStartTime = $null
}

Describe "State Machine Visualization" {    BeforeEach {
        # Create a fresh log file for each test
        Reset-LogFile
        
        # Reset state variables
        Reset-StateMachineVariables
    }
    
    # TODO: Add more detailed tests for state machine visualization
    # These tests will need to be carefully structured since they rely on
    # internal state that's not easily accessible from outside the module
    
    It "Get-StateIcon returns the right icon for a state" {
        # Act
        $icon = Get-StateIcon -StateName "dockerready"
        
        # Assert
        $icon | Should -Be "🐳 "
    }
}

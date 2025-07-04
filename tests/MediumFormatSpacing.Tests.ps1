# MediumFormatSpacing.Tests.ps1 - Tests for Medium format spacing between states

BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    Initialize-StandardTestEnvironment -ModulesToImport @("Logging", "StateManagement", "StateVisualization") -TestLogPath $script:TestLogPath -IncludeStateManagement | Out-Null
}

AfterAll {
    # Clean up test log file
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
}

Describe "Medium Format Spacing Tests" {
    
    Context "State Spacing" {
        BeforeEach {
            Reset-TestLogFile -TestLogPath $script:TestLogPath
            # Reset visualization state to ensure clean test runs
            if (Get-Command -Name Reset-VisualizationState -ErrorAction SilentlyContinue) {
                Reset-VisualizationState
            }
        }
        
        It "Should not add spacing before the first state" {
            # Arrange
            Set-OutputFormat -OutputFormat "Medium"
            
            # Act - process first state
            Start-StateProcessing -StateName "FirstState"
            
            # Assert - check log content
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            
            # Should not start with blank line after "STATE DETAILS" section
            $lines = $logContent -split "`r?`n"
            $stateDetailsIndex = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match "STATE DETAILS") {
                    $stateDetailsIndex = $i
                    break
                }
            }
            
            if ($stateDetailsIndex -ge 0) {
                # The line after "────────────────" should be the first state, not a blank line
                $nextContentLine = $lines[$stateDetailsIndex + 2]  # Skip the dashes line
                $nextContentLine | Should -Match "▶ FirstState"
            }
        }
        
        It "Should add blank line before subsequent states" {
            # Arrange
            Set-OutputFormat -OutputFormat "Medium"
            
            # Act - process multiple states
            Start-StateProcessing -StateName "FirstState"
            Start-StateProcessing -StateName "SecondState" -Dependencies @("FirstState")
            Start-StateProcessing -StateName "ThirdState" -Dependencies @("SecondState")
            
            # Assert - check for blank lines between states
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $lines = $logContent -split "`r?`n"
            
            # Find state lines and check for spacing
            $stateLines = @()
            $blankLineBeforeState = @()
            
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match "▶ (SecondState|ThirdState)") {
                    $stateLines += $i
                    # Check if previous line is blank
                    $blankLineBeforeState += ($i -gt 0 -and $lines[$i-1].Trim() -eq "")
                }
            }
            
            # Should have found SecondState and ThirdState
            $stateLines.Count | Should -Be 2
            
            # Both should have blank lines before them
            $blankLineBeforeState[0] | Should -BeTrue  # SecondState
            $blankLineBeforeState[1] | Should -BeTrue  # ThirdState
        }
        
        It "Should maintain proper spacing in template format" {
            # Arrange
            Set-OutputFormat -OutputFormat "Medium"
            
            # Act - simulate the states from the template
            Start-StateProcessing -StateName "firstState"
            Start-StateProcessing -StateName "secondState" -Dependencies @("firstState")
            Start-StateProcessing -StateName "thirdState" -Dependencies @("secondState")
            
            # Assert - verify spacing matches template expectations
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            
            # Should have proper state headers with spacing
            $logContent | Should -Match "▶ firstState\r?\n.*\r?\n▶ secondState"
            $logContent | Should -Match "▶ secondState.*\r?\n.*\r?\n▶ thirdState"
        }
    }
    
    Context "State Counter Reset" {
        BeforeEach {
            Reset-TestLogFile -TestLogPath $script:TestLogPath
        }
        
        It "Should reset state counter when Reset-VisualizationState is called" {
            # Arrange
            Set-OutputFormat -OutputFormat "Medium"
            Start-StateProcessing -StateName "State1"
            Start-StateProcessing -StateName "State2"
            
            # Act - reset visualization state
            Reset-VisualizationState
            Set-OutputFormat -OutputFormat "Medium"  # Set format again after reset
            
            # Clear log for next test
            Reset-TestLogFile -TestLogPath $script:TestLogPath
            
            # Process first state again
            Start-StateProcessing -StateName "NewFirstState"
            
            # Assert - should not add spacing before first state after reset
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            $lines = $logContent -split "`r?`n"
            
            # Find the state line
            $stateLine = $lines | Where-Object { $_ -match "▶ NewFirstState" } | Select-Object -First 1
            $stateLineIndex = [array]::IndexOf($lines, $stateLine)
            
            if ($stateLineIndex -gt 0) {
                # Previous line should not be blank (it should be the dashes or other content)
                $lines[$stateLineIndex - 1].Trim() | Should -Not -Be ""
            }
        }
    }
}

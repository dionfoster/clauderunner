BeforeAll {
    # Import required modules
    $modulePath = Join-Path $PSScriptRoot ".." "modules"
    Import-Module (Join-Path $modulePath "Logging.psm1") -Force
    Import-Module (Join-Path $modulePath "StateVisualization.psm1") -Force
    Import-Module (Join-Path $modulePath "OutputFormatters.psm1") -Force
    
    # Create a test log file
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    Set-LogPath -Path $script:TestLogPath
    
    function Reset-TestLogFile {
        param([string]$TestLogPath)
        if (Test-Path $TestLogPath) {
            Remove-Item $TestLogPath -Force
        }
        # Create empty file
        New-Item -Path $TestLogPath -ItemType File -Force | Out-Null
    }
    
    function Get-SystemLogLines {
        param([string]$TestLogPath)
        if (-not (Test-Path $TestLogPath)) { return @() }
        
        $content = Get-Content -Path $TestLogPath
        $systemLines = @()
        foreach ($line in $content) {
            if ($line -match '\[SYSTEM\]\s*(.*)$') {
                # Include empty lines as single spaces for spacing verification
                $extractedContent = $matches[1]
                if ($extractedContent -eq "") {
                    $systemLines += " "  # Represent empty lines as single space
                } else {
                    $systemLines += $extractedContent
                }
            }
        }
        return $systemLines
    }
}

Describe "Medium Output Format Complete Tests" {
    
    Context "Template Compliance" {
        BeforeEach {
            Reset-TestLogFile -TestLogPath $script:TestLogPath
            if (Get-Command -Name Reset-VisualizationState -ErrorAction SilentlyContinue) {
                Reset-VisualizationState
            }
        }
        
        It "Should produce output that matches template structure" {
            # Arrange
            Set-OutputFormat -OutputFormat "Medium"
            Set-TargetState -TargetState "apiReady"
            
            # Act - simulate the complete flow
            Start-StateTransitions  # Header
            Show-ExecutionFlow -TargetStateName "apiReady" -Config @{
                states = @{
                    dockerStartup = @{ needs = @() }
                    dockerReady = @{ needs = @("dockerStartup") }
                    apiReady = @{ needs = @("dockerReady") }
                }
            }
            
            Start-StateProcessing -StateName "dockerStartup"
            Complete-State -StateName "dockerStartup" -Success $true
            
            Start-StateProcessing -StateName "dockerReady" -Dependencies @("dockerStartup")
            Complete-State -StateName "dockerReady" -Success $true
            
            Start-StateProcessing -StateName "apiReady" -Dependencies @("dockerReady") 
            Complete-State -StateName "apiReady" -Success $true
            
            Write-StateSummary
            
            # Assert - Get the system log lines (actual output)
            $systemLines = Get-SystemLogLines -TestLogPath $script:TestLogPath
            
            # Verify header structure
            $systemLines[0] | Should -Match "╔═+"
            $systemLines[1] | Should -Match "║.*🚀 Claude Task Runner.*║"
            $systemLines[2] | Should -Match "║.*Target: apiReady.*║"
            $systemLines[3] | Should -Match "╚═+"
            
            # Verify execution flow section
            $systemLines | Should -Contain "📊 EXECUTION FLOW"
            $systemLines | Should -Contain "─────────────────"
            
            # Verify state details section appears
            $systemLines | Should -Contain "🔍 STATE DETAILS"
            $systemLines | Should -Contain "────────────────"
            
            # Verify states are present
            $systemLines | Should -Contain "▶ dockerStartup"
            $systemLines | Should -Contain "▶ dockerReady (depends: dockerStartup)"
            $systemLines | Should -Contain "▶ apiReady (depends: dockerReady)"
            
            # Verify summary appears
            $summaryLine = $systemLines | Where-Object { $_ -match "📈 SUMMARY:" }
            $summaryLine | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper blank line spacing between sections" {
            # Arrange
            Set-OutputFormat -OutputFormat "Medium"
            Set-TargetState -TargetState "testTarget"
            
            # Act
            Start-StateTransitions
            Show-ExecutionFlow -TargetStateName "testTarget" -Config @{
                states = @{
                    firstState = @{ needs = @() }
                    secondState = @{ needs = @("firstState") }
                }
            }
            
            Start-StateProcessing -StateName "firstState"
            Complete-State -StateName "firstState" -Success $true
            
            Start-StateProcessing -StateName "secondState" -Dependencies @("firstState")
            Complete-State -StateName "secondState" -Success $true
            
            Write-StateSummary
            
            # Assert
            $systemLines = Get-SystemLogLines -TestLogPath $script:TestLogPath
            
            # Find the indices of key sections
            $stateDetailsIndex = -1
            $firstStateIndex = -1
            $secondStateIndex = -1
            $summaryIndex = -1
            
            for ($i = 0; $i -lt $systemLines.Count; $i++) {
                if ($systemLines[$i] -eq "🔍 STATE DETAILS") { $stateDetailsIndex = $i }
                if ($systemLines[$i] -eq "▶ firstState") { $firstStateIndex = $i }
                if ($systemLines[$i] -eq "▶ secondState (depends: firstState)") { $secondStateIndex = $i }
                if ($systemLines[$i] -match "📈 SUMMARY:") { $summaryIndex = $i }
            }
            
            # Verify blank line before STATE DETAILS section
            ($stateDetailsIndex -gt 0) | Should -BeTrue
            $systemLines[$stateDetailsIndex - 1] | Should -BeExactly " "
            
            # Verify blank line before second state
            ($secondStateIndex -gt $firstStateIndex + 1) | Should -BeTrue
            $systemLines[$secondStateIndex - 1] | Should -BeExactly " "
            
            # Verify blank line before summary
            ($summaryIndex -gt 0) | Should -BeTrue
            $systemLines[$summaryIndex - 1] | Should -BeExactly " "
        }
    }
}

# Pester tests for State Visualization module
BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    $env = Initialize-StandardTestEnvironment -ModulesToImport @("Logging", "StateManagement", "StateVisualization") -TestLogPath $script:TestLogPath -IncludeStateManagement -IncludeCommonMocks
}

AfterAll {
    # Clean up test log file
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
}

Describe "State Visualization Module" {
    Context "State Transitions" {
        BeforeEach {
            # Use standardized BeforeEach setup
            Reset-TestLogFile -TestLogPath $script:TestLogPath
            if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
                Reset-StateMachineVariables
            }
        }
        
        It "Initializes state transitions" {
            # Act
            Start-StateTransitions
            
            # Assert
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "STATE TRANSITIONS:"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
        
        It "Starts processing a state with no dependencies" {
            # Act
            Start-StateProcessing -StateName "TestState"
            
            # Assert
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ TestState"
                $logContent | Should -Match "Dependencies: none"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
        
        It "Starts processing a state with dependencies" {
            # Act
            Start-StateProcessing -StateName "TestState" -Dependencies @("Dep1", "Dep2")
            
            # Assert
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "┌─ STATE: 🔄 ⚙️ TestState"
                $logContent | Should -Match "Dependencies: Dep1 ✓, Dep2 ✓"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
        
        It "Records a state check" {
            # Act
            Write-StateCheck -CheckType "Command" -CheckDetails "docker --version"
            
            # Assert
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "Check: 🔍 Command check \(docker --version\)"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
        
        It "Records a successful state check result" {
            # Arrange - Setup a state first
            Start-StateProcessing -StateName "TestState"
            
            # Act
            Write-StateCheckResult -IsReady $true -CheckType "Command" -AdditionalInfo "Docker 20.10.7"
            
            # Assert
            Assert-LogContent -TestLogPath $script:TestLogPath -Pattern "Result: ✅ READY \(Docker 20.10.7\)"
        }
        
        It "Records a failed state check result" {
            # Arrange - Setup a state first
            Start-StateProcessing -StateName "TestState"
            
            # Act
            Write-StateCheckResult -IsReady $false -CheckType "Command" -AdditionalInfo "Command not found"
            
            # Assert
            Assert-LogContent -TestLogPath $script:TestLogPath -Pattern "Result: ❌ NOT READY \(proceeding with actions\)"
        }
    }
    
    Context "State Actions" {
        BeforeEach {
            # Use standardized BeforeEach setup
            Reset-TestLogFile -TestLogPath $script:TestLogPath
            if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
                Reset-StateMachineVariables
            }
            
            # Setup test state
            Start-StateProcessing -StateName "TestState"
        }
        
        It "Starts actions section" {
            # Act
            Start-StateActions
            
            # Assert
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "Actions:"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
        
        It "Records start of an action" {
            # Act
            $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "npm install" -Description "Installing dependencies"
            
            # Assert
            $actionId | Should -Not -BeNullOrEmpty
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "Command: Installing dependencies \(npm install\)"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
        
        It "Records successful action completion" {
            # Act
            $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "npm install"
            Complete-StateAction -StateName "TestState" -ActionId $actionId -Success $true
            
            # Assert
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "Status: ✓"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
        
        It "Records failed action completion" {
            # Act
            $actionId = Start-StateAction -StateName "TestState" -ActionType "Command" -ActionCommand "npm install"
            Complete-StateAction -StateName "TestState" -ActionId $actionId -Success $false -ErrorMessage "Package not found"
            
            # Assert
            Assert-LogContent -TestLogPath $script:TestLogPath -Pattern "Status: ✗ FAILED.*Error: Package not found"
        }
    }
    
    Context "State Completion" {
        BeforeEach {
            # Use standardized BeforeEach setup
            Reset-TestLogFile -TestLogPath $script:TestLogPath
            if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
                Reset-StateMachineVariables
            }
            
            # Setup test states
            Start-StateProcessing -StateName "TestState"
            Start-StateProcessing -StateName "TestState2"
        }
        
        It "Records successful state completion" {
            # Act
            Complete-State -StateName "TestState" -Success $true
            
            # Assert
            Assert-LogContent -TestLogPath $script:TestLogPath -Pattern $global:CommonTestPatterns.ResultCompleted
        }
        
        It "Records failed state completion" {
            # Act
            Complete-State -StateName "TestState" -Success $false -ErrorMessage "Test error"
            
            # Assert
            Assert-LogContent -TestLogPath $script:TestLogPath -Pattern $global:CommonTestPatterns.ResultFailed
            Assert-LogContent -TestLogPath $script:TestLogPath -Pattern "Error: Test error"
        }
        
        It "Shows state summary with mixed results" {
            # Act
            # Initialize state transitions first
            Start-StateTransitions
            
            # Set up test states with the required data
            $global:TotalStartTime = Get-Date
            
            # Process states with custom state data for summary
            $global:ProcessedStates = @{
                "TestState" = @{
                    "Success" = $true
                    "Duration" = New-TimeSpan -Seconds 5
                }
                "TestState2" = @{
                    "Success" = $false
                    "ErrorMessage" = "Test error"
                    "Duration" = New-TimeSpan -Seconds 3
                }
            }
            
            # Now run summary
            Write-StateSummary
            
            # Assert
            Assert-LogContent -TestLogPath $script:TestLogPath -Pattern $global:CommonTestPatterns.ExecutionSummary
            Assert-LogContent -TestLogPath $script:TestLogPath -Pattern "Total time:"
        }
    }
    
    Context "Execution Flow" {
        BeforeEach {
            # Use standardized BeforeEach setup
            Reset-TestLogFile -TestLogPath $script:TestLogPath
            if (Get-Command -Name Reset-StateMachineVariables -ErrorAction SilentlyContinue) {
                Reset-StateMachineVariables
            }
            
            # Set output format to Medium to trigger execution flow
            Set-OutputFormat -OutputFormat "Medium"
        }
        
        It "Shows execution flow with correct flowing arrows" {
            # Arrange
            $mockConfig = @{
                states = @{
                    "firstState" = @{
                        needs = @()
                    }
                    "secondState" = @{
                        needs = @("firstState")
                    }
                    "thirdState" = @{
                        needs = @("secondState")
                    }
                }
            }
            
            # Act
            Show-ExecutionFlow -TargetStateName "thirdState" -Config $mockConfig
            
            # Assert
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "📊 EXECUTION FLOW"
                $logContent | Should -Match "\[firstState\] ➜ \[secondState\] ➜ \[thirdState\]"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
    }
}

# Pester tests for State Visualization module
BeforeAll {
    # Set up test log path
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    
    # Import modules directly in dependency order
    Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force
    Import-Module "$PSScriptRoot\..\modules\StateManagement.psm1" -Force
    Import-Module "$PSScriptRoot\..\modules\StateVisualization.psm1" -Force
    
    # Initialize log file
    New-Item -Path $script:TestLogPath -ItemType File -Force | Out-Null
    Logging\Set-LogPath -Path $script:TestLogPath
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
            # Act
            Write-StateCheckResult -IsReady $true -CheckType "Command" -AdditionalInfo "Docker 20.10.7"
            
            # Assert
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "Status: ✅ Ready - Command \(Docker 20.10.7\)"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
        
        It "Records a failed state check result" {
            # Act
            Write-StateCheckResult -IsReady $false -CheckType "Command" -AdditionalInfo "Command not found"
            
            # Assert
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "Status: ❌ Not Ready - Command \(Command not found\)"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
    }
    
    Context "State Actions" {
        BeforeEach {
            # Create a fresh log file for each test
            Reset-LogFile
            
            # Re-import modules to ensure fresh state
            Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force
            Import-Module "$PSScriptRoot\..\modules\StateManagement.psm1" -Force
            Import-Module "$PSScriptRoot\..\modules\StateVisualization.psm1" -Force
            
            # Set the log path for tests
            Set-LogPath -Path $script:TestLogPath
            
            # Reset state machine variables to ensure clean test state
            Reset-StateMachineVariables
            
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
                $logContent | Should -Match "⏳ Command: Installing dependencies \(npm install\)"
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
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "Status: ✗ FAILED.*Error: Package not found"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
    
    }
    
    Context "State Completion" {
        
        BeforeEach {
            # Create a fresh log file for each test
            Reset-LogFile
            
            # Re-import modules to ensure fresh state
            Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force
            Import-Module "$PSScriptRoot\..\modules\StateManagement.psm1" -Force
            Import-Module "$PSScriptRoot\..\modules\StateVisualization.psm1" -Force
            
            # Set the log path for tests
            Set-LogPath -Path $script:TestLogPath
            
            # Reset state machine variables to ensure clean test state
            Reset-StateMachineVariables
            
            # Setup test states
            Start-StateProcessing -StateName "TestState"
            Start-StateProcessing -StateName "TestState2"
        }
        
        It "Records successful state completion" {
            # Act
            Complete-State -StateName "TestState" -Success $true
            
            # Assert
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "Result: ✅ COMPLETED"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
        
        It "Records failed state completion" {
            # Act
            Complete-State -StateName "TestState" -Success $false -ErrorMessage "Test error"
            
            # Assert
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "Result: ❌ FAILED"
                $logContent | Should -Match "Error: Test error"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
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
            if (Test-Path $script:TestLogPath) {
                $logContent = Get-Content -Path $script:TestLogPath -Raw
                $logContent | Should -Match "EXECUTION SUMMARY"
                $logContent | Should -Match "Total time:"
            } else {
                "Log file doesn't exist" | Should -BeNullOrEmpty
            }
        }
    }
}

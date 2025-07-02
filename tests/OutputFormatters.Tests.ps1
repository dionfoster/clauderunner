# Pester tests for Output Formatters module
BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    Initialize-StandardTestEnvironment -ModulesToImport @("Logging", "StateManagement", "OutputFormatters") -TestLogPath $script:TestLogPath
}

AfterAll {
    # Clean up test log file
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
}

Describe "Output Formatters Module" {
    Context "State Counting Bug Regression Test" {
        BeforeEach {
            # Use standardized BeforeEach setup
            Reset-TestLogFile -TestLogPath $script:TestLogPath
        }
        
        It "Medium format shows correct state count for single successful state" {
            # Arrange - Create a summary with exactly one successful state
            $testSummary = @{
                States = @{
                    "SingleState" = @{
                        Success = $true
                        Duration = 2.5
                        Actions = @()
                    }
                }
            }
            
            # Act - Format using Medium output
            $result = Format-MediumOutput -Summary $testSummary -Success $true -ErrorMessage "" -Duration 5.0
            
            # Assert - Should show "1/1 states completed" not something like "6/1"
            $result | Should -Match "📈 SUMMARY: ✅ 1/1 states completed successfully in 5s"
        }
        
        It "Medium format shows correct state count for single failed state" {
            # Arrange - Create a summary with exactly one failed state
            $testSummary = @{
                States = @{
                    "SingleState" = @{
                        Success = $false
                        Duration = 1.0
                        Actions = @()
                        ErrorMessage = "Test error"
                    }
                }
            }
            
            # Act - Format using Medium output
            $result = Format-MediumOutput -Summary $testSummary -Success $false -ErrorMessage "Test error" -Duration 3.0
            
            # Assert - Should show "0/1 states completed" not something like "6/1"
            $result | Should -Match "📈 SUMMARY: ❌ 0/1 states completed successfully in 3s"
        }
        
        It "Medium format shows correct state count for multiple mixed states" {
            # Arrange - Create a summary with multiple states
            $testSummary = @{
                States = @{
                    "SuccessState1" = @{
                        Success = $true
                        Duration = 1.0
                        Actions = @()
                    }
                    "SuccessState2" = @{
                        Success = $true
                        Duration = 2.0
                        Actions = @()
                    }
                    "FailedState" = @{
                        Success = $false
                        Duration = 0.5
                        Actions = @()
                        ErrorMessage = "Failed"
                    }
                }
            }
            
            # Act - Format using Medium output
            $result = Format-MediumOutput -Summary $testSummary -Success $false -ErrorMessage "One or more states failed" -Duration 8.0
            
            # Assert - Should show "2/3 states completed"
            $result | Should -Match "📈 SUMMARY: ❌ 2/3 states completed successfully in 8s"
        }
        
        It "Medium format shows correct state count for all successful states" {
            # Arrange - Create a summary with multiple successful states
            $testSummary = @{
                States = @{
                    "State1" = @{
                        Success = $true
                        Duration = 1.0
                        Actions = @()
                    }
                    "State2" = @{
                        Success = $true
                        Duration = 2.0
                        Actions = @()
                    }
                    "State3" = @{
                        Success = $true
                        Duration = 1.5
                        Actions = @()
                    }
                }
            }
            
            # Act - Format using Medium output
            $result = Format-MediumOutput -Summary $testSummary -Success $true -ErrorMessage "" -Duration 6.0
            
            # Assert - Should show "3/3 states completed"
            $result | Should -Match "📈 SUMMARY: ✅ 3/3 states completed successfully in 6s"
        }
        
        It "Medium format shows correct state count for all failed states" {
            # Arrange - Create a summary with multiple failed states
            $testSummary = @{
                States = @{
                    "State1" = @{
                        Success = $false
                        Duration = 1.0
                        Actions = @()
                        ErrorMessage = "Error 1"
                    }
                    "State2" = @{
                        Success = $false
                        Duration = 2.0
                        Actions = @()
                        ErrorMessage = "Error 2"
                    }
                }
            }
            
            # Act - Format using Medium output
            $result = Format-MediumOutput -Summary $testSummary -Success $false -ErrorMessage "All states failed" -Duration 4.0
            
            # Assert - Should show "0/2 states completed"
            $result | Should -Match "📈 SUMMARY: ❌ 0/2 states completed successfully in 4s"
        }
    }
    
    Context "Output Format Validation" {
        BeforeEach {
            Reset-TestLogFile -TestLogPath $script:TestLogPath
        }
        
        It "Simple format produces expected output structure" {
            # Arrange
            $testSummary = @{
                States = @{
                    "TestState" = @{
                        Success = $true
                        Duration = [timespan]::FromSeconds(2.0)
                        Actions = @()
                    }
                }
                StateStartTimes = @{
                    "TestState" = Get-Date
                }
                TargetState = "TestState"
            }
            
            # Act
            $result = Format-SimpleOutput -Summary $testSummary -Success $true -ErrorMessage "" -Duration 5.0
            
            # Assert
            ($result -join "`n") | Should -Match "Status: SUCCESS \(1/1 completed in 5s\)"
        }
        
        It "Default format produces expected output structure" {
            # Arrange
            $testSummary = @{
                States = @{
                    "TestState" = @{
                        Success = $true
                        Duration = [timespan]::FromSeconds(2.0)
                        Actions = @()
                    }
                }
                StateStartTimes = @{
                    "TestState" = Get-Date
                }
            }
            
            # Act
            $result = Format-DefaultOutput -Summary $testSummary -Success $true -ErrorMessage "" -Duration 5.0
            
            # Assert
            $result | Should -Contain "EXECUTION SUMMARY"
            ($result -join "`n") | Should -Match "✓ TestState"
        }
        
        It "Elaborate format produces expected output structure" {
            # Arrange
            $testSummary = @{
                States = @{
                    "TestState" = @{
                        Success = $true
                        Duration = [timespan]::FromSeconds(2.0)
                        Actions = @()
                    }
                }
                StateStartTimes = @{
                    "TestState" = Get-Date
                }
            }
            
            # Act
            $result = Format-ElaborateOutput -Summary $testSummary -Success $true -ErrorMessage "" -Duration 5.0
            
            # Assert
            ($result -join "`n") | Should -Match "STATE PROCESSING COMPLETE: MISSION ACCOMPLISHED"
            ($result -join "`n") | Should -Match "Completion Time:"
        }
    }
}

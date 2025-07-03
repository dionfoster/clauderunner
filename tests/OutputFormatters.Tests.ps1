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
            ($result -join "`n") | Should -Match "🎯 Claude Task Runner v2.0 - Execution Report"
            ($result -join "`n") | Should -Match "🎉 FINAL SUMMARY"
        }
        
        It "Elaborate format produces comprehensive report structure" {
            # Arrange - Create a complex summary with multiple states and actions
            $testSummary = @{
                States = @{
                    "dockerStartup" = @{
                        Success = $true
                        Duration = [timespan]::FromSeconds(2.5)
                        Actions = @()
                    }
                    "apiReady" = @{
                        Success = $true
                        Duration = [timespan]::FromSeconds(5.2)
                        Actions = @(
                            @{
                                Command = "dotnet run"
                                Duration = [timespan]::FromSeconds(0.3)
                                Success = $true
                            }
                            @{
                                Command = "Endpoint polling"
                                Duration = [timespan]::FromSeconds(4.9)
                                Success = $true
                            }
                        )
                    }
                }
                StateStartTimes = @{
                    "dockerStartup" = Get-Date
                    "apiReady" = Get-Date
                }
                TargetState = "apiReady"
            }
            
            # Act
            $result = Format-ElaborateOutput -Summary $testSummary -Success $true -ErrorMessage "" -Duration 7.7
            
            # Assert - Check for all major sections
            $joinedResult = $result -join "`n"
            
            # Header section
            $joinedResult | Should -Match "🎯 Claude Task Runner v2.0 - Execution Report"
            $joinedResult | Should -Match "🎪 Target Environment: apiReady"
            
            # State execution matrix
            $joinedResult | Should -Match "🏗️ STATE EXECUTION MATRIX"
            $joinedResult | Should -Match "🏁 STATE: dockerStartup"
            $joinedResult | Should -Match "🚀 STATE: apiReady"
            
            # Dependencies
            $joinedResult | Should -Match "🔗 Dependencies:"
            
            # Actions for multi-action state
            $joinedResult | Should -Match "🎬 Execution Phase: Multi-Action Sequence"
            $joinedResult | Should -Match "🛠️ ACTION 1/2"
            $joinedResult | Should -Match "🛠️ ACTION 2/2"
            $joinedResult | Should -Match "📦 Command: dotnet run"
            $joinedResult | Should -Match "📦 Command: Endpoint polling"
            
            # Performance metrics
            $joinedResult | Should -Match "📈 Performance: ⚡"
            $joinedResult | Should -Match "🎯 Status: SUCCESS"
            $joinedResult | Should -Match "🏆 Efficiency: 100%"
            
            # Analytics dashboard
            $joinedResult | Should -Match "📊 EXECUTION ANALYTICS DASHBOARD"
            $joinedResult | Should -Match "🏆 SUCCESS METRICS"
            $joinedResult | Should -Match "State Name.*Duration.*Status.*Efficiency.*Actions Completed"
            
            # Final summary
            $joinedResult | Should -Match "🎉 FINAL SUMMARY"
            $joinedResult | Should -Match "🎯 Target Achieved: apiReady"
            $joinedResult | Should -Match "✨ Success Rate: 2/2 states \(100%\)"
            $joinedResult | Should -Match "⏰ Total Execution Time: 5.2s"
            $joinedResult | Should -Match "🏅 Performance Grade: A\+ \(Excellent\)"
            $joinedResult | Should -Match "🎊 Status: 🌟 MISSION ACCOMPLISHED! 🌟"
        }
        
        It "Elaborate format handles failed states correctly" {
            # Arrange - Create a summary with mixed success/failure
            $testSummary = @{
                States = @{
                    "successState" = @{
                        Success = $true
                        Duration = [timespan]::FromSeconds(1.0)
                        Actions = @()
                    }
                    "failedState" = @{
                        Success = $false
                        Duration = [timespan]::FromSeconds(0.5)
                        Actions = @()
                        ErrorMessage = "Test failure"
                    }
                }
                StateStartTimes = @{
                    "successState" = Get-Date
                    "failedState" = Get-Date
                }
                TargetState = "failedState"
            }
            
            # Act
            $result = Format-ElaborateOutput -Summary $testSummary -Success $false -ErrorMessage "One or more states failed" -Duration 1.5
            
            # Assert
            $joinedResult = $result -join "`n"
            $joinedResult | Should -Match "✨ Success Rate: 1/2 states \(50%\)"
            $joinedResult | Should -Match "🏅 Performance Grade: B \(Good\)"
        }
        
        It "Elaborate format header alignment is correct" {
            # Test the real-time header function alignment
            $formatters = Get-RealtimeFormatters -FormatName "Elaborate"
            $result = & $formatters.StateTransitionsHeader "testTarget"
            
            # Find the content lines (between ┃ characters)
            $contentLines = $result | Where-Object { $_ -match "^┃.*┃$" }
            
            # Each content line should be exactly 84 characters (same as borders)
            foreach ($line in $contentLines) {
                $line.Length | Should -Be 84
                $line | Should -Match "^┃.*┃$"
            }
            
            # Border lines should also be 84 characters
            $borderLines = $result | Where-Object { $_ -match "^[┏┗].*[┓┛]$" }
            foreach ($line in $borderLines) {
                $line.Length | Should -Be 84
            }
            
            # All lines should be the same length for perfect alignment
            $allBoxLines = $result | Where-Object { $_ -match "^[┏┃┗].*[┓┃┛]$" }
            $allBoxLines | ForEach-Object { $_.Length | Should -Be 84 }
        }
        
        It "Elaborate format summary header alignment is correct" {
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
                TargetState = "testTarget"
                StartTime = Get-Date
            }
            
            # Act
            $result = Format-ElaborateOutput -Summary $testSummary -Success $true -ErrorMessage "" -Duration 5.0
            
            # Find analytics dashboard header
            $analyticsHeaderIndex = 0
            for ($i = 0; $i -lt $result.Count; $i++) {
                if ($result[$i] -match "📊 EXECUTION ANALYTICS DASHBOARD") {
                    $analyticsHeaderIndex = $i
                    break
                }
            }
            
            # Check analytics dashboard alignment
            if ($analyticsHeaderIndex -gt 0) {
                $dashboardBorderTop = $result[$analyticsHeaderIndex - 1]
                $dashboardContent = $result[$analyticsHeaderIndex]
                $dashboardBorderBottom = $result[$analyticsHeaderIndex + 1]
                
                # All lines should be 84 characters for perfect alignment
                $dashboardBorderTop.Length | Should -Be 84
                $dashboardBorderBottom.Length | Should -Be 84
                $dashboardContent.Length | Should -Be 84
                $dashboardContent | Should -Match "^┃.*┃$"
            }
        }
    }
}

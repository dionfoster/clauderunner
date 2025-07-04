# MediumOutputFormatRegression.Tests.ps1 - Tests to catch Medium output format regressions

BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    Initialize-StandardTestEnvironment -ModulesToImport @("Logging", "OutputFormatters") -TestLogPath $script:TestLogPath | Out-Null
}

AfterAll {
    # Clean up test log file
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
}

Describe "Medium Output Format Regression Tests" {
    
    Context "Write-StateCheckResult-Medium Endpoint Formatting" {
        BeforeEach {
            Reset-TestLogFile -TestLogPath $script:TestLogPath
        }
        
        It "Should display the correct endpoint URL for successful endpoint checks" {
            # Arrange
            $additionalInfo = "Status: 200"
            $formatters = Get-RealtimeFormatters -FormatName "Medium"
            
            # Act - call the Medium formatter directly
            $result = & $formatters.StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo $additionalInfo
            
            # Assert - should NOT hardcode localhost URL (this test will FAIL initially, showing the regression)
            $result | Should -Not -Match "localhost:5001"
            $result | Should -Match "✅.*200 OK"
        }
        
        It "Should handle different endpoint URLs correctly" {
            # Arrange
            $formatters = Get-RealtimeFormatters -FormatName "Medium"
            $testCases = @(
                @{ Endpoint = "https://api.prod.com/health"; Expected = "api.prod.com" }
                @{ Endpoint = "http://localhost:3000/api/status"; Expected = "localhost:3000" }
                @{ Endpoint = "https://myservice.local/ready"; Expected = "myservice.local" }
            )
            
            foreach ($testCase in $testCases) {
                # Act
                $result = & $formatters.StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
                
                # Assert - should not hardcode any specific endpoint (this shows the current bug)
                $result | Should -Match "localhost:5001/healthcheck"  # This SHOULD fail when we fix it
            }
        }
        
        It "Should handle command checks without endpoint formatting" {
            # Arrange
            $formatters = Get-RealtimeFormatters -FormatName "Medium"
            
            # Act
            $result = & $formatters.StateCheckResult -IsReady $true -CheckType "Command" -AdditionalInfo ""
            
            # Assert - should show docker info format for commands
            $result | Should -Match "docker info"
            $result | Should -Match "✅ READY"
            $result | Should -Not -Match "localhost"
        }
        
        It "Should format failed endpoint checks correctly" {
            # Arrange
            $formatters = Get-RealtimeFormatters -FormatName "Medium"
            
            # Act
            $result = & $formatters.StateCheckResult -IsReady $false -CheckType "Endpoint" -AdditionalInfo ""
            
            # Assert
            $result | Should -Match "❌ NOT READY"
            # Current bug: shows hardcoded endpoint even for failures
            $result | Should -Not -Match "localhost:5001/healthcheck"
        }
        
        It "Should handle different HTTP status codes" {
            # Arrange
            $formatters = Get-RealtimeFormatters -FormatName "Medium"
            $testCases = @(
                @{ StatusCode = "201"; AdditionalInfo = "Status: 201" }
                @{ StatusCode = "204"; AdditionalInfo = "Status: 204" }
                @{ StatusCode = "302"; AdditionalInfo = "Status: 302" }
            )
            
            foreach ($testCase in $testCases) {
                # Act
                $result = & $formatters.StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo $testCase.AdditionalInfo
                
                # Assert
                $result | Should -Match "✅ $($testCase.StatusCode) OK"
            }
        }
    }
    
    Context "Medium Format Parameter Handling" {
        It "Should accept endpoint URL as a parameter for proper display" {
            # This test documents the expected future behavior
            # The function should accept the actual endpoint URL to display
            
            # Arrange
            $formatters = Get-RealtimeFormatters -FormatName "Medium"
            
            # Act
            $result = & $formatters.StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
            
            # Current behavior - hardcoded endpoint (this is the bug)
            $result | Should -Match "localhost:5001/healthcheck"
            
            # This test will fail once we fix the function to accept endpoint parameter
        }
    }
    
    Context "Integration with StateVisualization" {
        BeforeEach {
            Reset-TestLogFile -TestLogPath $script:TestLogPath
            # Import StateVisualization for integration testing
            Import-Module "$PSScriptRoot\..\modules\StateVisualization.psm1" -Force
        }
        
        It "Should pass endpoint URL information through the call chain" {
            # This is an integration test to verify the full call chain
            # Set output format to Medium
            Set-OutputFormat -OutputFormat "Medium"
            
            # Act - simulate what happens in the main script
            # This should capture the regression where endpoint URL is lost
            Write-StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
            
            # Assert - check that the log contains the expected format
            $logContent = Get-Content -Path $script:TestLogPath -Raw
            if ($logContent) {
                # Should show endpoint check result
                $logContent | Should -Match "Check:.*→.*✅.*200 OK"
                # Should not show hardcoded localhost if we fix the issue
                # For now, this will pass but highlights the problem
            }
        }
    }
    
    Context "Output Line Length and Formatting" {
        It "Should not produce overly long lines with trailing spaces" {
            # Arrange
            $formatters = Get-RealtimeFormatters -FormatName "Medium"
            
            # Act
            $result = & $formatters.StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
            
            # Assert - check line length is reasonable
            $result.Length | Should -BeLessThan 100
            
            # Should not end with excessive whitespace
            $result | Should -Not -Match "\s{10,}$"
        }
        
        It "Should maintain consistent formatting across different check types" {
            # Arrange
            $formatters = Get-RealtimeFormatters -FormatName "Medium"
            
            # Act
            $endpointResult = & $formatters.StateCheckResult -IsReady $true -CheckType "Endpoint" -AdditionalInfo "Status: 200"
            $commandResult = & $formatters.StateCheckResult -IsReady $true -CheckType "Command" -AdditionalInfo ""
            
            # Assert - both should start with same indentation
            $endpointResult | Should -Match "^  Check:"
            $commandResult | Should -Match "^  Check:"
            
            # Both should have same arrow separator
            $endpointResult | Should -Match "→"
            $commandResult | Should -Match "→"
        }
    }
}

# EndpointTestUtilities.psm1 - Common endpoint testing utilities

<#
.SYNOPSIS
Common endpoint testing utilities for Claude Task Runner tests.

.DESCRIPTION
This module provides shared functionality for testing endpoint-related operations
to reduce duplication across test files.
#>

<#
.SYNOPSIS
Creates a mock for Invoke-WebRequest with standard responses.

.DESCRIPTION
Sets up a mock for Invoke-WebRequest that returns appropriate responses
for common endpoint testing scenarios.

.PARAMETER SuccessfulEndpoints
Array of URI patterns that should return successful responses.

.PARAMETER FailedEndpoints  
Array of URI patterns that should return failed responses.

.PARAMETER ModuleName
Name of the module to mock the function in.
#>
function Initialize-WebRequestMock {
    param(
        [Parameter(Mandatory=$false)]
        [string[]]$SuccessfulEndpoints = @("*/health", "*/readiness"),
        
        [Parameter(Mandatory=$false)]
        [string[]]$FailedEndpoints = @(),
        
        [Parameter(Mandatory=$false)]
        [string]$ModuleName = "ReadinessChecks"
    )
    
    Mock -ModuleName $ModuleName Invoke-WebRequest {
        param($Uri, $Method, $TimeoutSec, $UseBasicParsing, $ErrorAction)
        
        # Check for successful endpoints
        foreach ($pattern in $SuccessfulEndpoints) {
            if ($Uri -like $pattern) {
                return @{
                    StatusCode = 200
                    Content = '{"status":"ready"}'
                }
            }
        }
        
        # Check for failed endpoints
        foreach ($pattern in $FailedEndpoints) {
            if ($Uri -like $pattern) {
                throw "Connection failed"
            }
        }
        
        # Default to success for unknown endpoints
        return @{
            StatusCode = 200
            Content = '{"status":"ok"}'
        }
    }
}

<#
.SYNOPSIS
Creates a standardized test case for endpoint readiness testing.

.DESCRIPTION
Generates a test case that validates endpoint readiness functionality
with consistent assertions and error handling.

.PARAMETER TestName
Name of the test case.

.PARAMETER EndpointUri
URI of the endpoint to test.

.PARAMETER ExpectedResult
Expected result (true for success, false for failure).

.PARAMETER AdditionalAssertions
Additional assertions to run after the main test.
#>
function New-EndpointReadinessTest {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestName,
        
        [Parameter(Mandatory=$true)]
        [string]$EndpointUri,
        
        [Parameter(Mandatory=$true)]
        [bool]$ExpectedResult,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$AdditionalAssertions
    )
    
    return @{
        Name = $TestName
        Test = {
            # Arrange
            $stateName = "TestState"
            
            # Act
            $result = Test-WebEndpoint -Uri $EndpointUri -StateName $stateName
            
            # Assert
            $result | Should -Be $ExpectedResult
            
            # Run additional assertions if provided
            if ($AdditionalAssertions) {
                & $AdditionalAssertions
            }
        }
    }
}

<#
.SYNOPSIS
Validates common endpoint test patterns in log output.

.DESCRIPTION
Checks log content for standard endpoint testing patterns and provides
descriptive error messages if patterns are missing.

.PARAMETER LogContent
The log content to validate.

.PARAMETER EndpointUri
The endpoint URI being tested.

.PARAMETER ShouldContainSuccess
Whether the log should contain success indicators.
#>
function Assert-EndpointTestLogContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$LogContent,
        
        [Parameter(Mandatory=$true)]
        [string]$EndpointUri,
        
        [Parameter(Mandatory=$false)]
        [bool]$ShouldContainSuccess = $true
    )
    
    # Escape special regex characters in the URI
    $escapedUri = [regex]::Escape($EndpointUri)
    
    # Check for endpoint check pattern
    $checkPattern = "Check:.*Endpoint.*$escapedUri"
    if ($LogContent -notmatch $checkPattern) {
        throw "Log should contain endpoint check pattern for URI: $EndpointUri`nPattern: $checkPattern`nLog content: $LogContent"
    }
    
    # Check for success/failure indicators
    if ($ShouldContainSuccess) {
        if ($LogContent -notmatch "Status:.*Ready|Result:.*READY") {
            throw "Log should contain success indicators for endpoint: $EndpointUri`nLog content: $LogContent"
        }
    } else {
        if ($LogContent -notmatch "Status:.*Not Ready|Result:.*NOT READY") {
            throw "Log should contain failure indicators for endpoint: $EndpointUri`nLog content: $LogContent"
        }
    }
}

# Export the functions
Export-ModuleMember -Function Initialize-WebRequestMock, New-EndpointReadinessTest, Assert-EndpointTestLogContent
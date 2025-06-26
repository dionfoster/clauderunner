# Code Coverage Configuration Guide

This document describes the comprehensive code coverage setup for the Claude Task Runner project.

## Overview

The project now includes a complete code coverage analysis system with multiple report formats and CI/CD integration capabilities.

## Files Added/Modified

### Core Configuration Files
- **`PesterConfig.ps1`** - Centralized Pester configuration with code coverage settings
- **`RunTestsWithCoverage.ps1`** - Dedicated script for running tests with coverage
- **`GenerateCoverageReport.ps1`** - HTML report generator from JaCoCo XML
- **`RunCompleteAnalysis.ps1`** - All-in-one script for comprehensive analysis

### Updated Files
- **`RunTests.ps1`** - Enhanced with new coverage options and configuration support
- **`README.md`** - Added comprehensive testing and coverage documentation
- **`.gitignore`** - Added TestResults directory and coverage files

### Generated Output
- **`TestResults/`** - Directory for all test and coverage outputs
  - `coverage.xml` - JaCoCo XML format (CI/CD standard)
  - `testresults.xml` - NUnit XML format (test results standard)
  - `coverage-report.html` - Interactive HTML report

## Usage Examples

### Basic Coverage Analysis
```powershell
# Run tests with coverage using dedicated configuration
.\RunTestsWithCoverage.ps1

# Run with custom threshold
.\RunTestsWithCoverage.ps1 -CoverageThreshold 85

# Run specific test with coverage
.\RunTestsWithCoverage.ps1 -TestPath "tests\Configuration.Tests.ps1"
```

### Complete Analysis
```powershell
# Run full analysis with HTML report
.\RunCompleteAnalysis.ps1

# Run with auto-open HTML report
.\RunCompleteAnalysis.ps1 -OpenReports

# Run for CI/CD (skip interactive HTML)
.\RunCompleteAnalysis.ps1 -SkipHtmlReport -CoverageThreshold 80
```

### Flexible Test Running
```powershell
# Use new advanced configuration
.\RunTests.ps1 -UseConfig -Coverage

# Traditional inline configuration
.\RunTests.ps1 -Coverage

# Specific test with advanced config
.\RunTests.ps1 -UseConfig -TestName "*Configuration*"
```

### HTML Report Generation
```powershell
# Generate HTML report from existing coverage data
.\GenerateCoverageReport.ps1

# Custom input/output paths
.\GenerateCoverageReport.ps1 -CoverageFile "custom\coverage.xml" -OutputFile "reports\coverage.html"
```

## Configuration Features

### Pester Configuration (`PesterConfig.ps1`)
- **Comprehensive Coverage**: Analyzes all PowerShell modules
- **Standard Output**: JaCoCo XML and NUnit XML formats
- **Proper Exclusions**: Automatically excludes test files
- **Flexible Filtering**: Support for tags and test selection

### Coverage Scope
- **Included**: All files in `modules/*.psm1` and `claude.ps1`
- **Excluded**: Test files, test helpers, and framework code
- **Formats**: JaCoCo XML (industry standard), NUnit XML (test results)

### Threshold Management
- **Configurable Thresholds**: Set minimum coverage requirements
- **Exit Code Integration**: Proper failure codes for CI/CD
- **Visual Feedback**: Color-coded coverage reporting

## CI/CD Integration

### Standard Formats
The configuration generates industry-standard reports compatible with:
- **Azure DevOps**: Native support for JaCoCo and NUnit formats
- **GitHub Actions**: Direct integration with coverage reporting actions
- **Jenkins**: Standard plugin support for both formats
- **TeamCity**: Built-in support for coverage visualization

### Example CI/CD Usage
```powershell
# For build pipelines
.\RunCompleteAnalysis.ps1 -SkipHtmlReport -CoverageThreshold 80
# Exit code: 0 = success, 1 = failure (tests failed or coverage below threshold)
```

### Report Locations
- JaCoCo XML: `TestResults/coverage.xml`
- NUnit XML: `TestResults/testresults.xml`
- HTML Report: `TestResults/coverage-report.html`

## Coverage Metrics

### Current Status
- **Overall Coverage**: ~46% (as of initial implementation)
- **Test Count**: 97 passing tests across 9 test files
- **Covered Modules**: All 7 PowerShell modules included

### Coverage Breakdown
The system provides detailed line-by-line coverage analysis including:
- Function-level coverage statistics
- Missed command identification
- File-specific coverage percentages
- Visual HTML reports with interactive exploration

## Best Practices

### Development Workflow
1. **Write Tests First**: Follow TDD principles
2. **Run Coverage Regularly**: Use `.\RunTestsWithCoverage.ps1` during development
3. **Review HTML Reports**: Use interactive reports to identify gaps
4. **Set Appropriate Thresholds**: Balance coverage goals with practicality

### CI/CD Workflow
1. **Use Standard Formats**: Leverage JaCoCo and NUnit XML outputs
2. **Set Coverage Gates**: Fail builds below threshold
3. **Archive Reports**: Store coverage artifacts for trending
4. **Integrate Notifications**: Alert on coverage drops

### Maintenance
1. **Update Exclusions**: Keep test file exclusions current
2. **Review Thresholds**: Adjust coverage targets as code matures
3. **Monitor Trends**: Track coverage over time
4. **Update Documentation**: Keep coverage guides current

## Troubleshooting

### Common Issues
- **Missing powershell-yaml**: Automatically installed by configuration system
- **Pester Version**: Requires Pester 5.0+, automatically installed if missing
- **Path Issues**: Use absolute paths in configuration files
- **Permission Issues**: Run with appropriate PowerShell execution policy

### Performance Considerations
- **Coverage Overhead**: ~1-2 seconds additional runtime for full coverage
- **Large Codebases**: Consider selective coverage for faster feedback
- **CI/CD Impact**: Minimal impact on build times with proper configuration

## Future Enhancements

### Potential Improvements
- **Coverage Trending**: Historical coverage tracking
- **Branch Coverage**: More detailed coverage metrics
- **Integration Testing**: Separate unit vs integration coverage
- **Custom Reporters**: Additional output formats as needed

This comprehensive coverage system provides the foundation for maintaining high code quality and ensuring robust test coverage across the Claude Task Runner project.

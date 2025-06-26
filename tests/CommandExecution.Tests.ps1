# Pester tests for CommandExecution module
BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot\TestHelpers\TestHelpers.psm1" -Force
    
    # Set up standardized test environment
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    $env = Initialize-StandardTestEnvironment -ModulesToImport @("Logging", "CommandExecution") -TestLogPath $script:TestLogPath
}

AfterAll {
    # Clean up test log file
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Force
    }
}

Describe "CommandExecution Module" {
    Context "Test-OutputForErrors" {
        It "Returns true when output contains error indicators" {
            # Arrange
            $errorOutput = "Error: Something went wrong"
            
            # Act
            $result = Test-OutputForErrors -OutputString $errorOutput
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Returns false when output does not contain error indicators" {
            # Arrange
            $normalOutput = "Operation completed successfully"
            
            # Act
            $result = Test-OutputForErrors -OutputString $normalOutput
            
            # Assert
            $result | Should -BeFalse
        }
    }
    
    Context "Get-ExecutableAndArgs" {
        It "Resolves a command and returns executable with arguments" {
            # Arrange
            $command = "npm install"
            
            # Act
            $result = Get-ExecutableAndArgs -Command $command
            
            # Assert
            $result.Count | Should -Be 2
            $result[0] | Should -Be "npm"
            $result[1] | Should -Be "install"
        }
    }
      Context "Build-StartProcessCommand" {
        It "Builds a command string for Start-Process" {
            # Arrange
            $executable = "npm"
            $arguments = "install"
            $windowStyle = "Hidden"
            
            # Act
            $result = Build-StartProcessCommand -Executable $executable -Arguments $arguments -WindowStyle $windowStyle
            
            # Assert
            $result | Should -Match "Start-Process -FilePath `"npm`" -ArgumentList `"install`" -WindowStyle Hidden"
        }
    }
      Context "Resolve-CommandAlias" {
        It "Resolves known command alias" {
            # Act
            $result = Resolve-CommandAlias -Command "npm install"
            
            # Assert
            $result | Should -Be "npm install"
        }
        
        It "Returns original command for unknown alias" {
            # Act
            $result = Resolve-CommandAlias -Command "unknown-command arg1 arg2"
            
            # Assert
            $result | Should -Be "unknown-command arg1 arg2"
        }
    }
}

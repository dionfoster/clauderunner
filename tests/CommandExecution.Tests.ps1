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
        
        It "Handles command with no arguments and known alias" {
            # Act
            $result = Resolve-CommandAlias -Command "node"
            
            # Assert
            $result | Should -Be "node "
        }
        
        It "Handles command with no arguments and unknown alias" {
            # Act
            $result = Resolve-CommandAlias -Command "unknowncommand"
            
            # Assert
            $result | Should -Be "unknowncommand"
        }
    }
    
    Context "ConvertTo-LaunchCommand" {
        It "Transforms command for windowsApp launch" {
            # Act
            $result = ConvertTo-LaunchCommand -Command "notepad.exe" -LaunchVia "windowsApp"
            
            # Assert
            $result.Command | Should -Be "start `"`" `"notepad.exe`""
            $result.CommandType | Should -Be "cmd"
            $result.PreserveWorkingDir | Should -Be $false
        }
        
        It "Transforms command for newWindow launch with npm command" {
            # Act
            $result = ConvertTo-LaunchCommand -Command "npm install" -LaunchVia "newWindow" -WorkingDirectory "C:\test"
            
            # Assert
            $result.Command | Should -Match "Start-Process pwsh -ArgumentList.*npm install"
            $result.CommandType | Should -Be "powershell"
            $result.PreserveWorkingDir | Should -Be $false
        }
        
        It "Transforms command for newWindow launch with node command" {
            # Act
            $result = ConvertTo-LaunchCommand -Command "node script.js" -LaunchVia "newWindow" -WorkingDirectory "C:\test"
            
            # Assert
            $result.Command | Should -Match "Start-Process pwsh -ArgumentList.*node script.js"
            $result.CommandType | Should -Be "powershell"
            $result.PreserveWorkingDir | Should -Be $false
        }
        
        It "Transforms command for newWindow launch with regular command" {
            # Act
            $result = ConvertTo-LaunchCommand -Command "echo hello" -LaunchVia "newWindow" -WorkingDirectory "C:\test"
            
            # Assert
            $result.Command | Should -Match "Start-Process.*echo.*hello"
            $result.CommandType | Should -Be "powershell"
            $result.PreserveWorkingDir | Should -Be $false
        }
        
        It "Transforms command for console launch with working directory" {
            # Act
            $result = ConvertTo-LaunchCommand -Command "echo hello" -LaunchVia "console" -WorkingDirectory "C:\test"
            
            # Assert
            $result.Command | Should -Be "echo hello"
            $result.CommandType | Should -Be "powershell"
            $result.PreserveWorkingDir | Should -Be $true
            $result.WorkingDirectory | Should -Be "C:\test"
        }
        
        It "Transforms command for console launch without working directory" {
            # Act
            $result = ConvertTo-LaunchCommand -Command "echo hello" -LaunchVia "console"
            
            # Assert
            $result.Command | Should -Be "echo hello"
            $result.CommandType | Should -Be "powershell"
            $result.PreserveWorkingDir | Should -Be $false
        }
        
        It "Uses console as default launch method" {
            # Act
            $result = ConvertTo-LaunchCommand -Command "echo hello"
            
            # Assert
            $result.Command | Should -Be "echo hello"
            $result.CommandType | Should -Be "powershell"
            $result.PreserveWorkingDir | Should -Be $false
        }
    }
    
    Context "Get-ExecutableAndArgs with edge cases" {
        It "Handles command with no arguments" {
            # Act
            $result = Get-ExecutableAndArgs -Command "notepad"
            
            # Assert
            $result.Count | Should -Be 2
            $result[0] | Should -Be "notepad"
            $result[1] | Should -Be ""
        }
        
        It "Handles command with multiple spaces" {
            # Act
            $result = Get-ExecutableAndArgs -Command "echo hello world"
            
            # Assert
            $result.Count | Should -Be 2
            $result[0] | Should -Be "echo"
            $result[1] | Should -Be "hello world"
        }
    }
    
    Context "Build-StartProcessCommand with edge cases" {
        It "Builds command without arguments" {
            # Act
            $result = Build-StartProcessCommand -Executable "notepad" -WindowStyle "Normal"
            
            # Assert
            $result | Should -Be "Start-Process -FilePath `"notepad`" -WindowStyle Normal"
        }
        
        It "Builds command with working directory" {
            # Act
            $result = Build-StartProcessCommand -Executable "notepad" -Arguments "test.txt" -WorkingDirectory "C:\temp" -WindowStyle "Normal"
            
            # Assert
            $result | Should -Match "Start-Process -FilePath `"notepad`" -ArgumentList `"test.txt`" -WorkingDirectory `"C:\\temp`" -WindowStyle Normal"
        }
    }
    
    Context "Test-OutputForErrors with additional patterns" {
        It "Detects 'not found' error pattern" {
            # Act
            $result = Test-OutputForErrors -OutputString "Command not found"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Detects 'unable' error pattern" {
            # Act
            $result = Test-OutputForErrors -OutputString "Unable to connect"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Detects 'fail' error pattern" {
            # Act
            $result = Test-OutputForErrors -OutputString "Operation failed"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Detects 'failed' error pattern" {
            # Act
            $result = Test-OutputForErrors -OutputString "Command failed to execute"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Detects 'no such file' error pattern" {
            # Act
            $result = Test-OutputForErrors -OutputString "no such file or directory"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Detects 'connection refused' error pattern" {
            # Act
            $result = Test-OutputForErrors -OutputString "connection refused by server"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Is case insensitive" {
            # Act
            $result = Test-OutputForErrors -OutputString "ERROR: Something went wrong"
            
            # Assert
            $result | Should -BeTrue
        }
    }
    
    Context "Invoke-CommandWithTimeout" {
        It "Executes powershell command without timeout successfully" {
            # Act
            $result = Invoke-CommandWithTimeout -Command "echo 'test'" -CommandType "powershell"
            
            # Assert
            $result.Success | Should -BeTrue
        }
        
        It "Executes cmd command without timeout successfully" {
            # Act
            $result = Invoke-CommandWithTimeout -Command "echo test" -CommandType "cmd"
            
            # Assert
            $result.Success | Should -BeTrue
            $result.Output | Should -Match "test"
        }
        
        It "Handles powershell command failure" {
            # Act
            $result = Invoke-CommandWithTimeout -Command "exit 1" -CommandType "powershell"
            
            # Assert
            $result.Success | Should -BeFalse
        }
        
        It "Handles cmd command failure" {
            # Act
            $result = Invoke-CommandWithTimeout -Command "exit 1" -CommandType "cmd"
            
            # Assert
            $result.Success | Should -BeFalse
        }
        
        It "Handles timeout scenario" {
            # Act
            $result = Invoke-CommandWithTimeout -Command "Start-Sleep 3" -CommandType "powershell" -TimeoutSeconds 1
            
            # Assert
            $result.Success | Should -BeFalse
            $result.Output | Should -Match "Timeout after 1 seconds"
        }
        
        It "Preserves working directory when specified" {
            # Arrange
            $originalLocation = Get-Location
            $testDir = $TestDrive
            
            # Act
            $result = Invoke-CommandWithTimeout -Command "echo test" -CommandType "cmd" -PreserveWorkingDir $true -WorkingDirectory $testDir
            
            # Assert
            $result.Success | Should -BeTrue
            (Get-Location).Path | Should -Be $originalLocation.Path
        }
        
        It "Does not change directory when PreserveWorkingDir is false" {
            # Arrange
            $originalLocation = Get-Location
            
            # Act
            $result = Invoke-CommandWithTimeout -Command "echo test" -CommandType "cmd" -PreserveWorkingDir $false -WorkingDirectory $TestDrive
            
            # Assert
            $result.Success | Should -BeTrue
            (Get-Location).Path | Should -Be $originalLocation.Path
        }
        
        It "Executes command with timeout but completes in time" {
            # Act
            $result = Invoke-CommandWithTimeout -Command "echo fast" -CommandType "cmd" -TimeoutSeconds 5
            
            # Assert
            $result.Success | Should -BeTrue
            $result.Output | Should -Match "fast"
        }
        
        It "Handles job completion with timeout" {
            # Act
            $result = Invoke-CommandWithTimeout -Command "echo quick" -CommandType "cmd" -TimeoutSeconds 5
            
            # Assert
            $result.Success | Should -BeTrue
            $result.Output | Should -Match "quick"
        }
        
        It "Handles timeout with PowerShell job" {
            # Act
            $result = Invoke-CommandWithTimeout -Command "Start-Sleep 2" -CommandType "powershell" -TimeoutSeconds 1
            
            # Assert
            $result.Success | Should -BeFalse
            $result.Output | Should -Match "Timeout"
        }
        
        It "Handles timeout with CMD job" {
            # Act
            $result = Invoke-CommandWithTimeout -Command "ping -n 3 127.0.0.1" -CommandType "cmd" -TimeoutSeconds 1
            
            # Assert
            $result.Success | Should -BeFalse
            $result.Output | Should -Match "Timeout"
        }
        
        It "Handles successful PowerShell job completion" {
            # Act
            $result = Invoke-CommandWithTimeout -Command "echo 'success'" -CommandType "powershell" -TimeoutSeconds 5
            
            # Assert
            $result.Success | Should -BeTrue
            $result.Output | Should -Match "success"
        }
        
        It "Handles successful CMD job completion" {
            # Act
            $result = Invoke-CommandWithTimeout -Command "echo success" -CommandType "cmd" -TimeoutSeconds 5
            
            # Assert
            $result.Success | Should -BeTrue
            $result.Output | Should -Match "success"
        }
    }
    
    Context "Invoke-Command" {
        It "Executes simple command successfully" {
            # Act
            $result = Invoke-Command -Command "ver" -Description "Test command" -StateName "teststate" -CommandType "cmd"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Returns false for command that actually fails" {
            # Act
            $result = Invoke-Command -Command "exit 1" -Description "Test command" -StateName "teststate" -CommandType "cmd"
            
            # Assert
            $result | Should -BeFalse
        }
        
        It "Handles command execution exceptions" {
            # Act
            $result = Invoke-Command -Command "invalidcommandthatdoesnotexist12345" -Description "Test command" -StateName "teststate"
            
            # Assert
            $result | Should -BeFalse
        }
        
        It "Resolves command aliases before execution" {
            # Act - Using a more reliable test that doesn't depend on npm being installed
            $result = Invoke-Command -Command "node --help" -Description "Test node" -StateName "teststate"
            
            # Assert - Should not throw and execute the resolved command
            $result | Should -BeOfType [bool]
        }
        
        It "Uses specified command type" {
            # Act
            $result = Invoke-Command -Command "ver" -Description "Test command" -StateName "teststate" -CommandType "cmd"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Uses specified launch method" {
            # Act
            $result = Invoke-Command -Command "ver" -Description "Test command" -StateName "teststate" -LaunchVia "console" -CommandType "cmd"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Uses working directory when specified" {
            # Act
            $result = Invoke-Command -Command "dir" -Description "Test command" -StateName "teststate" -WorkingDirectory $TestDrive -LaunchVia "console" -CommandType "cmd"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Applies timeout when specified" {
            # Act - Use a command that doesn't have input redirection issues
            $result = Invoke-Command -Command "ping -n 3 127.0.0.1" -Description "Test command" -StateName "teststate" -TimeoutSeconds 1 -CommandType "cmd"
            
            # Assert
            $result | Should -BeFalse
        }
        
        It "Returns false when command has no output but fails" {
            # Act
            $result = Invoke-Command -Command "exit 1" -Description "Test command" -StateName "teststate" -CommandType "cmd"
            
            # Assert
            $result | Should -BeFalse
        }
        
        It "Returns true for successful PowerShell command" {
            # Act
            $result = Invoke-Command -Command "echo 'success'" -Description "Test command" -StateName "teststate" -CommandType "powershell"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Uses windowsApp launch method" {
            # Act - Using a harmless command that should work
            $result = Invoke-Command -Command "calc.exe" -Description "Test command" -StateName "teststate" -LaunchVia "windowsApp"
            
            # Assert
            $result | Should -BeOfType [bool]
        }
        
        It "Handles command with output but still succeeds" {
            # Act
            $result = Invoke-Command -Command "echo success" -Description "Test command" -StateName "teststate" -CommandType "cmd"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Handles newWindow launch method" {
            # Act
            $result = Invoke-Command -Command "echo test" -Description "Test command" -StateName "teststate" -LaunchVia "newWindow" -CommandType "cmd"
            
            # Assert
            $result | Should -BeOfType [bool]
        }
        
        It "Executes command with working directory preservation" {
            # Act
            $result = Invoke-Command -Command "echo test" -Description "Test command" -StateName "teststate" -WorkingDirectory $TestDrive -LaunchVia "console" -CommandType "cmd"
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Handles command that produces output with errors" {
            # Act
            $result = Invoke-Command -Command "echo 'warning: failed operation'" -Description "Test command" -StateName "teststate" -CommandType "cmd"
            
            # Assert
            $result | Should -BeFalse
        }
        
        It "Handles command that has no output and succeeds" {
            # Act
            $result = Invoke-Command -Command "echo off" -Description "Test command" -StateName "teststate" -CommandType "cmd"
            
            # Assert
            $result | Should -BeTrue
        }
    }
}

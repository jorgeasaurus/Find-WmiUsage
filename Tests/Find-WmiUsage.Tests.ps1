#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    # Source the function from parent directory
    . $PSScriptRoot/../Find-WmiUsage.ps1

    # Create temporary test directory
    $script:TestRoot = Join-Path $TestDrive 'WmiTests'
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
}

Describe 'Find-WmiUsage' {

    Context 'Pattern Detection' {

        BeforeEach {
            $script:TestFile = Join-Path $script:TestRoot 'test.ps1'
        }

        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item $script:TestFile -Force
            }
        }

        It 'Detects Get-WmiObject cmdlet' {
            @'
Get-WmiObject -Class Win32_Process
'@ | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'Get-WmiObject'
            $result[0].LineNumber | Should -Be 1
        }

        It 'Detects gwmi alias' {
            'gwmi Win32_Service' | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'gwmi'
        }

        It 'Detects Invoke-WmiMethod cmdlet' {
            'Invoke-WmiMethod -Class Win32_Process -Name Create' | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'Invoke-WmiMethod'
        }

        It 'Detects Set-WmiInstance cmdlet' {
            'Set-WmiInstance -Class Win32_Environment' | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'Set-WmiInstance'
        }

        It 'Detects Remove-WmiObject cmdlet' {
            'Remove-WmiObject -Class Win32_Share' | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'Remove-WmiObject'
        }

        It 'Detects Register-WmiEvent cmdlet' {
            'Register-WmiEvent -Class Win32_ProcessStartTrace' | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'Register-WmiEvent'
        }

        It 'Detects wmic command' {
            'wmic process list' | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'wmic'
        }

        It 'Detects ManagementClass .NET usage' {
            '$mc = New-Object System.Management.ManagementClass("Win32_Service")' | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'ManagementClass'
        }

        It 'Detects ManagementObject .NET usage' {
            '$mo = [System.Management.ManagementObject]' | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'ManagementObject'
        }

        It 'Detects ManagementObjectSearcher .NET usage' {
            '$searcher = New-Object System.Management.ManagementObjectSearcher' | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'ManagementObjectSearcher'
        }

        It 'Detects SWbemLocator COM usage' {
            '$locator = New-Object -ComObject "WbemScripting.SWbemLocator"' | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'SWbemLocator'
        }

        It 'Is case-insensitive for pattern matching' {
            @'
get-wmiobject -Class Win32_Process
GET-WMIOBJECT -Class Win32_Service
GwMi Win32_BIOS
'@ | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result.Count | Should -Be 3
        }

        It 'Does not detect CIM cmdlets (modern equivalents)' {
            @'
Get-CimInstance -Class Win32_Process
Invoke-CimMethod -Class Win32_Process
'@ | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -BeNullOrEmpty
        }

        It 'Detects multiple patterns in single file' {
            @'
Get-WmiObject -Class Win32_Process
Invoke-WmiMethod -Name Create
wmic process list
'@ | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result.Count | Should -Be 3
            $result[0].LineNumber | Should -Be 1
            $result[1].LineNumber | Should -Be 2
            $result[2].LineNumber | Should -Be 3
        }
    }

    Context 'Comment Handling' {

        BeforeEach {
            $script:TestFile = Join-Path $script:TestRoot 'test.ps1'
        }

        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item $script:TestFile -Force
            }
        }

        It 'Includes commented lines by default' {
            @'
# Get-WmiObject -Class Win32_Process
Get-CimInstance -Class Win32_Process
'@ | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].LineText | Should -Match '# Get-WmiObject'
        }

        It 'Ignores commented lines when IgnoreComments is specified' {
            @'
# Get-WmiObject -Class Win32_Process
Get-CimInstance -Class Win32_Process
'@ | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table -IgnoreComments
            $result | Should -BeNullOrEmpty
        }

        It 'Includes empty lines by default' {
            @'

Get-WmiObject -Class Win32_Process

'@ | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result.Count | Should -Be 1
            $result[0].LineNumber | Should -Be 2
        }

        It 'Ignores empty lines when IgnoreComments is specified' {
            @'

Get-WmiObject -Class Win32_Process

'@ | Set-Content -Path $script:TestFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table -IgnoreComments
            $result.Count | Should -Be 1
            $result[0].LineNumber | Should -Be 2
        }
    }

    Context 'File Extension Handling' {

        It 'Scans .ps1 files by default' {
            $testFile = Join-Path $script:TestRoot 'script.ps1'
            'Get-WmiObject Win32_Process' | Set-Content -Path $testFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty

            Remove-Item $testFile -Force
        }

        It 'Scans .psm1 files by default' {
            $testFile = Join-Path $script:TestRoot 'module.psm1'
            'Get-WmiObject Win32_Process' | Set-Content -Path $testFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty

            Remove-Item $testFile -Force
        }

        It 'Scans .psd1 files by default' {
            $testFile = Join-Path $script:TestRoot 'manifest.psd1'
            'Get-WmiObject Win32_Process' | Set-Content -Path $testFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty

            Remove-Item $testFile -Force
        }

        It 'Supports custom extensions' {
            $testFile = Join-Path $script:TestRoot 'config.txt'
            'Get-WmiObject Win32_Process' | Set-Content -Path $testFile

            $result = Find-WmiUsage -Path $script:TestRoot -Extensions '*.txt' -Output Table
            $result | Should -Not -BeNullOrEmpty

            Remove-Item $testFile -Force
        }

        It 'Ignores non-matching extensions' {
            $testFile = Join-Path $script:TestRoot 'data.json'
            'Get-WmiObject Win32_Process' | Set-Content -Path $testFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -BeNullOrEmpty

            Remove-Item $testFile -Force
        }
    }

    Context 'Output Formats' {

        BeforeEach {
            $script:TestFile = Join-Path $script:TestRoot 'test.ps1'
            'Get-WmiObject -Class Win32_Process' | Set-Content -Path $script:TestFile
        }

        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item $script:TestFile -Force
            }
        }

        It 'Returns PSCustomObject array for Table output' {
            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -BeOfType [PSCustomObject]
            $result[0].PSObject.Properties.Name | Should -Contain 'File'
            $result[0].PSObject.Properties.Name | Should -Contain 'LineNumber'
            $result[0].PSObject.Properties.Name | Should -Contain 'Pattern'
            $result[0].PSObject.Properties.Name | Should -Contain 'LineText'
        }

        It 'Exports to CSV file' {
            $csvFile = Join-Path $script:TestRoot 'output.csv'
            Find-WmiUsage -Path $script:TestRoot -Output CSV -OutFile $csvFile

            Test-Path $csvFile | Should -Be $true
            $content = Import-Csv $csvFile
            $content | Should -Not -BeNullOrEmpty
            $content[0].Pattern | Should -Match 'Get-WmiObject'

            Remove-Item $csvFile -Force
        }

        It 'Creates default CSV filename when not specified' {
            $originalLocation = Get-Location
            Set-Location $script:TestRoot

            Find-WmiUsage -Path $script:TestRoot -Output CSV

            Test-Path 'WmiScanResults.csv' | Should -Be $true
            Remove-Item 'WmiScanResults.csv' -Force

            Set-Location $originalLocation
        }

        It 'Exports to JSON file' {
            $jsonFile = Join-Path $script:TestRoot 'output.json'
            Find-WmiUsage -Path $script:TestRoot -Output JSON -OutFile $jsonFile

            Test-Path $jsonFile | Should -Be $true
            $content = Get-Content $jsonFile | ConvertFrom-Json
            $content | Should -Not -BeNullOrEmpty
            $content[0].Pattern | Should -Match 'Get-WmiObject'

            Remove-Item $jsonFile -Force
        }

        It 'Creates default JSON filename when not specified' {
            $originalLocation = Get-Location
            Set-Location $script:TestRoot

            Find-WmiUsage -Path $script:TestRoot -Output JSON

            Test-Path 'WmiScanResults.json' | Should -Be $true
            Remove-Item 'WmiScanResults.json' -Force

            Set-Location $originalLocation
        }
    }

    Context 'Path Handling' {

        It 'Uses current directory when Path not specified' {
            $originalLocation = Get-Location
            $isolatedDir = Join-Path $script:TestRoot 'IsolatedTest'
            New-Item -ItemType Directory -Path $isolatedDir -Force | Out-Null
            Set-Location $isolatedDir

            $testFile = Join-Path $isolatedDir 'temp-test.ps1'
            'Get-WmiObject Win32_Process' | Set-Content -Path $testFile

            $result = Find-WmiUsage -Output Table
            $result | Should -Not -BeNullOrEmpty

            Set-Location $originalLocation
            Remove-Item $isolatedDir -Recurse -Force
        }

        It 'Handles non-existent paths gracefully' {
            $result = Find-WmiUsage -Path 'C:\NonExistentPath\Fake' -Output Table
            $result | Should -BeNullOrEmpty
        }

        It 'Recursively scans subdirectories' {
            $subDir = Join-Path $script:TestRoot 'SubFolder'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null

            $testFile1 = Join-Path $script:TestRoot 'root.ps1'
            $testFile2 = Join-Path $subDir 'nested.ps1'

            'Get-WmiObject Win32_Process' | Set-Content -Path $testFile1
            'Invoke-WmiMethod -Name Create' | Set-Content -Path $testFile2

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result.Count | Should -Be 2

            Remove-Item $testFile1, $testFile2 -Force
            Remove-Item $subDir -Recurse -Force
        }

        It 'Does not scan subdirectories when Recurse is false' {
            $subDir = Join-Path $script:TestRoot 'SubFolder'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null

            $testFile1 = Join-Path $script:TestRoot 'root.ps1'
            $testFile2 = Join-Path $subDir 'nested.ps1'

            'Get-WmiObject Win32_Process' | Set-Content -Path $testFile1
            'Invoke-WmiMethod -Name Create' | Set-Content -Path $testFile2

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table -Recurse:$false
            $result.Count | Should -Be 1
            $result[0].File | Should -BeLike '*root.ps1'

            Remove-Item $testFile1, $testFile2 -Force
            Remove-Item $subDir -Recurse -Force
        }
    }

    Context 'Edge Cases' {

        It 'Handles empty files' {
            $testFile = Join-Path $script:TestRoot 'empty.ps1'
            '' | Set-Content -Path $testFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -BeNullOrEmpty

            Remove-Item $testFile -Force
        }

        It 'Handles files with no matches' {
            $testFile = Join-Path $script:TestRoot 'nomatch.ps1'
            @'
Get-CimInstance -Class Win32_Process
Get-Process
Get-Service
'@ | Set-Content -Path $testFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -BeNullOrEmpty

            Remove-Item $testFile -Force
        }

        It 'Handles very long lines' {
            $testFile = Join-Path $script:TestRoot 'longline.ps1'
            $longLine = 'Get-WmiObject Win32_Process' + (' ' * 5000) + '# Very long line'
            $longLine | Set-Content -Path $testFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty
            $result[0].Pattern | Should -Match 'Get-WmiObject'

            Remove-Item $testFile -Force
        }

        It 'Handles special characters in file paths' {
            $specialDir = Join-Path $script:TestRoot 'Folder With Spaces'
            New-Item -ItemType Directory -Path $specialDir -Force | Out-Null

            $testFile = Join-Path $specialDir 'test file.ps1'
            'Get-WmiObject Win32_Process' | Set-Content -Path $testFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result | Should -Not -BeNullOrEmpty

            Remove-Item $testFile -Force
            Remove-Item $specialDir -Recurse -Force
        }

        It 'Returns only first matching pattern per line' {
            $testFile = Join-Path $script:TestRoot 'multi.ps1'
            'Get-WmiObject Win32_Process; gwmi Win32_Service' | Set-Content -Path $testFile

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table
            $result.Count | Should -Be 1
            $result[0].Pattern | Should -Match 'Get-WmiObject'

            Remove-Item $testFile -Force
        }
    }

    Context 'Parallel Processing' {

        It 'Processes multiple files in parallel' {
            # Create multiple test files
            1..10 | ForEach-Object {
                $testFile = Join-Path $script:TestRoot "test$_.ps1"
                "Get-WmiObject Win32_Process # File $_" | Set-Content -Path $testFile
            }

            $result = Find-WmiUsage -Path $script:TestRoot -Output Table -ThrottleLimit 5
            $result.Count | Should -Be 10

            # Cleanup
            Get-ChildItem $script:TestRoot -Filter 'test*.ps1' | Remove-Item -Force
        }

        It 'Respects ThrottleLimit parameter' {
            # This test just ensures the parameter is accepted
            $testFile = Join-Path $script:TestRoot 'test.ps1'
            'Get-WmiObject Win32_Process' | Set-Content -Path $testFile

            { Find-WmiUsage -Path $script:TestRoot -ThrottleLimit 10 -Output Table } | Should -Not -Throw

            Remove-Item $testFile -Force
        }
    }

    Context 'Parameter Validation' {

        It 'Accepts valid Output parameter values' {
            $testFile = Join-Path $script:TestRoot 'test.ps1'
            'Get-WmiObject Win32_Process' | Set-Content -Path $testFile

            { Find-WmiUsage -Path $script:TestRoot -Output Table } | Should -Not -Throw
            { Find-WmiUsage -Path $script:TestRoot -Output CSV -OutFile (Join-Path $script:TestRoot 'test.csv') } | Should -Not -Throw
            { Find-WmiUsage -Path $script:TestRoot -Output JSON -OutFile (Join-Path $script:TestRoot 'test.json') } | Should -Not -Throw

            Remove-Item $testFile -Force
            Remove-Item (Join-Path $script:TestRoot 'test.csv') -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $script:TestRoot 'test.json') -Force -ErrorAction SilentlyContinue
        }

        It 'Rejects invalid Output parameter values' {
            { Find-WmiUsage -Path $script:TestRoot -Output 'InvalidFormat' } | Should -Throw
        }
    }
}
# Requires -Version 7.0
function Find-WmiUsage {
    <#
.SYNOPSIS
# Scans PowerShell files for legacy WMI / WMIC usage.

.PARAMETER Path
  Root directory to scan (defaults to current).

.PARAMETER Output
  Output mode: Table (default), CSV, or JSON.

.PARAMETER OutFile
  Path for CSV/JSON output.

.PARAMETER Extensions
  File extensions to include (default: *.ps1, *.psm1, *.psd1).

.PARAMETER IgnoreComments
  Skip commented or empty lines.

.PARAMETER ThrottleLimit
  Controls parallel job concurrency.

.PARAMETER ExcludeFiles
  File names to exclude from scanning (default: Find-WmiUsage.ps1, Find-WmiUsage.Tests.ps1).

.PARAMETER Recurse
  Scan subdirectories recursively (default: true).

.EXAMPLE
  Find-WmiUsage -Path C:\Scripts -Output CSV -OutFile .\WmiScan.csv
#>
    [CmdletBinding()]
    param(
        [string]$Path = '.',
        [ValidateSet('Table', 'CSV', 'JSON')]
        [string]$Output = 'Table',
        [string]$OutFile,
        [string[]]$Extensions = @('*.ps1', '*.psm1', '*.psd1'),
        [switch]$IgnoreComments,
        [int]$ThrottleLimit = 20,
        [string[]]$ExcludeFiles = @('Find-WmiUsage.ps1', 'Find-WmiUsage.Tests.ps1'),
        [switch]$Recurse = $true
    )

    # Regex patterns to detect WMI / WMIC usage
    $Patterns = @(
        '(?i)\bwmic\b',
        '(?i)\bGet-WmiObject\b',
        '(?i)\bgwmi\b',
        '(?i)\bInvoke-WmiMethod\b',
        '(?i)\biwmi\b',
        '(?i)\bSet-WmiInstance\b',
        '(?i)\bswmi\b',
        '(?i)\bRemove-WmiObject\b',
        '(?i)\brwmi\b',
        '(?i)\bRegister-WmiEvent\b',
        '(?i)\bNew-Object\s+[^\r\n]*ManagementClass\b',
        '(?i)\bSWbemLocator\b',
        '(?i)\bSWbemServices\b',
        '(?i)\bManagementObject\b',
        '(?i)\bManagementObjectSearcher\b'
    )

    # Gather files
    $Files = foreach ($ext in $Extensions) {
        if ($Recurse) {
            Get-ChildItem -Path $Path -Recurse -Filter $ext -ErrorAction SilentlyContinue
        } else {
            Get-ChildItem -Path $Path -Filter $ext -ErrorAction SilentlyContinue
        }
    }

    # Filter out excluded files
    if ($ExcludeFiles) {
        $Files = $Files | Where-Object { $_.Name -notin $ExcludeFiles }
    }

    if (-not $Files) {
        if ($Path -eq '.') { $Path = (Get-Location).Path }
        Write-Warning "No PowerShell files found in $Path"
        return
    }

    # Parallel scan
    $Results = $Files | ForEach-Object -Parallel {
        $findings = @()
        $lines = @(Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue)
        if (-not $lines) { return @() }
        Write-Verbose "Scanning $($_.BaseName)"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = [string]$lines[$i]
            if ($using:IgnoreComments -and ($line.Trim() -like '#*' -or $line.Trim() -eq '')) { continue }
            foreach ($pat in $using:Patterns) {
                if ($line -match $pat) {
                    $findings += [PSCustomObject]@{
                        File       = $_.FullName
                        LineNumber = $i + 1
                        Pattern    = $pat
                        LineText   = $line.Trim()
                    }
                    break
                }
            }
        }
        $findings
    } -ThrottleLimit $ThrottleLimit

    # Sort results for consistent output
    if ($Results) {
        $Results = $Results | Sort-Object File, LineNumber
    }

    # Output
    switch ($Output) {
        'Table' {
            if ($Results) {
                # Display formatted output without consuming the pipeline
                $Results | Format-Table File, LineNumber, Pattern, LineText -AutoSize | Out-Host
            } else {
                Write-Host "No WMI/WMIC patterns found."
            }
        }
        'CSV' {
            if (-not $OutFile) { $OutFile = 'WmiScanResults.csv' }
            $Results | Export-Csv -NoTypeInformation -Path $OutFile
            Write-Host "Results written to $OutFile"
        }
        'JSON' {
            if (-not $OutFile) { $OutFile = 'WmiScanResults.json' }
            $Results | ConvertTo-Json -Depth 3 | Set-Content -Path $OutFile
            Write-Host "Results written to $OutFile"
        }
    }

    # Return results for testability and pipeline usage
    return $Results
}
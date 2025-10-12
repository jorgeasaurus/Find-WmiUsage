# Find-WmiUsage

A PowerShell tool to scan codebases for legacy WMI (Windows Management Instrumentation) usage that needs migration to modern CIM cmdlets.

## Why This Tool Exists

Microsoft has deprecated and is removing the legacy WMI cmdlets and WMIC command-line tool from Windows. According to [Microsoft's official announcement](https://support.microsoft.com/en-us/topic/windows-management-instrumentation-command-line-wmic-removal-from-windows-e9e83c7f-4992-477f-ba1d-96f694b8665d):

- **WMIC is being removed** starting with Windows 11, version 25H2
- **New Windows 11 installations** (version 24H2) already have WMIC removed by default
- **Legacy PowerShell WMI cmdlets are deprecated** in favor of CIM cmdlets

This tool helps you identify legacy WMI usage in your PowerShell scripts, modules, and manifests so you can migrate to the modern CIM alternatives before these tools are removed.

## What It Detects

Find-WmiUsage scans for 15 different legacy WMI patterns:

### PowerShell Cmdlets (Deprecated)
- `Get-WmiObject` → Use `Get-CimInstance`
- `Invoke-WmiMethod` → Use `Invoke-CimMethod`
- `Set-WmiInstance` → Use `Set-CimInstance`
- `Remove-WmiObject` → Use `Remove-CimInstance`
- `Register-WmiEvent` → Use `Register-CimIndicationEvent`

### PowerShell Aliases
- `gwmi`, `iwmi`, `swmi`, `rwmi`

### External Commands
- `wmic` command-line tool

### .NET Classes
- `System.Management.ManagementClass`
- `System.Management.ManagementObject`
- `System.Management.ManagementObjectSearcher`

### COM Objects
- `SWbemLocator`
- `SWbemServices`

## Requirements

- PowerShell 7.0 or later
- Pester 5.0+ (for running tests)

## Installation

1. Clone or download this repository
2. Source the function in your PowerShell session:

```powershell
git clone https://github.com/jorgeasaurus/Find-WmiUsage.git
cd Find-WmiUsage
. .\Find-WmiUsage.ps1
```

## Usage

### Basic Scan

Scan the current directory for WMI usage:

```powershell
Find-WmiUsage
```

### Scan Specific Directory

```powershell
Find-WmiUsage -Path C:\Scripts
```

### Export Results to CSV

```powershell
Find-WmiUsage -Path C:\MyModules -Output CSV -OutFile .\wmi-findings.csv
```

### Export Results to JSON

```powershell
Find-WmiUsage -Path C:\Automation -Output JSON -OutFile .\wmi-audit.json
```

### Scan Specific File Types

```powershell
# Scan only .ps1 files
Find-WmiUsage -Extensions '*.ps1'

# Scan custom extensions
Find-WmiUsage -Extensions '*.txt','*.config'
```

### Ignore Comments

By default, the scanner includes commented lines (useful for finding WMI references in documentation). To skip comments:

```powershell
Find-WmiUsage -IgnoreComments
```

### Adjust Parallelism

Control how many files are processed concurrently (default: 20):

```powershell
# Process more files in parallel for large codebases
Find-WmiUsage -Path C:\LargeRepo -ThrottleLimit 50
```

## Example Output

```
File                              LineNumber Pattern              LineText
----                              ---------- -------              --------
C:\Scripts\inventory.ps1                  12 (?i)\bGet-WmiObject\b Get-WmiObject -Class Win32_ComputerSystem
C:\Scripts\inventory.ps1                  45 (?i)\bgwmi\b          gwmi Win32_Service -Filter "State='Running'"
C:\Scripts\legacy-report.ps1              8 (?i)\bwmic\b           wmic process list brief
```

## Migration Guide

When you find legacy WMI usage, migrate to CIM cmdlets:

### Example 1: Get System Information

**Legacy (deprecated):**
```powershell
Get-WmiObject -Class Win32_ComputerSystem
```

**Modern (recommended):**
```powershell
Get-CimInstance -ClassName Win32_ComputerSystem
```

### Example 2: Query with Filter

**Legacy (deprecated):**
```powershell
Get-WmiObject -Class Win32_Service -Filter "State='Running'"
```

**Modern (recommended):**
```powershell
Get-CimInstance -ClassName Win32_Service -Filter "State='Running'"
```

### Example 3: Invoke Method

**Legacy (deprecated):**
```powershell
Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "notepad.exe"
```

**Modern (recommended):**
```powershell
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine="notepad.exe"}
```

### Example 4: WMIC Command

**Legacy (deprecated):**
```powershell
wmic process where "name='notepad.exe'" delete
```

**Modern (recommended):**
```powershell
Get-CimInstance -ClassName Win32_Process -Filter "Name='notepad.exe'" | Remove-CimInstance
```

## Key Differences: WMI vs CIM

| Aspect | WMI Cmdlets | CIM Cmdlets |
|--------|------------|-------------|
| **Protocol** | DCOM | WS-MAN (SOAP over HTTP) |
| **Firewall-friendly** | No | Yes |
| **Cross-platform** | No | Yes (with OMI on Linux) |
| **Session management** | Limited | Robust (`New-CimSession`) |
| **Performance** | Slower | Faster |
| **Future support** | Deprecated | Actively maintained |

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Path` | String | `.` (current directory) | Root directory to scan recursively |
| `-Output` | String | `Table` | Output format: `Table`, `CSV`, or `JSON` |
| `-OutFile` | String | Auto-generated | File path for CSV/JSON output |
| `-Extensions` | String[] | `*.ps1`, `*.psm1`, `*.psd1` | File extensions to scan |
| `-IgnoreComments` | Switch | `$false` | Skip commented and empty lines |
| `-ThrottleLimit` | Int | `20` | Number of files to process in parallel |

## Running Tests

This project includes comprehensive Pester tests:

```powershell
# Install Pester if needed
Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser

# Run tests
Invoke-Pester .\Tests\Find-WmiUsage.Tests.ps1
```

## Performance

The tool uses PowerShell 7's parallel `ForEach-Object -Parallel` feature to scan multiple files concurrently. Performance depends on:

- Number of files
- File sizes
- ThrottleLimit setting
- Disk I/O speed

For large repositories (1000+ files), expect scan times of 10-30 seconds with default settings.

## Limitations

- Requires PowerShell 7.0+ (uses parallel processing features)
- Scans only text-based files
- Pattern matching uses regex (may have false positives/negatives in complex code)
- Does not analyze dynamic code execution or runtime behavior

## Use Cases

1. **Pre-migration audits** - Identify all WMI usage before upgrading to Windows 11 25H2
2. **Module modernization** - Update PowerShell modules to use CIM cmdlets
3. **Documentation updates** - Find WMI references in comments and help text
4. **Code reviews** - Enforce modern practices in new code submissions
5. **Compliance checks** - Ensure scripts are compatible with future Windows versions

## Contributing

Contributions are welcome! Areas for improvement:

- Additional WMI pattern detection
- Integration with CI/CD pipelines
- Auto-remediation suggestions
- Support for other scripting languages (Python, VBScript, etc.)

## License

This project is provided as-is for use in identifying legacy WMI usage in your codebase.

## Additional Resources

- [Microsoft: WMIC Removal Announcement](https://support.microsoft.com/en-us/topic/windows-management-instrumentation-command-line-wmic-removal-from-windows-e9e83c7f-4992-477f-ba1d-96f694b8665d)
- [Microsoft Docs: Get-CimInstance](https://learn.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance)
- [Microsoft Docs: CIM Cmdlets](https://learn.microsoft.com/en-us/powershell/module/cimcmdlets/)
- [PowerShell Gallery: CimCmdlets Module](https://www.powershellgallery.com/packages/CimCmdlets)

## Support

For issues, questions, or suggestions, please open an issue in this repository.

---

**Note**: This tool performs static code analysis only. Always test your migrated scripts thoroughly in a non-production environment before deploying to production systems.
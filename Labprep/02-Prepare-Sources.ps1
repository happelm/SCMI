<#
.SYNOPSIS
    SCMI Lab - Step 2: download installers, write helper scripts and share C:\Software.

.DESCRIPTION
    Run on the site server (SCCM.smart.etc) as local admin. Needs internet access.
    Idempotent: existing files are not downloaded again (use -Force to refresh).

    Layout:
      C:\Software\7-Zip\24.09\          MSI, old version (superseded)
      C:\Software\7-Zip\25.01\          MSI, new version (supersedes 24.09)
      C:\Software\NotepadPP\            EXE (latest from GitHub) + Finance install wrapper
      C:\Software\PuTTY\                MSI (latest)
      C:\Software\VCRedist\             vc_redist.x64.exe (dependency)
      C:\Software\Greenshot\            Inno Setup EXE (latest GitHub release), depends on VCRedist (artificial)
      C:\Software\FirefoxESR\           MSI + policies.json + install/uninstall wrappers  -> PSADT candidate
      C:\Software\Toolbox\              in-house "app" with a deliberately broken detection
      C:\Software\AdobeReader2019\      dummy content only, never deployed (dead content)
      C:\Software\Legacy\SmartETC-Branding\  classic Package/Program (batch)
    Share: \\SCCM\Software$  (read for Everyone)
#>
[CmdletBinding()]
param(
    [string]$Root      = 'C:\Software',
    [string]$ShareName = 'Software$',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Results = [System.Collections.Generic.List[object]]::new()
function Invoke-Step {
    param([string]$Name, [scriptblock]$Action)
    try   { & $Action; Write-Host "[OK]   $Name" -ForegroundColor Green;  $Results.Add([pscustomobject]@{Step=$Name;Status='OK';Error=''}) }
    catch { Write-Warning "[FAIL] $Name :: $($_.Exception.Message)";       $Results.Add([pscustomobject]@{Step=$Name;Status='FAIL';Error=$_.Exception.Message}) }
}
function Get-File([string]$Url, [string]$Dest) {
    New-Item -ItemType Directory -Path (Split-Path $Dest) -Force | Out-Null
    if ($Force -or -not (Test-Path $Dest)) { Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing }
}
function Get-GitHubAsset([string]$Repo, [string]$Pattern, [string]$DestFolder) {
    $rel   = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = 'SCMI-Lab' }
    $asset = $rel.assets | Where-Object name -match $Pattern | Select-Object -First 1
    if (-not $asset) { throw "No asset matching '$Pattern' in latest release of $Repo" }
    Get-File $asset.browser_download_url (Join-Path $DestFolder $asset.name)
    $asset.name
}
function Set-Text([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    Set-Content -Path $Path -Value $Text -Encoding ASCII
}

New-Item -ItemType Directory -Path $Root -Force | Out-Null

# ---------------------------------------------------------------- Downloads
Invoke-Step '7-Zip 24.09 MSI' { Get-File 'https://www.7-zip.org/a/7z2409-x64.msi' "$Root\7-Zip\24.09\7z2409-x64.msi" }
Invoke-Step '7-Zip 25.01 MSI' { Get-File 'https://www.7-zip.org/a/7z2501-x64.msi' "$Root\7-Zip\25.01\7z2501-x64.msi" }
Invoke-Step 'PuTTY MSI'       { Get-File 'https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-installer.msi' "$Root\PuTTY\putty-64bit-installer.msi" }
Invoke-Step 'VC++ Redist x64' { Get-File 'https://aka.ms/vs/17/release/vc_redist.x64.exe' "$Root\VCRedist\vc_redist.x64.exe" }
Invoke-Step 'Firefox ESR MSI' { Get-File 'https://download.mozilla.org/?product=firefox-esr-msi-latest-ssl&os=win64&lang=en-US' "$Root\FirefoxESR\FirefoxESR.msi" }

Invoke-Step 'Notepad++ (GitHub latest)' {
    $name = Get-GitHubAsset 'notepad-plus-plus/notepad-plus-plus' '^npp\.[\d\.]+\.Installer\.x64\.exe$' "$Root\NotepadPP"
    # normalise to a fixed name so the ConfigMgr script does not need to know the version
    Copy-Item "$Root\NotepadPP\$name" "$Root\NotepadPP\npp-installer-x64.exe" -Force
}
Invoke-Step 'Greenshot (GitHub latest)' {
    $name = Get-GitHubAsset 'greenshot/greenshot' 'INSTALLER.*\.exe$' "$Root\Greenshot"
    Copy-Item "$Root\Greenshot\$name" "$Root\Greenshot\greenshot-installer.exe" -Force
}

# ---------------------------------------------------------------- Wrappers & dummy content
Invoke-Step 'Notepad++ Finance wrapper' {
    Set-Text "$Root\NotepadPP\Install-Finance.ps1" @'
# Finance edition: standard install + department config marker
$ErrorActionPreference = 'Stop'
$p = Start-Process "$PSScriptRoot\npp-installer-x64.exe" -ArgumentList '/S' -Wait -PassThru
if ($p.ExitCode -ne 0) { exit $p.ExitCode }
New-Item 'HKLM:\SOFTWARE\SmartETC\NotepadPP' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\SmartETC\NotepadPP' -Name Edition -Value 'Finance'
exit 0
'@
}

Invoke-Step 'Firefox ESR wrappers + policies.json' {
    Set-Text "$Root\FirefoxESR\policies.json" @'
{
  "policies": {
    "DisableAppUpdate": true,
    "DisableTelemetry": true,
    "Homepage": { "URL": "https://intranet.smart.etc", "Locked": true },
    "NoDefaultBookmarks": true
  }
}
'@
    Set-Text "$Root\FirefoxESR\Install-Firefox.ps1" @'
# Multi-step legacy install - the PSADT conversion candidate in M9
$ErrorActionPreference = 'Stop'
Get-Process firefox -ErrorAction SilentlyContinue | Stop-Process -Force
$p = Start-Process msiexec.exe -ArgumentList "/i `"$PSScriptRoot\FirefoxESR.msi`" /qn /norestart" -Wait -PassThru
if ($p.ExitCode -notin 0,3010) { exit $p.ExitCode }
$dist = "$env:ProgramFiles\Mozilla Firefox\distribution"
New-Item $dist -ItemType Directory -Force | Out-Null
Copy-Item "$PSScriptRoot\policies.json" $dist -Force
Remove-Item "$env:PUBLIC\Desktop\Firefox.lnk" -ErrorAction SilentlyContinue
exit $p.ExitCode
'@
    Set-Text "$Root\FirefoxESR\Uninstall-Firefox.ps1" @'
Get-Process firefox -ErrorAction SilentlyContinue | Stop-Process -Force
$h = "$env:ProgramFiles\Mozilla Firefox\uninstall\helper.exe"
if (Test-Path $h) { Start-Process $h -ArgumentList '/S' -Wait }
Remove-Item "$env:ProgramFiles\Mozilla Firefox" -Recurse -Force -ErrorAction SilentlyContinue
exit 0
'@
}

Invoke-Step 'Toolbox (broken detection)' {
    Set-Text "$Root\Toolbox\Install-Toolbox.ps1" @'
# Installs to ...\Toolbox - the deployment type detection looks in ...\Tools (deliberate error)
New-Item "$env:ProgramData\SmartETC\Toolbox" -ItemType Directory -Force | Out-Null
Set-Content "$env:ProgramData\SmartETC\Toolbox\toolbox.txt" -Value 'SmartETC Toolbox 2.3'
exit 0
'@
    Set-Text "$Root\Toolbox\Uninstall-Toolbox.ps1" @'
Remove-Item "$env:ProgramData\SmartETC\Toolbox" -Recurse -Force -ErrorAction SilentlyContinue
exit 0
'@
}

Invoke-Step 'Adobe Reader 2019 dummy content' {
    Set-Text "$Root\AdobeReader2019\README.txt" 'SCMI lab dummy content. Distributed, never deployed. Represents dead content in the assessment.'
}

Invoke-Step 'Legacy package SmartETC-Branding' {
    Set-Text "$Root\Legacy\SmartETC-Branding\install.cmd" @'
@echo off
rem Legacy package: department tag + branding. Usage: install.cmd <Department>
rem /reg:64 is required - package programs run in a 32-bit context and would otherwise
rem land in WOW6432Node (classic legacy trap, worth a slide in M8).
reg add HKLM\SOFTWARE\SmartETC /v Department      /t REG_SZ /d %1  /f /reg:64
reg add HKLM\SOFTWARE\SmartETC /v BrandingVersion /t REG_SZ /d 3.1 /f /reg:64
if not exist "%ProgramData%\SmartETC" mkdir "%ProgramData%\SmartETC"
copy /y "%~dp0support.txt" "%ProgramData%\SmartETC\support.txt" >nul
exit /b 0
'@
    Set-Text "$Root\Legacy\SmartETC-Branding\support.txt" 'SmartETC IT Service Desk - ext. 4711'
}

# ---------------------------------------------------------------- Share
Invoke-Step "Share $ShareName" {
    if (-not (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name $ShareName -Path $Root -ReadAccess 'Everyone' | Out-Null
    }
}

$Results | Format-Table -AutoSize
$Results | Export-Csv "$PSScriptRoot\02-Prepare-Sources-results.csv" -NoTypeInformation -Encoding UTF8

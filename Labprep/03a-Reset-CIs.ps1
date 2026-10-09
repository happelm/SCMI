<#
.SYNOPSIS
    SCMI Lab - one-off cleanup after the first 03-CM-Populate run on 2609.

.DESCRIPTION
    The first run created the four configuration items WITHOUT settings (RuleName was missing)
    and added these empty CIs to both baselines. This removes the two baselines and the four CIs
    so the next 03-CM-Populate run recreates them cleanly. Nothing is deployed at this point
    (deployments are gated behind -EnableDeployments), so the removal has no client impact.
    Run on the site server, then rerun 03-CM-Populate.ps1.
#>
param([string]$SiteCode = 'ETC', [string]$SiteServer = 'SCCM.smart.etc')
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $env:SMS_ADMIN_UI_PATH '..\ConfigurationManager.psd1')
if (-not (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer | Out-Null
}
Set-Location "$($SiteCode):\"
$CMPSSuppressFastNotUsedCheck = $true

foreach ($b in 'BL - Workstation Security','BL - Reporting Only') {
    if (Get-CMBaseline -Name $b -Fast) {
        if (Get-CMBaselineDeployment -Name $b) { Write-Warning "$b is deployed - remove the deployment first, skipped."; continue }
        Remove-CMBaseline -Name $b -Force; Write-Host "removed baseline $b"
    }
}
foreach ($c in 'CI - SmartETC Compliance Marker','CI - RemoteRegistry Disabled','CI - Local Administrators Count','CI - BitLocker OS Volume') {
    if (Get-CMConfigurationItem -Name $c -Fast) { Remove-CMConfigurationItem -Name $c -Force; Write-Host "removed CI $c" }
}
Set-Location C:\
Write-Host 'Done - now rerun 03-CM-Populate.ps1' -ForegroundColor Cyan

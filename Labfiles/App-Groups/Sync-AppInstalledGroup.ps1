<#
.SYNOPSIS
    Keeps an Entra security group in sync with the Windows devices on which Intune has
    discovered a given app. The cloud counterpart of a ConfigMgr query collection on
    installed software. Course example (SCMI) - not production code.

.DESCRIPTION
    Neither Entra dynamic groups nor Intune assignment filters can read installed software.
    This script bridges the gap with Intune Discovered apps:

      1. Reads deviceManagement/detectedApps and keeps the Windows entries whose display name
         matches -AppName (-like, so wildcards work). Every app version is its own entry.
         The server-side startswith filter is loose (lab: 'Notepad' also returned
         'Microsoft.WindowsNotepad'), so the script filters again on the client.
      2. Reads the devices of every matching entry (detectedApps/{id}/managedDevices). The
         relation returns stub objects without azureADDeviceId, so each device is read once
         more. Devices that return 404 (deleted, still listed under the app) are skipped.
      3. Resolves azureADDeviceId to the Entra device object.
      4. Compares with the direct device members of -GroupId: adds what is missing, removes
         what no longer has the app. Report mode (default) changes nothing.

    Data freshness (Learn, Intune Discovered apps): Win32 apps are collected by the Intune
    Management Extension every 24 hours. Co-managed devices whose client apps workload is
    still on Configuration Manager do not collect Win32 inventory through the IME - they
    only show up after the client apps workload has moved to Intune. New devices without a
    signed-in Entra user can take up to seven days for the first inventory.

    Safety nets:
      - -MaxChanges caps adds + removes per run.
      - If no device has the app, removals are skipped unless -AllowEmptyGroup is set
        (a broken inventory or a typo in -AppName must not empty the group).
      - The target group must be an assigned security group (no dynamic membership).
      - Members that are not devices (users, groups) are reported and left alone.

.PARAMETER AppName
    Display name as shown in Intune Discovered apps, wildcards allowed. Example: '7-Zip*'.

.PARAMETER GroupId
    Object ID of the target Entra security group (assigned membership).

.PARAMETER MaxChanges
    Upper limit of adds + removes per run.

.PARAMETER AllowEmptyGroup
    Allow removals even when no device with the app was found.

.PARAMETER ReportPath
    CSV report path. Default: temp folder (runbook sandbox or local).

.PARAMETER UseManagedIdentity
    Connect with the managed identity of the Automation account. Without it, the script
    connects interactively (demo on the trainer machine).

.PARAMETER Apply
    Without this switch nothing is changed (report only).

.EXAMPLE
    .\Sync-AppInstalledGroup.ps1 -AppName '7-Zip*' -GroupId <group-object-id>
    Report only, interactive sign-in.

.EXAMPLE
    .\Sync-AppInstalledGroup.ps1 -AppName '7-Zip*' -GroupId <group-object-id> -Apply
    Adds and removes devices, interactive sign-in.

.EXAMPLE
    .\Sync-AppInstalledGroup.ps1 -UseManagedIdentity -AppName '7-Zip*' -GroupId <group-object-id> -Apply -MaxChanges 100
    Runbook schedule (daily is enough: the inventory refreshes every 24 hours).

.NOTES
    Runtime : Windows PowerShell 5.1 or PowerShell 7.4 (Azure Automation runbook)
    Module  : Microsoft.Graph.Authentication (Invoke-MgGraphRequest only)
    Graph   : v1.0. Application or delegated permissions:
              DeviceManagementManagedDevices.Read.All   detectedApps, managedDevices
              Device.Read.All                           Entra device lookup
              GroupMember.ReadWrite.All                 read the group, add and remove members
    Checked with app-only Graph on 2026-11-28: the read calls of steps 1-3. Not run yet as a
    whole script, and the add/remove calls not run yet.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AppName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$GroupId,

    [ValidateRange(1, 10000)]
    [int]$MaxChanges = 50,

    [switch]$AllowEmptyGroup,

    [string]$ReportPath = (Join-Path ([System.IO.Path]::GetTempPath()) ("AppInstalledGroup-{0:yyyyMMdd-HHmm}.csv" -f (Get-Date))),

    [switch]$UseManagedIdentity,

    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$graph = 'https://graph.microsoft.com/v1.0'

# --- Connect ------------------------------------------------------------------------------
if ($UseManagedIdentity) {
    Connect-MgGraph -Identity -NoWelcome
} else {
    Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All', 'Device.Read.All', 'GroupMember.ReadWrite.All' -NoWelcome
}

# --- Helpers ------------------------------------------------------------------------------
function Get-GraphAll {
    param([string]$Uri)
    $items = New-Object System.Collections.Generic.List[object]
    while ($Uri) {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        foreach ($v in @($resp.value)) { if ($null -ne $v) { $items.Add($v) } }
        $Uri = $resp.'@odata.nextLink'
    }
    return $items.ToArray()   # unrolled: callers wrap with @()
}

function Get-HttpStatus {
    param($ErrorRecord)
    $r = $ErrorRecord.Exception.Response
    if ($r -and $r.StatusCode) { return [int]$r.StatusCode }
    if ($ErrorRecord.Exception.Message -match '\b(404|NotFound)\b') { return 404 }
    return 0
}

# --- 0. Target group ----------------------------------------------------------------------
$group = Invoke-MgGraphRequest -Method GET -OutputType PSObject `
         -Uri "$graph/groups/$GroupId`?`$select=id,displayName,groupTypes,securityEnabled"
if (@($group.groupTypes) -contains 'DynamicMembership') { throw "Group '$($group.displayName)' has dynamic membership. Use an assigned security group." }
if (-not $group.securityEnabled) { throw "Group '$($group.displayName)' is not a security group." }
Write-Output "Target group: $($group.displayName)"

# --- 1. Matching detected apps ------------------------------------------------------------
# Server-side pre-filter on the literal start of the pattern (loose), then -like on the client.
$prefix = ($AppName -split '[\*\?\[]')[0].Trim()
$uri = "$graph/deviceManagement/detectedApps?`$select=id,displayName,version,platform,deviceCount&`$top=100"
if ($prefix) {
    $filter = "startswith(displayName,'" + $prefix.Replace("'", "''") + "')"
    $uri += '&$filter=' + [uri]::EscapeDataString($filter)
}
$apps = @(@(Get-GraphAll $uri) | Where-Object { $_.displayName -like $AppName -and $_.platform -eq 'windows' })
Write-Output ("Matching app entries: {0} ({1})" -f $apps.Count, (($apps | ForEach-Object { "$($_.displayName) $($_.version)" }) -join '; '))

# --- 2. Devices per app entry -------------------------------------------------------------
$found = @{}   # managedDeviceId -> list of "name version"
foreach ($a in $apps) {
    foreach ($d in @(Get-GraphAll "$graph/deviceManagement/detectedApps/$($a.id)/managedDevices?`$select=id,deviceName")) {
        if (-not $found.ContainsKey($d.id)) { $found[$d.id] = New-Object System.Collections.Generic.List[string] }
        $found[$d.id].Add("$($a.displayName) $($a.version)")
    }
}

# --- 3. Resolve to Entra device objects ---------------------------------------------------
$rows    = New-Object System.Collections.Generic.List[object]
$desired = @{}   # Entra object id -> row
foreach ($mdId in $found.Keys) {
    $apps4dev = ($found[$mdId] | Sort-Object -Unique) -join '; '
    try {
        $md = Invoke-MgGraphRequest -Method GET -OutputType PSObject `
              -Uri "$graph/deviceManagement/managedDevices/$mdId`?`$select=id,deviceName,azureADDeviceId,managementAgent"
    } catch {
        if ((Get-HttpStatus $_) -eq 404) {
            $rows.Add([pscustomobject]@{ Device = $mdId; App = $apps4dev; Action = 'Skip'; Reason = 'Intune device not found (stale inventory)' }); continue
        }
        throw
    }
    if (-not $md.azureADDeviceId -or $md.azureADDeviceId -eq '00000000-0000-0000-0000-000000000000') {
        $rows.Add([pscustomobject]@{ Device = $md.deviceName; App = $apps4dev; Action = 'Skip'; Reason = 'No Entra device ID' }); continue
    }
    $ed = @(Get-GraphAll ("$graph/devices?`$select=id,displayName&`$filter=" + [uri]::EscapeDataString("deviceId eq '$($md.azureADDeviceId)'")))
    if ($ed.Count -ne 1) {
        $rows.Add([pscustomobject]@{ Device = $md.deviceName; App = $apps4dev; Action = 'Skip'; Reason = "Entra device objects found: $($ed.Count)" }); continue
    }
    $desired[$ed[0].id] = [pscustomobject]@{ Device = $md.deviceName; App = $apps4dev; Agent = $md.managementAgent }
}
Write-Output "Devices with the app: $($desired.Count)"

# --- 4. Compare with the group ------------------------------------------------------------
$members = @(Get-GraphAll "$graph/groups/$GroupId/members?`$select=id,displayName")
$current = @{}
foreach ($m in $members) {
    if ($m.'@odata.type' -eq '#microsoft.graph.device') { $current[$m.id] = $m.displayName }
    else { $rows.Add([pscustomobject]@{ Device = $m.displayName; App = ''; Action = 'Ignore'; Reason = "Member is $($m.'@odata.type'), not a device" }) }
}

$toAdd    = @($desired.Keys | Where-Object { -not $current.ContainsKey($_) })
$toRemove = @($current.Keys | Where-Object { -not $desired.ContainsKey($_) })
$keep     = @($desired.Keys | Where-Object { $current.ContainsKey($_) })
foreach ($id in $keep) { $rows.Add([pscustomobject]@{ Device = $desired[$id].Device; App = $desired[$id].App; Action = 'Keep'; Reason = 'Member, app found' }) }

if ($desired.Count -eq 0 -and $toRemove.Count -gt 0 -and -not $AllowEmptyGroup) {
    Write-Warning "No device with '$AppName' found - removals skipped. Check the app name, or use -AllowEmptyGroup."
    foreach ($id in $toRemove) { $rows.Add([pscustomobject]@{ Device = $current[$id]; App = ''; Action = 'Skip'; Reason = 'Removal blocked: no device has the app' }) }
    $toRemove = @()
}

# --- 5. Apply -----------------------------------------------------------------------------
$changes = 0
foreach ($id in $toAdd) {
    $row = [pscustomobject]@{ Device = $desired[$id].Device; App = $desired[$id].App; Action = 'Add'; Reason = 'App found, not a member' }
    if ($Apply) {
        if ($changes -ge $MaxChanges) { $row.Action = 'Skip'; $row.Reason = "MaxChanges ($MaxChanges) reached" }
        else {
            $body = @{ '@odata.id' = "$graph/directoryObjects/$id" } | ConvertTo-Json
            Invoke-MgGraphRequest -Method POST -Uri "$graph/groups/$GroupId/members/`$ref" -Body $body -ContentType 'application/json' | Out-Null
            $row.Action = 'Added'; $changes++
        }
    }
    $rows.Add($row)
}
foreach ($id in $toRemove) {
    $row = [pscustomobject]@{ Device = $current[$id]; App = ''; Action = 'Remove'; Reason = 'Member, app no longer found' }
    if ($Apply) {
        if ($changes -ge $MaxChanges) { $row.Action = 'Skip'; $row.Reason = "MaxChanges ($MaxChanges) reached" }
        else {
            Invoke-MgGraphRequest -Method DELETE -Uri "$graph/groups/$GroupId/members/$id/`$ref" | Out-Null
            $row.Action = 'Removed'; $changes++
        }
    }
    $rows.Add($row)
}

# --- Report -------------------------------------------------------------------------------
$rows | Sort-Object Action, Device | Export-Csv -Path $ReportPath -Delimiter ';' -Encoding UTF8 -NoTypeInformation
$rows | Sort-Object Action, Device | Format-Table Device, Action, Reason, App -AutoSize | Out-String -Width 250 | Write-Output
$mode = if ($Apply) { 'APPLIED' } else { 'REPORT ONLY - use -Apply to change the group' }
Write-Output ("{0}: add {1}, remove {2}, keep {3}. Report: {4}" -f $mode, $toAdd.Count, $toRemove.Count, $keep.Count, $ReportPath)

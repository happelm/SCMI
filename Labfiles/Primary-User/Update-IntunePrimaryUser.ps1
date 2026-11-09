<#
.SYNOPSIS
    Recalculates the Intune primary user of Windows devices from the last logged-on users.
    Course example (SCMI) - not production code.

.DESCRIPTION
    Intune sets the primary user during or right after enrollment and never recalculates it.
    This runbook approximates the ConfigMgr user device affinity:

      1. Reads all Intune-managed devices and keeps corporate Windows devices that are
         Entra joined or hybrid joined (the only join types where Learn supports a change).
      2. Reads per device, via Graph $batch:
           - usersLoggedOn      (userId + lastLogOnDateTime, beta only)
           - the users relation (the current primary user; more reliable than the
                                 userPrincipalName property of managedDevice)
      3. Builds the list of eligible users who logged on inside the lookback window
         (drops unknown/local accounts, UPN patterns, members of an exclusion group,
         disabled users and users without the Intune service plan).
      4. Applies the rule (-Mode):
           SoleUser       exactly one eligible user logged on in the window and it is not
                          the current primary user. Default, most conservative.
           PrimaryAbsent  the current primary user did not log on in the window; the
                          eligible user with the most recent logon becomes primary user.
      5. Report mode (default) writes a CSV and changes nothing. -Apply changes the primary
         user, capped by -MaxChanges, and re-reads the users relation to confirm.

    Limitation: usersLoggedOn holds the last logon per user, not usage time. This is an
    approximation, not the ConfigMgr usage-minutes logic.

    VERIFY before production use:
      - POST managedDevices/{id}/users/$ref sets the primary user in community scripts and
        modules. Microsoft Learn documents only reading the users relationship.
      - Whether POST replaces an existing primary user or a DELETE .../users/$ref is needed
        first. The script re-reads the relation after the POST and reports what it finds.
      - Application permission for the write: DeviceManagementManagedDevices.ReadWrite.All
        (community sources). Delegated admins need the Intune RBAC permission
        Managed devices/Set primary user (Learn).
      - Whether usersLoggedOn also contains local accounts and how it behaves with
        Fast User Switching or RDP sessions.

.PARAMETER LookbackDays
    Only logons newer than this count.

.PARAMETER Mode
    SoleUser (default) or PrimaryAbsent, see description.

.PARAMETER ExcludeUpnPattern
    -like patterns for accounts that never become primary user (admin, service accounts).

.PARAMETER ExcludeUserGroupId
    Object ID of an Entra group whose (transitive) user members never become primary user.

.PARAMETER ExcludeDeviceCategory
    Intune device categories to skip (shared, kiosk, lab).

.PARAMETER ExcludeDeviceNamePattern
    -like patterns for device names to skip.

.PARAMETER IncludeDevicesWithoutPrimaryUser
    By default devices without a primary user are skipped, because Intune treats them as
    shared devices (Learn). Use this switch to assign a primary user to them too.

.PARAMETER MaxChanges
    Upper limit of changes per run (safety net against a broken rule or bad data).

.PARAMETER ReportPath
    CSV report path. Default: temp folder of the runbook sandbox.

.PARAMETER UseManagedIdentity
    Connect with the managed identity of the Automation account. Without it, the script
    connects interactively (for testing on an admin workstation).

.PARAMETER Apply
    Without this switch nothing is changed (report only).

.EXAMPLE
    .\Update-IntunePrimaryUser.ps1 -LookbackDays 14
    Report only, interactive sign-in.

.EXAMPLE
    .\Update-IntunePrimaryUser.ps1 -UseManagedIdentity -LookbackDays 14 -Mode SoleUser -MaxChanges 25 -Apply
    Runbook schedule, changes up to 25 devices.

.NOTES
    Runtime : Azure Automation, PowerShell 7.4 runbook
    Module  : Microsoft.Graph.Authentication (Invoke-MgGraphRequest only)
    Identity: system-assigned managed identity with Graph application permissions
              DeviceManagementManagedDevices.ReadWrite.All   read devices, set primary user
              User.Read.All                                 resolve users, license check
              GroupMember.Read.All                          only with -ExcludeUserGroupId
    Intune service plan INTUNE_A = c1ec4a95-1f05-45b3-a911-aa3fa01094f5 (Learn licensing
    service plan reference). It is part of all suites that include Intune Plan 1.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 90)]
    [int]$LookbackDays = 14,

    [ValidateSet('SoleUser', 'PrimaryAbsent')]
    [string]$Mode = 'SoleUser',

    [string[]]$ExcludeUpnPattern = @('adm-*', 'admin*', 'svc-*', '*-admin@*'),

    [string]$ExcludeUserGroupId,

    [string[]]$ExcludeDeviceCategory = @('Shared', 'Kiosk'),

    [string[]]$ExcludeDeviceNamePattern = @(),

    [switch]$IncludeDevicesWithoutPrimaryUser,

    [ValidateRange(1, 10000)]
    [int]$MaxChanges = 50,

    [string]$ReportPath = (Join-Path ([System.IO.Path]::GetTempPath()) ("IntunePrimaryUser-{0:yyyyMMdd-HHmm}.csv" -f (Get-Date))),

    [switch]$UseManagedIdentity,

    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$graph      = 'https://graph.microsoft.com/beta'
$intunePlan = 'c1ec4a95-1f05-45b3-a911-aa3fa01094f5'   # INTUNE_A (Learn service plan reference)
$batchSize  = 10                                        # 2 requests per device, $batch max = 20

# --- Connect ------------------------------------------------------------------------------
if ($UseManagedIdentity) {
    Connect-MgGraph -Identity -NoWelcome
} else {
    $scopes = @('DeviceManagementManagedDevices.ReadWrite.All', 'User.Read.All')
    if ($ExcludeUserGroupId) { $scopes += 'GroupMember.Read.All' }
    Connect-MgGraph -Scopes $scopes -NoWelcome
}

# --- Helpers ------------------------------------------------------------------------------
function Get-GraphAll {
    param([string]$Uri)
    $items = [System.Collections.Generic.List[object]]::new()
    while ($Uri) {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        foreach ($v in @($resp.value)) { if ($null -ne $v) { $items.Add($v) } }
        $Uri = $resp.'@odata.nextLink'
    }
    return , $items
}

function Invoke-GraphBatch {
    # Sends up to 20 requests; retries sub-requests that return 429/503/504.
    param([object[]]$Requests)
    $results = @{}
    $pending = @($Requests)
    for ($attempt = 1; $pending.Count -gt 0 -and $attempt -le 4; $attempt++) {
        $body = @{ requests = $pending } | ConvertTo-Json -Depth 6
        $resp = Invoke-MgGraphRequest -Method POST -Uri "$graph/`$batch" -Body $body -ContentType 'application/json' -OutputType PSObject
        $retry = @(); $wait = 0
        foreach ($r in $resp.responses) {
            if ($r.status -in 429, 503, 504) {
                $retry += @($pending | Where-Object { $_.id -eq $r.id })
                $ra = $r.headers.'Retry-After'
                if ($ra -and [int]$ra -gt $wait) { $wait = [int]$ra }
            } else {
                $results[$r.id] = $r
            }
        }
        $pending = $retry
        if ($pending.Count -gt 0) { Start-Sleep -Seconds ([Math]::Max($wait, 5 * $attempt)) }
    }
    foreach ($p in $pending) { $results[$p.id] = [pscustomobject]@{ id = $p.id; status = 429; body = $null } }
    return $results
}

$userCache = @{}
function Get-UserInfo {
    # Returns $null for IDs that are not Entra users (local accounts, deleted users).
    param([string]$UserId)
    if ([string]::IsNullOrWhiteSpace($UserId)) { return $null }
    if (-not $userCache.ContainsKey($UserId)) {
        try {
            $u = Invoke-MgGraphRequest -Method GET -OutputType PSObject `
                 -Uri "$graph/users/$UserId`?`$select=id,userPrincipalName,accountEnabled,assignedPlans"
            $userCache[$UserId] = [pscustomobject]@{
                Id        = $u.id
                Upn       = $u.userPrincipalName
                Enabled   = [bool]$u.accountEnabled
                HasIntune = [bool](@($u.assignedPlans) | Where-Object {
                                $_.servicePlanId -eq $intunePlan -and $_.capabilityStatus -eq 'Enabled' })
            }
        } catch {
            $userCache[$UserId] = $null
        }
    }
    return $userCache[$UserId]
}

# --- Exclusion group ----------------------------------------------------------------------
$excludedUserIds = @{}
if ($ExcludeUserGroupId) {
    foreach ($m in (Get-GraphAll "$graph/groups/$ExcludeUserGroupId/transitiveMembers")) {
        if ($m.'@odata.type' -eq '#microsoft.graph.user') { $excludedUserIds[$m.id] = $true }
    }
    Write-Output "Excluded users from group: $($excludedUserIds.Count)"
}

# --- 1. Devices ---------------------------------------------------------------------------
# Filtered client-side: Learn documents $filter support only for some managedDevice properties.
$select  = 'id,deviceName,operatingSystem,joinType,managedDeviceOwnerType,deviceCategoryDisplayName'
$all     = Get-GraphAll "$graph/deviceManagement/managedDevices?`$select=$select"
$devices = @($all | Where-Object {
    $_.operatingSystem -eq 'Windows' -and
    $_.managedDeviceOwnerType -eq 'company' -and
    $_.joinType -in 'azureADJoined', 'hybridAzureADJoined'
})
Write-Output "Managed devices: $($all.Count) / in scope (corporate Windows, Entra or hybrid joined): $($devices.Count)"

# --- 2. usersLoggedOn + current primary user via $batch -----------------------------------
$loggedOn = @{}
$primary  = @{}
for ($i = 0; $i -lt $devices.Count; $i += $batchSize) {
    $chunk    = @($devices[$i..([Math]::Min($i + $batchSize - 1, $devices.Count - 1))])
    $requests = foreach ($d in $chunk) {
        @{ id = "$($d.id)|logon"; method = 'GET'; url = "/deviceManagement/managedDevices/$($d.id)?`$select=id,usersLoggedOn" }
        @{ id = "$($d.id)|users"; method = 'GET'; url = "/deviceManagement/managedDevices/$($d.id)/users?`$select=id,userPrincipalName" }
    }
    $res = Invoke-GraphBatch -Requests @($requests)
    foreach ($d in $chunk) {
        $l = $res["$($d.id)|logon"]; $u = $res["$($d.id)|users"]
        $loggedOn[$d.id] = if ($l.status -eq 200) { , @($l.body.usersLoggedOn | Where-Object { $_ }) } else { $null }
        $primary[$d.id]  = if ($u.status -eq 200) { @($u.body.value)[0] } else { 'ERROR' }
    }
}

# --- 3./4. Decide and (optionally) apply --------------------------------------------------
$since   = (Get-Date).ToUniversalTime().AddDays(-$LookbackDays)
$changes = 0

$report = foreach ($d in $devices) {
    $cur = $primary[$d.id]
    $row = [ordered]@{
        DeviceName      = $d.deviceName
        ManagedDeviceId = $d.id
        JoinType        = $d.joinType
        Category        = $d.deviceCategoryDisplayName
        CurrentPrimary  = if ($cur -and $cur -ne 'ERROR') { $cur.userPrincipalName } else { $null }
        Candidate       = $null
        CandidateLogon  = $null
        EligibleLogons  = $null
        Action          = 'None'
        Reason          = $null
    }

    if ($cur -eq 'ERROR' -or $null -eq $loggedOn[$d.id]) {
        $row.Action = 'Error'; $row.Reason = 'Could not read usersLoggedOn or users relation'
        [pscustomobject]$row; continue
    }
    if ($d.deviceCategoryDisplayName -and $d.deviceCategoryDisplayName -in $ExcludeDeviceCategory) {
        $row.Reason = 'Device category excluded'; [pscustomobject]$row; continue
    }
    if (@($ExcludeDeviceNamePattern | Where-Object { $d.deviceName -like $_ }).Count -gt 0) {
        $row.Reason = 'Device name excluded'; [pscustomobject]$row; continue
    }
    if (-not $cur -and -not $IncludeDevicesWithoutPrimaryUser) {
        $row.Reason = 'No primary user (shared device)'; [pscustomobject]$row; continue
    }

    # Logons in window, newest first
    $recent = @($loggedOn[$d.id] | Where-Object {
                    $_.lastLogOnDateTime -and ([datetime]$_.lastLogOnDateTime).ToUniversalTime() -ge $since } |
                Sort-Object { [datetime]$_.lastLogOnDateTime } -Descending)

    $primaryLoggedOn = [bool]($cur -and @($recent | Where-Object { $_.userId -eq $cur.id }).Count -gt 0)

    # Eligible users only
    $eligible = @(foreach ($l in $recent) {
        $info = Get-UserInfo $l.userId
        if (-not $info)                                                              { continue }
        if ($excludedUserIds.ContainsKey($info.Id))                                  { continue }
        if (@($ExcludeUpnPattern | Where-Object { $info.Upn -like $_ }).Count -gt 0) { continue }
        if (-not $info.Enabled -or -not $info.HasIntune)                             { continue }
        [pscustomobject]@{ Id = $info.Id; Upn = $info.Upn; Last = $l.lastLogOnDateTime }
    })
    $row.EligibleLogons = ($eligible.Upn -join ';')

    if ($eligible.Count -eq 0) {
        $row.Reason = "No eligible logon in $LookbackDays days"; [pscustomobject]$row; continue
    }
    # No switch statement here: 'continue' inside switch would not skip to the next device.
    if ($Mode -eq 'SoleUser' -and @($eligible.Id | Select-Object -Unique).Count -gt 1) {
        $row.Reason = 'Several eligible users in window'; [pscustomobject]$row; continue
    }
    if ($Mode -eq 'PrimaryAbsent' -and $primaryLoggedOn) {
        $row.Reason = 'Primary user logged on in window'; [pscustomobject]$row; continue
    }

    $cand = $eligible[0]
    $row.Candidate      = $cand.Upn
    $row.CandidateLogon = $cand.Last

    if ($cur -and $cand.Id -eq $cur.id) {
        $row.Reason = 'Already primary user'; [pscustomobject]$row; continue
    }
    if (-not $Apply) {
        $row.Action = 'WouldChange'; [pscustomobject]$row; continue
    }
    if ($changes -ge $MaxChanges) {
        $row.Action = 'Skipped'; $row.Reason = "MaxChanges ($MaxChanges) reached"; [pscustomobject]$row; continue
    }

    try {
        # VERIFY: community-documented write, see header
        $ref = @{ '@odata.id' = "$graph/users/$($cand.Id)" } | ConvertTo-Json
        Invoke-MgGraphRequest -Method POST -Uri "$graph/deviceManagement/managedDevices/$($d.id)/users/`$ref" `
                              -Body $ref -ContentType 'application/json' | Out-Null
        $changes++
        $after = @((Invoke-MgGraphRequest -Method GET -OutputType PSObject `
                    -Uri "$graph/deviceManagement/managedDevices/$($d.id)/users?`$select=id,userPrincipalName").value)
        if ($after.Count -eq 1 -and $after[0].id -eq $cand.Id) {
            $row.Action = 'Changed'
        } else {
            # Learn: up to 10 minutes until the change shows in Intune and Entra
            $row.Action = 'ChangedUnconfirmed'
            $row.Reason = "users relation now: $($after.userPrincipalName -join ';')"
        }
    } catch {
        $row.Action = 'Failed'; $row.Reason = $_.Exception.Message
    }
    [pscustomobject]$row
}

# --- 5. Report ----------------------------------------------------------------------------
$report | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding utf8
Write-Output ("Mode: {0} / Lookback: {1} days / Apply: {2}" -f $Mode, $LookbackDays, [bool]$Apply)
$report | Group-Object Action | Sort-Object Name | Select-Object Name, Count |
    Format-Table -AutoSize | Out-String -Width 250 | Write-Output   # explicit width: no console in the sandbox
$report | Where-Object { $_.Action -in 'WouldChange', 'Changed', 'ChangedUnconfirmed', 'Failed' } |
    Select-Object DeviceName, CurrentPrimary, Candidate, CandidateLogon, Action, Reason |
    Format-Table -AutoSize | Out-String -Width 250 | Write-Output
Write-Output "Report: $ReportPath"

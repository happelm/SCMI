<#
.SYNOPSIS
    SCMI Lab - Step 1: AD structure, users, groups and GPOs for the ConfigMgr-to-Intune migration workshop.

.DESCRIPTION
    Run on the domain controller (smart.etc) as Domain Admin.
    Idempotent: existing objects are skipped, not recreated.

    Fits the existing course image: OU=Cloud is the Cloud Sync scope and holds User1/User2 and
    the domain-joined clients CL1/CL2. This script keeps that scope intact:

      OU=Cloud                                (sync scope - unchanged)
        OU=Workstations\{Finance,Sales}       CL1 -> Finance, CL2 -> Sales (still inside the scope)
      OU=Company                              (NOT synced - deliberately)
        OU=Users\{Finance,Sales}              5 additional on-prem-only users (realism, AD user discovery)
        OU=Groups                             GG-Finance, GG-Sales, GG-App-PuTTY (ConfigMgr targeting only)

    User1 is added to GG-Finance + GG-App-PuTTY, User2 to GG-Sales, so user-targeted
    ConfigMgr deployments reach the accounts the participants actually log on with.

      - 4 GPOs linked to Cloud\Workstations:
          GPO-01  fully MDM-mappable (Group Policy Analytics "green")
          GPO-02  legacy mix (preferences + settings with no MDM equivalent)
          GPO-03  loopback + WMI filter (semantic loss demo, harmless in lab: filter targets laptops only)
          GPO-04  conflict demo for M7 (ADMX-backed setting that the Intune profile will set the other way)

    Sync scope: Cloud Sync OU scoping includes child OUs, so CL1/CL2 stay in scope after the move.
    Verify once in the scoping filter of the Cloud Sync configuration after the first run.

    Shared image:
      Default = GPO links are created DISABLED, so Intune course demos are not affected.
      For SCMI run again with -EnableGpoLinks (idempotent, only flips the link state).
#>
[CmdletBinding()]
param(
    [string]   $DomainDN        = 'DC=smart,DC=etc',
    [string]   $DnsDomain       = 'smart.etc',
    [string]   $SyncRootOU      = 'OU=Cloud,DC=smart,DC=etc',
    [hashtable]$ClientPlacement = @{ 'CL1' = 'Finance'; 'CL2' = 'Sales' },
    [hashtable]$SyncedUsers     = @{ 'User1' = @('GG-Finance','GG-App-PuTTY'); 'User2' = @('GG-Sales') },
    [switch]   $SkipComputerMove,
    [switch]   $EnableGpoLinks      # default: GPOs are linked but DISABLED (shared image with Intune courses)
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory, GroupPolicy

$Results = [System.Collections.Generic.List[object]]::new()
function Invoke-Step {
    param([string]$Name, [scriptblock]$Action)
    try   { & $Action; Write-Host "[OK]   $Name" -ForegroundColor Green;  $Results.Add([pscustomobject]@{Step=$Name;Status='OK';Error=''}) }
    catch { Write-Warning "[FAIL] $Name :: $($_.Exception.Message)";       $Results.Add([pscustomobject]@{Step=$Name;Status='FAIL';Error=$_.Exception.Message}) }
}

function New-OUIfMissing {
    param([string]$Name, [string]$Path)
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -SearchScope OneLevel -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $false
    }
}

# ---------------------------------------------------------------- OUs
$CompanyOU = "OU=Company,$DomainDN"
$WksOU     = "OU=Workstations,$SyncRootOU"
$UsersOU   = "OU=Users,$CompanyOU"
$GroupsOU  = "OU=Groups,$CompanyOU"

Invoke-Step 'OU structure' {
    Get-ADOrganizationalUnit -Identity $SyncRootOU | Out-Null   # throws if the sync root does not exist
    New-OUIfMissing 'Workstations' $SyncRootOU
    New-OUIfMissing 'Company'      $DomainDN
    New-OUIfMissing 'Users'        $CompanyOU
    New-OUIfMissing 'Groups'       $CompanyOU
    foreach ($d in 'Finance','Sales') { New-OUIfMissing $d $WksOU; New-OUIfMissing $d $UsersOU }
}

# ---------------------------------------------------------------- Users & groups
$users = @(
    @{ Sam='anna.berger';   Given='Anna';   Sur='Berger'; Dept='Finance' },
    @{ Sam='markus.huber';  Given='Markus'; Sur='Huber';  Dept='Finance' },
    @{ Sam='julia.wagner';  Given='Julia';  Sur='Wagner'; Dept='Sales'   },
    @{ Sam='thomas.gruber'; Given='Thomas'; Sur='Gruber'; Dept='Sales'   },
    @{ Sam='lisa.moser';    Given='Lisa';   Sur='Moser';  Dept='Sales'   }
)
$missing = @($users | Where-Object { -not (Get-ADUser -Filter "SamAccountName -eq '$($_.Sam)'" -ErrorAction SilentlyContinue) })
if ($missing.Count) { $pw = Read-Host -AsSecureString "Password for $($missing.Count) new lab user(s)" }
Invoke-Step 'Users' {
    foreach ($u in $missing) {
        New-ADUser -Name "$($u.Given) $($u.Sur)" -GivenName $u.Given -Surname $u.Sur `
            -SamAccountName $u.Sam -UserPrincipalName "$($u.Sam)@$DnsDomain" `
            -Department $u.Dept -Path "OU=$($u.Dept),$UsersOU" `
            -AccountPassword $pw -Enabled $true -PasswordNeverExpires $true
    }
}

Invoke-Step 'Groups + membership' {
    foreach ($g in 'GG-Finance','GG-Sales','GG-App-PuTTY') {
        if (-not (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path $GroupsOU
        }
    }
    Add-ADGroupMember GG-Finance   -Members ($users | ? Dept -eq 'Finance' | % Sam)
    Add-ADGroupMember GG-Sales     -Members ($users | ? Dept -eq 'Sales'   | % Sam)
    Add-ADGroupMember GG-App-PuTTY -Members 'anna.berger','julia.wagner'
    foreach ($u in $SyncedUsers.Keys) {
        $adu = Get-ADUser -Filter "SamAccountName -eq '$u'" -ErrorAction SilentlyContinue
        if (-not $adu) { Write-Warning "Synced user $u not found - skipped"; continue }
        foreach ($g in $SyncedUsers[$u]) { Add-ADGroupMember $g -Members $adu }
    }
}

# ---------------------------------------------------------------- Computers
if (-not $SkipComputerMove) {
    foreach ($c in $ClientPlacement.Keys) {
        Invoke-Step "Move $c -> $($ClientPlacement[$c])" {
            Get-ADComputer $c | Move-ADObject -TargetPath "OU=$($ClientPlacement[$c]),$WksOU"
        }
    }
} else { Write-Host 'Computer move skipped.' -ForegroundColor Yellow }

# ---------------------------------------------------------------- GPO helpers
$LinkState = if ($EnableGpoLinks) { 'Yes' } else { 'No' }
function Get-OrNewGPO([string]$Name, [string]$Comment) {
    $g = Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if (-not $g) { $g = New-GPO -Name $Name -Comment $Comment }
    $linked = @((Get-GPInheritance -Target $WksOU).GpoLinks | ForEach-Object DisplayName)
    if ($linked -notcontains $Name) {
        New-GPLink -Name $Name -Target $WksOU -LinkEnabled $LinkState | Out-Null
    } else {
        Set-GPLink -Name $Name -Target $WksOU -LinkEnabled $LinkState | Out-Null
    }
    $g
}

# GPO-01: fully MDM-mappable -----------------------------------------------------------
Invoke-Step 'GPO-01 WS - Edge & Defender Baseline' {
    $n = 'GPO-01 WS - Edge & Defender Baseline'
    Get-OrNewGPO $n 'SCMI: fully MDM mappable, expected green in Group Policy Analytics' | Out-Null
    $edge = 'HKLM\SOFTWARE\Policies\Microsoft\Edge'
    Set-GPRegistryValue -Name $n -Key $edge -ValueName 'HomepageLocation'     -Type String -Value 'https://intranet.smart.etc' | Out-Null
    Set-GPRegistryValue -Name $n -Key $edge -ValueName 'HomepageIsNewTabPage' -Type DWord  -Value 0 | Out-Null
    Set-GPRegistryValue -Name $n -Key $edge -ValueName 'ShowHomeButton'       -Type DWord  -Value 1 | Out-Null
    Set-GPRegistryValue -Name $n -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender' -ValueName 'PUAProtection'     -Type DWord  -Value 1 | Out-Null
    Set-GPRegistryValue -Name $n -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'   -ValueName 'EnableSmartScreen' -Type DWord  -Value 1 | Out-Null
    Set-GPRegistryValue -Name $n -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'   -ValueName 'ShellSmartScreenLevel' -Type String -Value 'Block' | Out-Null
}

# GPO-02: legacy mix -------------------------------------------------------------------
Invoke-Step 'GPO-02 WS - Legacy Mix' {
    $n = 'GPO-02 WS - Legacy Mix'
    Get-OrNewGPO $n 'SCMI: preferences + settings without MDM equivalent. Add drive map / logon script / folder redirection manually (see README).' | Out-Null
    # Group Policy Preference registry item -> not analysed as MDM-supported
    Set-GPPrefRegistryValue -Name $n -Context Computer -Action Update -Key 'HKLM\SOFTWARE\SmartETC' -ValueName 'LegacyGPP' -Type DWord -Value 1 | Out-Null
    # Offline Files
    Set-GPRegistryValue -Name $n -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows\NetCache' -ValueName 'Enabled' -Type DWord -Value 1 | Out-Null
    # User-side screensaver policy
    Set-GPRegistryValue -Name $n -Key 'HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop' -ValueName 'ScreenSaveActive'  -Type String -Value '1'   | Out-Null
    Set-GPRegistryValue -Name $n -Key 'HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop' -ValueName 'ScreenSaveTimeOut' -Type String -Value '900' | Out-Null
}

# GPO-03: loopback + WMI filter ------------------------------------------------------
Invoke-Step 'GPO-03 WS - Laptop Loopback (WMI filtered)' {
    $n = 'GPO-03 WS - Laptop Loopback (WMI filtered)'
    $gpo = Get-OrNewGPO $n 'SCMI: loopback merge + WMI filter (laptops). No effect on Hyper-V VMs by design.'
    Set-GPRegistryValue -Name $n -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' -ValueName 'UserPolicyMode' -Type DWord -Value 1 | Out-Null
    Set-GPRegistryValue -Name $n -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -ValueName 'NoControlPanel' -Type DWord -Value 1 | Out-Null

    # WMI filter via msWMI-Som object (no native cmdlet exists)
    $filterName = 'WMI - Laptops only'
    $query      = 'SELECT * FROM Win32_SystemEnclosure WHERE ChassisTypes = 8 OR ChassisTypes = 9 OR ChassisTypes = 10 OR ChassisTypes = 14'
    $somPath    = "CN=SOM,CN=WMIPolicy,CN=System,$DomainDN"
    $existing   = Get-ADObject -SearchBase $somPath -Filter "msWMI-Name -eq '$filterName'" -Properties 'msWMI-ID' -ErrorAction SilentlyContinue
    if ($existing) {
        $id = $existing.'msWMI-ID'
    } else {
        $id  = "{$([guid]::NewGuid().ToString().ToUpper())}"
        $now = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss.ffffff-000')
        New-ADObject -Name $id -Type 'msWMI-Som' -Path $somPath -OtherAttributes @{
            'msWMI-Name'         = $filterName
            'msWMI-Parm1'        = 'SCMI lab: matches laptop chassis types only'
            'msWMI-Parm2'        = "1;3;10;$($query.Length);WQL;root\CIMv2;$query;"
            'msWMI-Author'       = "$env:USERNAME@$DnsDomain"
            'msWMI-ID'           = $id
            'instanceType'       = 4
            'showInAdvancedViewOnly' = 'TRUE'
            'msWMI-ChangeDate'   = $now
            'msWMI-CreationDate' = $now
        }
    }
    $gpoDN = "CN={$($gpo.Id.ToString().ToUpper())},CN=Policies,CN=System,$DomainDN"
    Set-ADObject -Identity $gpoDN -Replace @{ gPCWQLFilter = "[$DnsDomain;$id;0]" }
}

# GPO-04: conflict demo --------------------------------------------------------------
Invoke-Step 'GPO-04 WS - Lock Screen Camera (Conflict Demo)' {
    $n = 'GPO-04 WS - Lock Screen Camera (Conflict Demo)'
    Get-OrNewGPO $n 'SCMI M7: conflicts with Intune DeviceLock/PreventEnablingLockScreenCamera' | Out-Null
    Set-GPRegistryValue -Name $n -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization' -ValueName 'NoLockScreenCamera' -Type DWord -Value 1 | Out-Null
}

# ---------------------------------------------------------------- Summary
$Results | Format-Table -AutoSize
$Results | Export-Csv "$PSScriptRoot\01-AD-Populate-results.csv" -NoTypeInformation -Encoding UTF8

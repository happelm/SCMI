<#
.SYNOPSIS
    SCMI Lab - Step 3: populate the ConfigMgr site with realistic "grown" content.

.DESCRIPTION
    Run on the site server in an elevated PowerShell with the ConfigMgr console installed.
    Recommended start (a missing mandatory parameter then FAILS the step instead of prompting):
        powershell.exe -NonInteractive -ExecutionPolicy Bypass -File .\03-CM-Populate.ps1
    Requires 01-AD-Populate.ps1 and 02-Prepare-Sources.ps1 to have run first.
    Idempotent: objects that exist by name are skipped. Every step is wrapped - a failing
    step is logged and the script continues. Check 03-CM-Populate-results.csv afterwards.

    Shared image: by default only OBJECTS are created (apps, collections, CIs, baselines, client
    settings, policies). Nothing is deployed, so Intune course demos (e.g. 7-Zip as Win32 app)
    are not pre-empted. For SCMI run again with -EnableDeployments (idempotent).

    Written against the documented ConfigurationManager module cmdlets; NOT yet executed
    against a 2609 site. Steps marked [VERIFY] use cmdlets whose parameter sets have
    changed between releases in the past.
#>
[CmdletBinding()]
param(
    [string]$SiteCode   = 'ETC',
    [string]$SiteServer = 'SCCM.smart.etc',
    [string]$NetBIOS    = 'SMART',
    [string]$DomainDN   = 'DC=smart,DC=etc',
    [string]$WksOUPath  = 'SMART.ETC/CLOUD/WORKSTATIONS',   # SystemOUName format of OU=Workstations,OU=Cloud
    [string]$Src        = '\\SCCM\Software$',
    [string]$BranchRange = '10.99.0.1-10.99.0.254',  # fictional branch office "Graz"
    [switch]$EnableDeployments   # default OFF: objects only, nothing lands on clients (shared image with Intune courses)
)

$ErrorActionPreference = 'Stop'
$Results = [System.Collections.Generic.List[object]]::new()
function Invoke-Step {
    param([string]$Name, [scriptblock]$Action)
    try   { & $Action; Write-Host "[OK]   $Name" -ForegroundColor Green;  $Results.Add([pscustomobject]@{Step=$Name;Status='OK';Error=''}) }
    catch { Write-Warning "[FAIL] $Name :: $($_.Exception.Message)";       $Results.Add([pscustomobject]@{Step=$Name;Status='FAIL';Error=$_.Exception.Message}) }
}

# ---------------------------------------------------------------- Connect
# Values that need the file system are resolved BEFORE switching to the CMSite drive.
$hqIp = (Get-NetIPAddress -AddressFamily IPv4 |
         Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
         Select-Object -First 1).IPAddress
$hqRange = ($hqIp -replace '\.\d+$', '.1') + '-' + ($hqIp -replace '\.\d+$', '.254')

Import-Module (Join-Path $env:SMS_ADMIN_UI_PATH '..\ConfigurationManager.psd1')
if (-not (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer | Out-Null
}
Set-Location "$($SiteCode):\"
$CMPSSuppressFastNotUsedCheck = $true

function Invoke-IgnoreExisting([scriptblock]$Action) {
    try { & $Action } catch { if ($_.Exception.Message -notmatch 'already') { throw } }
}

$Now = Get-Date
function Sched-Daily { New-CMSchedule -RecurInterval Days -RecurCount 1 -Start $Now }

# =============================================================================================
# 1. Site basics: boundaries, discovery
# =============================================================================================
function Get-OrNewIPRangeBoundary([string]$Name, [string]$Range) {
    # ConfigMgr enforces unique boundary values - reuse one that already covers this range, whatever its name
    $b = Get-CMBoundary | Where-Object { $_.BoundaryType -eq 3 -and $_.Value -eq $Range } | Select-Object -First 1
    if (-not $b) { $b = Get-CMBoundary -BoundaryName $Name }
    if (-not $b) { $b = New-CMBoundary -Name $Name -Type IPRange -Value $Range }
    $b
}
Invoke-Step "Boundary HQ ($hqRange)" {
    $b = Get-OrNewIPRangeBoundary 'Vienna HQ' $hqRange
    if ($b.DisplayName -ne 'Vienna HQ') { Write-Host "       reusing existing boundary '$($b.DisplayName)' for $hqRange" -ForegroundColor Yellow }
    if (-not (Get-CMBoundaryGroup -Name 'BG - Vienna HQ')) {
        New-CMBoundaryGroup -Name 'BG - Vienna HQ' -DefaultSiteCode $SiteCode | Out-Null
    }
    Invoke-IgnoreExisting { Add-CMBoundaryToGroup -BoundaryId $b.BoundaryID -BoundaryGroupName 'BG - Vienna HQ' }
    Invoke-IgnoreExisting { Set-CMBoundaryGroup -Name 'BG - Vienna HQ' -AddSiteSystemServerName $SiteServer }
}
Invoke-Step "Boundary Branch Graz ($BranchRange)" {
    if (-not (Get-CMBoundary -BoundaryName 'Branch Graz')) {
        New-CMBoundary -Name 'Branch Graz' -Type IPRange -Value $BranchRange | Out-Null
    }
    if (-not (Get-CMBoundaryGroup -Name 'BG - Branch Graz')) {
        New-CMBoundaryGroup -Name 'BG - Branch Graz' | Out-Null   # no site system: content falls back / peer cache discussion in M11
    }
    Invoke-IgnoreExisting { Add-CMBoundaryToGroup -BoundaryName 'Branch Graz' -BoundaryGroupName 'BG - Branch Graz' }
}

Invoke-Step 'AD System + User Discovery on OU=Cloud and OU=Company [VERIFY]' {
    $ldap = @("LDAP://OU=Cloud,$DomainDN", "LDAP://OU=Company,$DomainDN")
    Set-CMDiscoveryMethod -ActiveDirectorySystemDiscovery -SiteCode $SiteCode -Enabled $true -AddActiveDirectoryContainer $ldap -Recursive
    Set-CMDiscoveryMethod -ActiveDirectoryUserDiscovery   -SiteCode $SiteCode -Enabled $true -AddActiveDirectoryContainer $ldap -Recursive
    Invoke-CMSystemDiscovery -SiteCode $SiteCode
    Invoke-CMUserDiscovery   -SiteCode $SiteCode
}

# =============================================================================================
# 2. Collections
# =============================================================================================
function New-DevColl {
    param([string]$Name, [string]$Limit = 'All Systems', [string]$Query, [string]$Comment,
          [ValidateSet('Periodic','Continuous','Both','Manual')][string]$Refresh = 'Periodic')
    if (Get-CMDeviceCollection -Name $Name) { return }
    $p = @{ Name = $Name; LimitingCollectionName = $Limit; RefreshType = $Refresh; Comment = $Comment }
    if ($Refresh -in 'Periodic','Both') { $p.RefreshSchedule = Sched-Daily }
    New-CMDeviceCollection @p | Out-Null
    if ($Query) { Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Name -RuleName 'Query' -QueryExpression $Query }
}
$sel = 'select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System'

Invoke-Step 'Collection: All Workstations (OU)' {
    New-DevColl 'All Workstations' -Refresh Both -Comment 'AD OU based. Note: Entra-joined CL3/CL4 never appear here.' `
        -Query "$sel where SMS_R_System.SystemOUName = '$WksOUPath'"
}
Invoke-Step 'Collection: Dept-Finance / Dept-Sales (OU)' {
    New-DevColl 'Dept-Finance' -Limit 'All Workstations' -Query "$sel where SMS_R_System.SystemOUName = '$WksOUPath/FINANCE'"
    New-DevColl 'Dept-Sales'   -Limit 'All Workstations' -Query "$sel where SMS_R_System.SystemOUName = '$WksOUPath/SALES'"
}
Invoke-Step 'Collection: Finance Laptops (limiting chain, no Intune equivalent)' {
    New-DevColl 'Finance Laptops' -Limit 'Dept-Finance' -Comment 'Limiting chain demo - empty on VMs by design' `
        -Query "$sel inner join SMS_G_System_SYSTEM_ENCLOSURE on SMS_G_System_SYSTEM_ENCLOSURE.ResourceID = SMS_R_System.ResourceId where SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes in ('8','9','10','14')"
}
Invoke-Step 'Collection: All Laptops (chassis)' {
    New-DevColl 'All Laptops' -Query "$sel inner join SMS_G_System_SYSTEM_ENCLOSURE on SMS_G_System_SYSTEM_ENCLOSURE.ResourceID = SMS_R_System.ResourceId where SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes in ('8','9','10','14')"
}
Invoke-Step 'Collection: Virtual Machines' {
    New-DevColl 'Virtual Machines' -Query "$sel where SMS_R_System.IsVirtualMachine = 'True'"
}
Invoke-Step 'Collection: Windows 11 (all builds)' {
    New-DevColl 'Windows 11 - All' -Query "$sel inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OPERATING_SYSTEM.BuildNumber >= '22000'"
}
Invoke-Step 'Collection: Windows 11 newest build in estate' {
    Push-Location C:\   # CIM call from the file system provider
    $b = Get-CimInstance -Namespace "root\SMS\site_$SiteCode" -ComputerName $SiteServer `
            -Query 'SELECT BuildNumber FROM SMS_G_System_OPERATING_SYSTEM' |
         ForEach-Object { [int]$_.BuildNumber } | Sort-Object -Descending | Select-Object -First 1
    Pop-Location
    if (-not $b) { throw 'No hardware inventory yet - rerun after clients have reported HINV.' }
    New-DevColl "Windows 11 - Build $b" -Query "$sel inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OPERATING_SYSTEM.BuildNumber = '$b'"
}
Invoke-Step 'Collection: Has 7-Zip installed (inventory - no Entra equivalent)' {
        New-DevColl 'Has 7-Zip installed' -Query "$sel inner join SMS_G_System_ADD_REMOVE_PROGRAMS_64 on SMS_G_System_ADD_REMOVE_PROGRAMS_64.ResourceID = SMS_R_System.ResourceId where SMS_G_System_ADD_REMOVE_PROGRAMS_64.DisplayName like '7-Zip%'"
}
Invoke-Step 'Collection: Pilot-CoMgmt (direct: CL1)' {
    New-DevColl 'Pilot-CoMgmt' -Limit 'All Systems' -Refresh Manual -Comment 'Co-management pilot (M3/M5)'
    $d = Get-CMDevice -Name 'CL1' -Fast
    if (-not $d) { throw 'CL1 not discovered yet - add direct rule later.' }
    if (-not (Get-CMDeviceCollectionDirectMembershipRule -CollectionName 'Pilot-CoMgmt' -ResourceId $d.ResourceID)) {
        Add-CMDeviceCollectionDirectMembershipRule -CollectionName 'Pilot-CoMgmt' -ResourceId $d.ResourceID
    }
}
Invoke-Step 'Collection: Workstations without Pilot (include/exclude)' {
    New-DevColl 'Workstations - Production' -Limit 'All Systems' -Refresh Manual
    Invoke-IgnoreExisting { Add-CMDeviceCollectionIncludeMembershipRule -CollectionName 'Workstations - Production' -IncludeCollectionName 'All Workstations' }
    Invoke-IgnoreExisting { Add-CMDeviceCollectionExcludeMembershipRule -CollectionName 'Workstations - Production' -ExcludeCollectionName 'Pilot-CoMgmt' }
}
Invoke-Step 'Collection: MW-Workstations + maintenance window' {
    New-DevColl 'MW-Workstations Sat 22-02' -Limit 'All Workstations' -Query "$sel where SMS_R_System.SystemOUName = '$WksOUPath'"
    if (-not (Get-CMMaintenanceWindow -CollectionName 'MW-Workstations Sat 22-02')) {
        $s = New-CMSchedule -DayOfWeek Saturday -Start ([datetime]'2026-01-03 22:00') -DurationInterval Hours -DurationCount 4
        New-CMMaintenanceWindow -CollectionName 'MW-Workstations Sat 22-02' -Name 'Weekly Sat 22:00' -Schedule $s -ApplyTo Any | Out-Null
    }
}
Invoke-Step 'Collections: dirt (empty / badly named)' {
    New-DevColl 'TEST_alt_Kopie'             -Refresh Manual -Comment 'nobody knows'
    New-DevColl 'Neue Sammlung (2)'          -Refresh Manual
    New-DevColl 'Win10 Upgrade Wave 3 - DONE' -Refresh Manual -Comment 'Project finished 2023'
}
Invoke-Step 'User collections' {
    if (-not (Get-CMUserCollection -Name 'Users-Finance')) {
        New-CMUserCollection -Name 'Users-Finance' -LimitingCollectionName 'All Users' -RefreshType Periodic -RefreshSchedule (Sched-Daily) | Out-Null
        Add-CMUserCollectionQueryMembershipRule -CollectionName 'Users-Finance' -RuleName 'GG-Finance' `
            -QueryExpression "select SMS_R_User.ResourceId, SMS_R_User.ResourceType, SMS_R_User.Name, SMS_R_User.UniqueUserName from SMS_R_User where SMS_R_User.UserGroupName = '$NetBIOS\\GG-Finance'"
    }
    if (-not (Get-CMUserCollection -Name 'Users-App-PuTTY')) {
        New-CMUserCollection -Name 'Users-App-PuTTY' -LimitingCollectionName 'All Users' -RefreshType Periodic -RefreshSchedule (Sched-Daily) | Out-Null
        Add-CMUserCollectionQueryMembershipRule -CollectionName 'Users-App-PuTTY' -RuleName 'GG-App-PuTTY' `
            -QueryExpression "select SMS_R_User.ResourceId, SMS_R_User.ResourceType, SMS_R_User.Name, SMS_R_User.UniqueUserName from SMS_R_User where SMS_R_User.UserGroupName = '$NetBIOS\\GG-App-PuTTY'"
    }
}

# =============================================================================================
# 3. Applications
# =============================================================================================
function New-App([string]$Name, [string]$Publisher, [string]$Version, [bool]$AutoInstall = $false) {
    if (-not (Get-CMApplication -Name $Name -Fast)) {
        New-CMApplication -Name $Name -Publisher $Publisher -SoftwareVersion $Version -AutoInstall $AutoInstall | Out-Null
    }
}
function Test-DT([string]$App, [string]$DT) { [bool](Get-CMDeploymentType -ApplicationName $App -DeploymentTypeName $DT -ErrorAction SilentlyContinue) }
$scriptDT = @{ InstallationBehaviorType = 'InstallForSystem'; LogonRequirementType = 'WhetherOrNotUserLoggedOn'; UserInteractionMode = 'Hidden' }

# 3.1 7-Zip old/new - MSI detection + supersedence
Invoke-Step 'App: 7-Zip 24.09 (MSI)' {
    New-App '7-Zip 24.09' 'Igor Pavlov' '24.09' $true
    if (-not (Test-DT '7-Zip 24.09' '7-Zip 24.09 MSI x64')) {
        Add-CMMsiDeploymentType -ApplicationName '7-Zip 24.09' -DeploymentTypeName '7-Zip 24.09 MSI x64' `
            -ContentLocation "$Src\7-Zip\24.09\7z2409-x64.msi" -InstallationBehaviorType InstallForSystem -Force | Out-Null
    }
}
Invoke-Step 'App: 7-Zip 25.01 (MSI) supersedes 24.09' {
    New-App '7-Zip 25.01' 'Igor Pavlov' '25.01'
    if (-not (Test-DT '7-Zip 25.01' '7-Zip 25.01 MSI x64')) {
        Add-CMMsiDeploymentType -ApplicationName '7-Zip 25.01' -DeploymentTypeName '7-Zip 25.01 MSI x64' `
            -ContentLocation "$Src\7-Zip\25.01\7z2501-x64.msi" -InstallationBehaviorType InstallForSystem -Force | Out-Null
        $new = Get-CMDeploymentType -ApplicationName '7-Zip 25.01' -DeploymentTypeName '7-Zip 25.01 MSI x64'
        $old = Get-CMDeploymentType -ApplicationName '7-Zip 24.09' -DeploymentTypeName '7-Zip 24.09 MSI x64'
        Add-CMDeploymentTypeSupersedence -SupersedingDeploymentType $new -SupersededDeploymentType $old -IsUninstall $true | Out-Null
    }
}

# 3.2 VC++ Redist + Greenshot - dependency chain (artificial dependency, clearly labelled)
Invoke-Step 'App: Microsoft Visual C++ Redistributable x64' {
    New-App 'Microsoft Visual C++ Redistributable x64' 'Microsoft' '14.x' $true
    if (-not (Test-DT 'Microsoft Visual C++ Redistributable x64' 'VCRedist x64')) {
        $det = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' `
                  -ValueName 'Installed' -PropertyType Integer -ExpressionOperator IsEquals -ExpectedValue '1' -Value -Is64Bit
        Add-CMScriptDeploymentType -ApplicationName 'Microsoft Visual C++ Redistributable x64' -DeploymentTypeName 'VCRedist x64' `
            -ContentLocation "$Src\VCRedist" -InstallCommand 'vc_redist.x64.exe /install /quiet /norestart' `
            -UninstallCommand 'vc_redist.x64.exe /uninstall /quiet /norestart' -AddDetectionClause $det @scriptDT | Out-Null
    }
}
Invoke-Step 'App: Greenshot (depends on VC++)' {
    New-App 'Greenshot' 'Greenshot' 'latest' $true
    if (-not (Test-DT 'Greenshot' 'Greenshot EXE')) {
        $det = New-CMDetectionClauseFile -Path '%ProgramFiles%\Greenshot' -FileName 'Greenshot.exe' -Existence -Is64Bit
        Add-CMScriptDeploymentType -ApplicationName 'Greenshot' -DeploymentTypeName 'Greenshot EXE' `
            -ContentLocation "$Src\Greenshot" -InstallCommand 'greenshot-installer.exe /VERYSILENT /NORESTART /SUPPRESSMSGBOXES' `
            -UninstallCommand '"%ProgramFiles%\Greenshot\unins000.exe" /VERYSILENT /NORESTART' -AddDetectionClause $det @scriptDT | Out-Null
        $dt  = Get-CMDeploymentType -ApplicationName 'Greenshot' -DeploymentTypeName 'Greenshot EXE'
        $dep = Get-CMDeploymentType -ApplicationName 'Microsoft Visual C++ Redistributable x64' -DeploymentTypeName 'VCRedist x64'
        $dt | New-CMDeploymentTypeDependencyGroup -GroupName 'Runtimes' |
              Add-CMDeploymentTypeDependency -DeploymentTypeDependency $dep -IsAutoInstall $true | Out-Null
    }
}

# 3.3 Notepad++ - two deployment types, custom global condition, registry vs. script detection
Invoke-Step 'Global condition: SmartETC Department' {
    if (-not (Get-CMGlobalCondition -Name 'SmartETC Department')) {
        $t = (Get-Command New-CMGlobalConditionRegistryValue).Parameters['DeviceType'].ParameterType
        if ($t.IsGenericType) { $t = $t.GetGenericArguments()[0] }          # Nullable<enum>
        $names = [enum]::GetNames($t)
        $dev = @($names | Where-Object { $_ -eq 'Windows' }) + @($names | Where-Object { $_ -match 'Windows|NonMobile' }) | Select-Object -First 1
        if (-not $dev) { throw "No Windows value in DeviceType enum: $($names -join ', ')" }
        New-CMGlobalConditionRegistryValue -Name 'SmartETC Department' -DeviceType $dev -DataType String -RegistryHive LocalMachine `
            -KeyName 'SOFTWARE\SmartETC' -ValueName 'Department' -Is64Bit $true | Out-Null
    }
}
Invoke-Step 'App: Notepad++ (2 DTs: Finance w/ requirement, Standard w/ script detection) [VERIFY]' {
    New-App 'Notepad++' 'Notepad++ Team' 'latest' $true
    if (-not (Test-DT 'Notepad++' 'Notepad++ Finance')) {
        $gc = Get-CMGlobalCondition -Name 'SmartETC Department'
        if (-not $gc) { throw "Global condition 'SmartETC Department' missing - fix that step first." }
        $req = $gc | New-CMRequirementRuleCommonValue -Value1 'Finance' -RuleOperator IsEquals
        $det = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName 'SOFTWARE\SmartETC\NotepadPP' `
                  -ValueName 'Edition' -PropertyType String -ExpressionOperator IsEquals -ExpectedValue 'Finance' -Value -Is64Bit
        Add-CMScriptDeploymentType -ApplicationName 'Notepad++' -DeploymentTypeName 'Notepad++ Finance' `
            -ContentLocation "$Src\NotepadPP" -InstallCommand 'powershell.exe -ExecutionPolicy Bypass -File Install-Finance.ps1' `
            -UninstallCommand '"%ProgramFiles%\Notepad++\uninstall.exe" /S' -AddDetectionClause $det -AddRequirement $req @scriptDT | Out-Null
    }
    if (-not (Test-DT 'Notepad++' 'Notepad++ Standard')) {
        $detScript = @'
if (Test-Path "$env:ProgramFiles\Notepad++\notepad++.exe") { Write-Output 'Installed' }
'@
        Add-CMScriptDeploymentType -ApplicationName 'Notepad++' -DeploymentTypeName 'Notepad++ Standard' `
            -ContentLocation "$Src\NotepadPP" -InstallCommand 'npp-installer-x64.exe /S' `
            -UninstallCommand '"%ProgramFiles%\Notepad++\uninstall.exe" /S' `
            -ScriptLanguage PowerShell -ScriptText $detScript @scriptDT | Out-Null
    }
}

# 3.4 PuTTY - MSI, user-targeted available (Software Center -> Company Portal)
Invoke-Step 'App: PuTTY (MSI)' {
    New-App 'PuTTY' 'Simon Tatham' 'latest'
    if (-not (Test-DT 'PuTTY' 'PuTTY MSI x64')) {
        Add-CMMsiDeploymentType -ApplicationName 'PuTTY' -DeploymentTypeName 'PuTTY MSI x64' `
            -ContentLocation "$Src\PuTTY\putty-64bit-installer.msi" -InstallationBehaviorType InstallForSystem -Force | Out-Null
    }
}

# 3.5 Firefox ESR - multi-step script install (PSADT candidate)
Invoke-Step 'App: Mozilla Firefox ESR (multi-step wrapper)' {
    New-App 'Mozilla Firefox ESR' 'Mozilla' 'ESR latest'
    if (-not (Test-DT 'Mozilla Firefox ESR' 'Firefox ESR + policies')) {
        $det = New-CMDetectionClauseFile -Path '%ProgramFiles%\Mozilla Firefox\distribution' -FileName 'policies.json' -Existence -Is64Bit
        Add-CMScriptDeploymentType -ApplicationName 'Mozilla Firefox ESR' -DeploymentTypeName 'Firefox ESR + policies' `
            -ContentLocation "$Src\FirefoxESR" -InstallCommand 'powershell.exe -ExecutionPolicy Bypass -File Install-Firefox.ps1' `
            -UninstallCommand 'powershell.exe -ExecutionPolicy Bypass -File Uninstall-Firefox.ps1' -AddDetectionClause $det @scriptDT | Out-Null
    }
}

# 3.6 Toolbox - deliberately broken detection
Invoke-Step 'App: SmartETC Toolbox (broken detection)' {
    New-App 'SmartETC Toolbox' 'SmartETC IT' '2.3'
    if (-not (Test-DT 'SmartETC Toolbox' 'Toolbox Script')) {
        # Installer writes to ...\Toolbox, detection checks ...\Tools -> 0x87D00324 on the client
        $det = New-CMDetectionClauseFile -Path '%ProgramData%\SmartETC\Tools' -FileName 'toolbox.txt' -Existence -Is64Bit
        Add-CMScriptDeploymentType -ApplicationName 'SmartETC Toolbox' -DeploymentTypeName 'Toolbox Script' `
            -ContentLocation "$Src\Toolbox" -InstallCommand 'powershell.exe -ExecutionPolicy Bypass -File Install-Toolbox.ps1' `
            -UninstallCommand 'powershell.exe -ExecutionPolicy Bypass -File Uninstall-Toolbox.ps1' -AddDetectionClause $det @scriptDT | Out-Null
    }
}

# 3.7 Adobe Reader 2019 - dead content (distributed, never deployed)
Invoke-Step 'App: Adobe Reader 2019 (dead content)' {
    New-App 'Adobe Reader 2019' 'Adobe' '19.x'
    if (-not (Test-DT 'Adobe Reader 2019' 'AcroRdr2019 EXE')) {
        $det = New-CMDetectionClauseFile -Path '%ProgramFiles(x86)%\Adobe\Acrobat Reader DC\Reader' -FileName 'AcroRd32.exe' -Existence
        Add-CMScriptDeploymentType -ApplicationName 'Adobe Reader 2019' -DeploymentTypeName 'AcroRdr2019 EXE' `
            -ContentLocation "$Src\AdobeReader2019" -InstallCommand 'AcroRdr2019.exe /sAll /rs /msi EULA_ACCEPT=YES' `
            -UninstallCommand 'msiexec /x {AC76BA86-7AD7-1033-7B44-AC0F074E4100} /qn' -AddDetectionClause $det @scriptDT | Out-Null
    }
}

# 3.8 Duplicate app (dirt)
Invoke-Step 'App: 7Zip (duplicate, no DT)' { New-App '7Zip' 'Igor Pavlov' '' }

# =============================================================================================
# 4. Legacy package / programs
# =============================================================================================
Invoke-Step 'Package: SmartETC Branding (2 programs)' {
    if (-not (Get-CMPackage -Name 'SmartETC Branding' -Fast)) {
        New-CMPackage -Name 'SmartETC Branding' -Manufacturer 'SmartETC IT' -Version '3.1' -Path "$Src\Legacy\SmartETC-Branding" | Out-Null
    }
    foreach ($d in 'Finance','Sales') {
        if (-not (Get-CMProgram -PackageName 'SmartETC Branding' -ProgramName "Install $d")) {
            New-CMProgram -PackageName 'SmartETC Branding' -StandardProgramName "Install $d" -CommandLine "install.cmd $d" `
                -RunType Hidden -ProgramRunType WhetherOrNotUserIsLoggedOn -RunMode RunWithAdministrativeRights | Out-Null
        }
    }
}

# =============================================================================================
# 5. Content distribution
# =============================================================================================
foreach ($a in '7-Zip 24.09','7-Zip 25.01','Microsoft Visual C++ Redistributable x64','Greenshot','Notepad++','PuTTY','Mozilla Firefox ESR','SmartETC Toolbox','Adobe Reader 2019') {
    Invoke-Step "Distribute: $a" {
        if (-not (Get-CMDeploymentType -ApplicationName $a)) { throw 'no deployment type (fix the app step first)' }
        Invoke-IgnoreExisting { Start-CMContentDistribution -ApplicationName $a -DistributionPointName $SiteServer }
    }
}
Invoke-Step 'Distribute: SmartETC Branding (package)' {
    Invoke-IgnoreExisting { Start-CMContentDistribution -PackageName 'SmartETC Branding' -DistributionPointName $SiteServer }
}

# =============================================================================================
# 6. Deployments
# =============================================================================================
function New-AppDeploy([string]$App, [string]$Coll, [ValidateSet('Required','Available')][string]$Purpose) {
    if (Get-CMApplicationDeployment -Name $App -CollectionName $Coll -ErrorAction SilentlyContinue) { return }
    $p = @{ Name = $App; CollectionName = $Coll; DeployAction = 'Install'; DeployPurpose = $Purpose;
            UserNotification = 'DisplaySoftwareCenterOnly'; AvailableDateTime = $Now }
    if ($Purpose -eq 'Required') { $p.DeadlineDateTime = $Now.AddMinutes(30) }
    New-CMApplicationDeployment @p | Out-Null
}
if ($EnableDeployments) {
Invoke-Step 'Deploy: branding package (Finance/Sales, required)' {
    foreach ($d in 'Finance','Sales') {
        if (-not (Get-CMPackageDeployment -PackageName 'SmartETC Branding' -CollectionName "Dept-$d" -ErrorAction SilentlyContinue)) {
            New-CMPackageDeployment -StandardProgram -PackageName 'SmartETC Branding' -ProgramName "Install $d" `
                -CollectionName "Dept-$d" -DeployPurpose Required -ScheduleEvent AsSoonAsPossible -RerunBehavior RerunIfFailedPreviousAttempt | Out-Null
        }
    }
}
Invoke-Step 'Deploy: 7-Zip 24.09 required -> All Workstations' { New-AppDeploy '7-Zip 24.09'         'All Workstations' Required }
Invoke-Step 'Deploy: Notepad++ required -> All Workstations'   { New-AppDeploy 'Notepad++'           'All Workstations' Required }
Invoke-Step 'Deploy: Greenshot available -> All Workstations'  { New-AppDeploy 'Greenshot'           'All Workstations' Available }
Invoke-Step 'Deploy: Firefox ESR available -> All Workstations'{ New-AppDeploy 'Mozilla Firefox ESR' 'All Workstations' Available }
Invoke-Step 'Deploy: PuTTY available -> Users-App-PuTTY'       { New-AppDeploy 'PuTTY'               'Users-App-PuTTY'  Available }
Invoke-Step 'Deploy: Toolbox required -> Dept-Sales (fails)'   { New-AppDeploy 'SmartETC Toolbox'    'Dept-Sales'       Required }
} else { Write-Host '       Deployments skipped (use -EnableDeployments for SCMI).' -ForegroundColor Yellow }
# 7-Zip 25.01 deliberately NOT deployed (supersedence discussion in M8)
# Adobe Reader 2019 deliberately NOT deployed (dead content in M1)

# =============================================================================================
# 7. Configuration items & baselines (script settings)
# =============================================================================================
function New-ScriptCI {
    param([string]$Name, [string]$Setting, [ValidateSet('String','Integer')][string]$DataType = 'String',
          [string]$Discovery, [string]$Remediation, [string]$Operator = 'IsEquals', [string]$Expected)
    $ci = Get-CMConfigurationItem -Name $Name -Fast
    if (-not $ci) {
        $ci = New-CMConfigurationItem -Name $Name -CreationType WindowsOS
    } else {
        $ci = Get-CMConfigurationItem -Name $Name          # full object: SDMPackageXML is a lazy property
        if ($ci.SDMPackageXML -match [regex]::Escape($Setting)) { return }   # setting already present
    }
    $p = @{ SettingName = $Setting; DataType = $DataType; DiscoveryScriptLanguage = 'PowerShell'; DiscoveryScriptText = $Discovery;
            ValueRule = $true; RuleName = "$Setting - $Operator $Expected"; ExpressionOperator = $Operator; ExpectedValue = $Expected;
            NoncomplianceSeverity = 'Warning'; ReportNoncompliance = $true; Is64Bit = $true }
    if ($Remediation) { $p.RemediationScriptLanguage = 'PowerShell'; $p.RemediationScriptText = $Remediation; $p.Remediate = $true }
    $ci | Add-CMComplianceSettingScript @p | Out-Null
}

Invoke-Step 'CI: Registry marker (remediate)' {
    New-ScriptCI -Name 'CI - SmartETC Compliance Marker' -Setting 'ComplianceMarker' -Expected 'Managed' `
        -Discovery '(Get-ItemProperty HKLM:\SOFTWARE\SmartETC -Name ComplianceMarker -ErrorAction SilentlyContinue).ComplianceMarker' `
        -Remediation 'New-Item HKLM:\SOFTWARE\SmartETC -Force | Out-Null; Set-ItemProperty HKLM:\SOFTWARE\SmartETC -Name ComplianceMarker -Value Managed'
}
Invoke-Step 'CI: RemoteRegistry disabled (remediate)' {
    New-ScriptCI -Name 'CI - RemoteRegistry Disabled' -Setting 'RemoteRegistryStartType' -Expected 'Disabled' `
        -Discovery '(Get-Service RemoteRegistry).StartType.ToString()' `
        -Remediation 'Stop-Service RemoteRegistry -Force -ErrorAction SilentlyContinue; Set-Service RemoteRegistry -StartupType Disabled'
}
Invoke-Step 'CI: Local admin count (report only)' {
    $disc = @'
$name = (New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544').Translate([System.Security.Principal.NTAccount]).Value.Split('\')[1]
@(([ADSI]"WinNT://./$name,group").psbase.Invoke('Members')).Count
'@
    New-ScriptCI -Name 'CI - Local Administrators Count' -Setting 'LocalAdminCount' -DataType Integer -Operator 'LessEquals' -Expected '2' -Discovery $disc
}
Invoke-Step 'CI: BitLocker OS volume (report only)' {
    New-ScriptCI -Name 'CI - BitLocker OS Volume' -Setting 'OSVolumeProtection' -Expected 'On' `
        -Discovery '$v = Get-CimInstance -Namespace root\cimv2\security\microsoftvolumeencryption -ClassName Win32_EncryptableVolume -Filter "DriveLetter=''$env:SystemDrive''" -ErrorAction SilentlyContinue; if ($v.ProtectionStatus -eq 1) { "On" } else { "Off" }'
}

Invoke-Step 'Baseline: BL - Workstation Security (remediating)' {
    if (-not (Get-CMBaseline -Name 'BL - Workstation Security' -Fast)) {
        New-CMBaseline -Name 'BL - Workstation Security' | Out-Null
        foreach ($c in 'CI - SmartETC Compliance Marker','CI - RemoteRegistry Disabled','CI - Local Administrators Count') {
            Set-CMBaseline -Name 'BL - Workstation Security' -AddOSConfigurationItem (Get-CMConfigurationItem -Name $c -Fast).CI_ID
        }
    }
    if ($EnableDeployments -and -not (Get-CMBaselineDeployment -Name 'BL - Workstation Security')) {
        New-CMBaselineDeployment -Name 'BL - Workstation Security' -CollectionName 'All Workstations' -EnableEnforcement $true `
            -Schedule (New-CMSchedule -RecurInterval Hours -RecurCount 4) | Out-Null
    }
}
Invoke-Step 'Baseline: BL - Reporting Only' {
    if (-not (Get-CMBaseline -Name 'BL - Reporting Only' -Fast)) {
        New-CMBaseline -Name 'BL - Reporting Only' | Out-Null
        Set-CMBaseline -Name 'BL - Reporting Only' -AddOSConfigurationItem (Get-CMConfigurationItem -Name 'CI - BitLocker OS Volume' -Fast).CI_ID
    }
    if ($EnableDeployments -and -not (Get-CMBaselineDeployment -Name 'BL - Reporting Only')) {
        New-CMBaselineDeployment -Name 'BL - Reporting Only' -CollectionName 'All Workstations' -EnableEnforcement $false `
            -Schedule (Sched-Daily) | Out-Null
    }
}

# =============================================================================================
# 8. Client settings
# =============================================================================================
Invoke-Step 'Default client settings: software metering on [VERIFY]' {
    Set-CMClientSettingSoftwareMetering -DefaultSetting -Enable $true
}
$csWks = 'CS - Workstations Custom'
Invoke-Step "Client settings: $csWks (create)" {
    if (-not (Get-CMClientSetting -Name $csWks)) { New-CMClientSetting -Name $csWks -Type Device | Out-Null }
    if ($EnableDeployments) { Invoke-IgnoreExisting { Start-CMClientSettingDeployment -ClientSettingName $csWks -CollectionName 'All Workstations' } }
}
Invoke-Step "Client settings: $csWks - client cache" {
    Set-CMClientSettingClientCache -Name $csWks -ConfigureCacheSize $true -MaxCacheSize 20480 -MaxCacheSizePercent 20
}
Invoke-Step "Client settings: $csWks - computer restart [VERIFY]" {
    Set-CMClientSettingComputerRestart -Name $csWks -RebootLogoffNotificationCountdownDuration 240 -RebootLogoffNotificationFinalWindowMinutes 30
}
Invoke-Step "Client settings: $csWks - Software Center branding [VERIFY]" {
    Set-CMClientSettingSoftwareCenter -Name $csWks -EnableCustomize $true -CompanyName 'SmartETC IT' -ColorScheme '#0B3D91'
}
Invoke-Step 'Client settings: CS - Branch Graz BITS [VERIFY]' {
    $n = 'CS - Branch Graz BITS'
    if (-not (Get-CMClientSetting -Name $n)) { New-CMClientSetting -Name $n -Type Device | Out-Null }
    Set-CMClientSettingBackgroundIntelligentTransfer -Name $n -EnableBitsMaxBandwidth $true -MaxBandwidthValidFrom 8 -MaxBandwidthValidTo 17 `
        -MaxTransferRateOnSchedule 512 -EnableDownloadOffSchedule $true -MaxTransferRateOffSchedule 4096
    if ($EnableDeployments) { Invoke-IgnoreExisting { Start-CMClientSettingDeployment -ClientSettingName $n -CollectionName 'Dept-Sales' } }
}

# =============================================================================================
# 9. Software metering, saved queries, scripts
# =============================================================================================
Invoke-Step 'Software metering rules' {
    foreach ($r in @(@{P='Notepad++';F='notepad++.exe'}, @{P='PuTTY';F='putty.exe'}, @{P='Firefox ESR';F='firefox.exe'})) {
        if (-not (Get-CMSoftwareMeteringRule -ProductName $r.P)) {
            New-CMSoftwareMeteringRule -ProductName $r.P -FileName $r.F -SiteCode $SiteCode -LanguageId 65535 | Out-Null
        }
    }
}
Invoke-Step 'Saved queries (custom reporting stand-in)' {
    $q = @{
        'Q - Devices without client'      = "$sel where SMS_R_System.Client is null or SMS_R_System.Client = 0"
        'Q - Last logged-on user'         = 'select SMS_R_System.Name, SMS_R_System.LastLogonUserName, SMS_R_System.LastLogonTimestamp from SMS_R_System'
        'Q - Installed software (7-Zip)'  = 'select SMS_R_System.Name, SMS_G_System_ADD_REMOVE_PROGRAMS_64.DisplayName, SMS_G_System_ADD_REMOVE_PROGRAMS_64.Version from SMS_R_System inner join SMS_G_System_ADD_REMOVE_PROGRAMS_64 on SMS_G_System_ADD_REMOVE_PROGRAMS_64.ResourceID = SMS_R_System.ResourceId where SMS_G_System_ADD_REMOVE_PROGRAMS_64.DisplayName like ''7-Zip%'''
    }
    foreach ($k in $q.Keys) { if (-not (Get-CMQuery -Name $k)) { New-CMQuery -Name $k -Expression $q[$k] -TargetClassName 'SMS_R_System' | Out-Null } }
}
Invoke-Step 'Run Scripts (appear in Intune after Tenant Attach)' {
    $s = [ordered]@{
        'Get Uptime'              = '$os = Get-CimInstance Win32_OperatingSystem; "{0:N1} h" -f ((Get-Date) - $os.LastBootUpTime).TotalHours'
        'Get Co-Management State' = '(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\DeviceManageabilityCSP\Provider\MS DM Server" -Name ConfigInfo -ErrorAction SilentlyContinue).ConfigInfo'
        'Clear CCM Cache'         = '$c = New-Object -ComObject UIResource.UIResourceMgr; $ch = $c.GetCacheInfo(); $ch.GetCacheElements() | ForEach-Object { $ch.DeleteCacheElement($_.CacheElementID) }; "Cache cleared"'
    }
    foreach ($k in $s.Keys) {
        if (-not (Get-CMScript -ScriptName $k -Fast)) { New-CMScript -ScriptName $k -ScriptText $s[$k] | Out-Null }
    }
    Write-Host '       -> approve the scripts in the console (or enable author self-approval in Hierarchy Settings).' -ForegroundColor Yellow
}

# =============================================================================================
# 10. Endpoint Protection
# =============================================================================================
Invoke-Step 'Endpoint Protection point [VERIFY]' {
    if (-not (Get-CMEndpointProtectionPoint -SiteSystemServerName $SiteServer -ErrorAction SilentlyContinue)) {
        Add-CMEndpointProtectionPoint -SiteSystemServerName $SiteServer -SiteCode $SiteCode -ProtectionService DoNotJoinMaps | Out-Null
    }
}
Invoke-Step 'Antimalware policy AM - Workstations [VERIFY]' {
    if (-not (Get-CMAntimalwarePolicy -Name 'AM - Workstations')) {
        New-CMAntimalwarePolicy -Name 'AM - Workstations' -Policy ScheduledScans, RealTimeProtection, ExclusionSettings | Out-Null
    }
    if ($EnableDeployments) { Invoke-IgnoreExisting { Start-CMAntimalwarePolicyDeployment -AntimalwarePolicyName 'AM - Workstations' -CollectionName 'All Workstations' } }
    Set-CMClientSettingEndpointProtection -Name 'CS - Workstations Custom' -Enable $true
}

# =============================================================================================
# 11. Custom task sequence (app chain with reboot, never deployed)
# =============================================================================================
Invoke-Step 'Task sequence: TS - Finance App Bundle (legacy)' {
    $n = 'TS - Finance App Bundle (legacy)'
    if (-not (Get-CMTaskSequence -Name $n -Fast)) {
        New-CMTaskSequence -CustomTaskSequence -Name $n -Description 'App chain with reboot - no Intune equivalent (M1/M10)' | Out-Null
    }
    if (@(Get-CMTaskSequenceStep -TaskSequenceName $n).Count -gt 0) { return }   # already populated
    $apps = 'Microsoft Visual C++ Redistributable x64','Notepad++','Greenshot'
    foreach ($a in $apps) { if (-not (Get-CMDeploymentType -ApplicationName $a)) { throw "'$a' has no deployment type yet" } }
    $steps = @(
        New-CMTSStepInstallApplication -Name 'Install VC++ Runtime' -Application (Get-CMApplication -Name $apps[0])
        New-CMTSStepReboot             -Name 'Restart'              -RunAfterRestart HardDisk
        New-CMTSStepInstallApplication -Name 'Install Notepad++'    -Application (Get-CMApplication -Name $apps[1])
        New-CMTSStepInstallApplication -Name 'Install Greenshot'    -Application (Get-CMApplication -Name $apps[2])
    )
    Add-CMTaskSequenceStep -TaskSequenceName $n -Step $steps
}

# ---------------------------------------------------------------- Summary
Set-Location C:\
$Results | Format-Table -AutoSize
$Results | Export-Csv "$PSScriptRoot\03-CM-Populate-results.csv" -NoTypeInformation -Encoding UTF8
$fail = @($Results | Where-Object Status -eq 'FAIL').Count
Write-Host "`nDone. $($Results.Count - $fail) OK, $fail FAIL. Rerun is safe; failed steps are retried." -ForegroundColor Cyan

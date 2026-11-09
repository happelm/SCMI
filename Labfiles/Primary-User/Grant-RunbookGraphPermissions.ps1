<#
.SYNOPSIS
    Grants the Graph application permissions for Update-IntunePrimaryUser.ps1 to the
    managed identity of an Azure Automation account. Run once, as an admin.

.DESCRIPTION
    Managed identities have no API permissions page in the Entra admin center; app roles
    are assigned with Graph (Learn: "Assign an application role to a managed identity
    using PowerShell").

.PARAMETER ManagedIdentityObjectId
    Object (principal) ID of the Automation account's system-assigned managed identity
    (Automation account -> Identity).

.EXAMPLE
    .\Grant-RunbookGraphPermissions.ps1 -ManagedIdentityObjectId <object-id> -IncludeGroupRead
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ManagedIdentityObjectId,

    [switch]$IncludeGroupRead
)

$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'AppRoleAssignment.ReadWrite.All', 'Application.Read.All' -NoWelcome

$permissions = @('DeviceManagementManagedDevices.ReadWrite.All', 'User.Read.All')
if ($IncludeGroupRead) { $permissions += 'GroupMember.Read.All' }

# Microsoft Graph service principal (well-known appId)
$graphSp  = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$existing = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityObjectId -All

foreach ($p in $permissions) {
    $role = $graphSp.AppRoles | Where-Object { $_.Value -eq $p -and $_.AllowedMemberTypes -contains 'Application' }
    if (-not $role) { Write-Warning "App role $p not found"; continue }
    if ($existing | Where-Object { $_.AppRoleId -eq $role.Id -and $_.ResourceId -eq $graphSp.Id }) {
        Write-Output "Already assigned: $p"; continue
    }
    if ($PSCmdlet.ShouldProcess($ManagedIdentityObjectId, "Assign $p")) {
        # Parameter usage as in the Learn article (ServicePrincipalId = resource service principal)
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $graphSp.Id `
            -PrincipalId $ManagedIdentityObjectId -ResourceId $graphSp.Id -AppRoleId $role.Id | Out-Null
        Write-Output "Assigned: $p"
    }
}

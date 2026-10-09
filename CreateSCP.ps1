#
# ConfigureSCP.ps1
# Configures the service connection point (SCP) for Microsoft Entra hybrid join in the current forest.
#
# REQUIREMENT: Must be run by an Enterprise Admin of the current forest.
#
# EXAMPLES:
#   .\ConfigureSCP.ps1 -Domain contoso.com -TenantId <guid>
#   .\ConfigureSCP.ps1 -Domain contoso.onmicrosoft.com -TenantId <guid>
#
[CmdletBinding()]
param(
    # Verified domain used for device authentication.
    # If you use federation, enter a federated domain name.
    # Otherwise, enter your primary *.onmicrosoft.com domain name.
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Domain,

# Microsoft Entra tenant identifier (GUID).
    [Parameter(Mandatory = $true)]
    [guid]$TenantId
)

$ErrorActionPreference = "Stop"

Write-Output "Configuring the SCP for Microsoft Entra hybrid join in your Active Directory forest."

try {
    ## Set variables
    $azureADName = "azureADName:" + $Domain.Trim()
    $azureADId   = "azureADId:" + $TenantId.ToString()
    $keywords    = "keywords"
    $ldap        = "LDAP://"

$rootDSE    = New-Object System.DirectoryServices.DirectoryEntry($ldap + "RootDSE")
    $configCN   = $rootDSE.Properties["configurationNamingContext"][0].ToString()
    $servicesCN = "CN=Services," + $configCN
    $drcCN      = "CN=Device Registration Configuration," + $servicesCN
    $scpCN      = "CN=62a0ff2e-97b9-4513-943f-0d221bd30080," + $drcCN

## Get/Create: CN=Device Registration Configuration,CN=Services
    if ([System.DirectoryServices.DirectoryEntry]::Exists($ldap + $drcCN)) {
        $deDRC = New-Object System.DirectoryServices.DirectoryEntry($ldap + $drcCN)
    }
    else {
        $de    = New-Object System.DirectoryServices.DirectoryEntry($ldap + $servicesCN)
        $deDRC = $de.Children.Add("CN=Device Registration Configuration", "container")
        $deDRC.CommitChanges()
    }

## Edit/Create: CN=62a0ff2e-97b9-4513-943f-0d221bd30080,CN=Device Registration Configuration,CN=Services
    if ([System.DirectoryServices.DirectoryEntry]::Exists($ldap + $scpCN)) {
        $deSCP = New-Object System.DirectoryServices.DirectoryEntry($ldap + $scpCN)
        $deSCP.Properties[$keywords].Clear()
    }
    else {
        $deSCP = $deDRC.Children.Add("CN=62a0ff2e-97b9-4513-943f-0d221bd30080", "serviceConnectionPoint")
    }

$deSCP.Properties[$keywords].Add($azureADName) | Out-Null
    $deSCP.Properties[$keywords].Add($azureADId)   | Out-Null
    $deSCP.CommitChanges()

Write-Output "Configuration complete!"
}
catch {
    Write-Output "Configuration could not be completed."
    Write-Output $_
    exit 1
}
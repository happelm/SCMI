# Detection script
$svc = Get-Service -Name RemoteRegistry -ErrorAction SilentlyContinue
if (-not $svc) { Write-Output 'Service not found'; exit 0 }
if ($svc.StartType -eq 'Disabled') { Write-Output 'Compliant: Disabled'; exit 0 }
Write-Output "Not compliant: $($svc.StartType)"; exit 1

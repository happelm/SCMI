# Detection script – reports an issue as long as the marker exists
$marker = 'HKLM:\SOFTWARE\SmartETC\Apps\<AppName>'
if (Test-Path $marker) { Write-Output 'Marker present'; exit 1 }
Write-Output 'Marker already removed'; exit 0

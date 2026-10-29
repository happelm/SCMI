# Remediation script – removes the marker, clears the re-evaluation schedule, forces a full report, restarts the IME
$marker = 'HKLM:\SOFTWARE\SmartETC\Apps\<AppName>'
Remove-Item -Path $marker -Recurse -Force -ErrorAction SilentlyContinue
# Clear the re-evaluation schedule so that the IME runs detection at the next check-in
Remove-Item -Path 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps\*\GRS' -Recurse -Force -ErrorAction SilentlyContinue
# Force a full status report so that Intune receives the new state
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps\Reporting\*' -Name 'LastFullReportTimeUtc' -Force -ErrorAction SilentlyContinue
# Restart the IME after the result has been reported
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-ExecutionPolicy Bypass -Command "Start-Sleep 180; Restart-Service IntuneManagementExtension -Force"'
Write-Output 'Marker removed, schedule cleared, full report forced, IME restart scheduled'; exit 0

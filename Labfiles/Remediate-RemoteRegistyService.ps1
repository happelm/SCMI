# Remediation script
Stop-Service -Name RemoteRegistry -Force -ErrorAction SilentlyContinue
Set-Service -Name RemoteRegistry -StartupType Disabled
Write-Output 'RemoteRegistry disabled'; exit 0

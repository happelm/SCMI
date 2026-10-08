---
title: 'Lab 6.2 – Turn a configuration item into a remediation'
lab:
    title: 'Lab 6.2 – Turn a configuration item into a remediation'
    module: 'Day 2 – Authority, policy, apps'
---

# Lab 6.2 – Turn a configuration item into a remediation

**Estimated time:** 15 minutes

**Goal:** Rebuild CI - RemoteRegistry Disabled as an Intune remediation and run it on CL4.

> **Why:** CL3 and CL4 never get BL - Workstation Security, because the baseline is deployed to All Workstations. CI - RemoteRegistry Disabled has no settings catalog equivalent – the Intune counterpart of a script CI is a remediation.

1. ConfigMgr console → Assets and Compliance → Compliance Settings → Configuration Items → CI - RemoteRegistry Disabled: open the setting and note the discovery script, the compliance rule (value equals Disabled) and the remediation script.

2. Map the three parts: the discovery script and the compliance rule together become the detection script (exit 0 = compliant, exit 1 = not compliant), the remediation script stays a remediation script. The evaluation schedule of the baseline (every 4 hours) becomes the schedule of the assignment.

3. Prepare CL4 so that there is something to fix: in an elevated PowerShell run `Set-Service RemoteRegistry -StartupType Manual`.

4. Intune admin center → Devices → Scripts and remediations → Remediations → Create: name SCMI-RemoteRegistry-Disabled, the two scripts below, run this script using the logged-on credentials = No, run script in 64-bit PowerShell = Yes.

    ```powershell
    # Detection script
    $svc = Get-Service -Name RemoteRegistry -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Output 'Service not found'; exit 0 }
    if ($svc.StartType -eq 'Disabled') { Write-Output 'Compliant: Disabled'; exit 0 }
    Write-Output "Not compliant: $($svc.StartType)"; exit 1
    ```

    ```powershell
    # Remediation script
    Stop-Service -Name RemoteRegistry -Force -ErrorAction SilentlyContinue
    Set-Service -Name RemoteRegistry -StartupType Disabled
    Write-Output 'RemoteRegistry disabled'; exit 0
    ```

5. Assign it to a new device group SCMI-CL4-Group with CL4, schedule hourly.

6. Do not wait for the schedule: Intune admin center → Devices → CL4 → Run remediation → SCMI-RemoteRegistry-Disabled.

7. On CL4 check `Get-Service RemoteRegistry | Select-Object Name, StartType, Status` and follow `HealthScripts.log` in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.

8. Intune admin center → Remediations → SCMI-RemoteRegistry-Disabled → Device status: add the columns for the detection output before and after the remediation.

### Checkpoint

- [ ] CL4: RemoteRegistry start type is Disabled again
- [ ] Device status shows "Issue fixed" with the output of both detection runs
- [ ] You can name what replaced the compliance rule and the baseline schedule of the CI

> **Note:** Keep SCMI-RemoteRegistry-Disabled – Lab 12.1 runs it again on demand.

---
title: 'Lab 10.3 – Repair a required app'
lab:
    title: 'Lab 10.3 – Repair a required app'
    module: 'Day 2 – Authority, policy, apps'
---

# Lab 10.3 – Repair a required app

**Estimated time:** 30 minutes · *optional*

**Goal:** Give the helpdesk a way to force the reinstall of a required app – with a marker in the PSADT template and a remediation on demand.

> **Why:** Intune has no repair action. For a required app, Reinstall in the Company Portal does nothing while detection is positive, and Uninstall is not passed to the device. The lever that remains is the detection rule.

### Part A – Marker in the package

1. Open `C:\ADTSoftware\FirefoxESR\Invoke-AppDeployToolkit.ps1` from Lab 10.1. Note the value of `AppName` in the `$adtSession` block – it becomes the name of the marker key: `HKLM\SOFTWARE\SmartETC\Apps\<AppName>`, for example `...\Apps\Firefox ESR`.

2. **Write the marker.** In `Install-ADTDeployment`, at the very end of the Post-Install phase (after the `Remove-ADTFile` line), add the first four lines of the code below. They create the key and write Version and InstallDate.

    ```powershell
    # End of the Post-Install phase – company marker (same pattern in every package)
    $marker = "HKLM:\SOFTWARE\SmartETC\Apps\$($adtSession.AppName)"
    New-Item -Path $marker -Force | Out-Null
    Set-ItemProperty -Path $marker -Name 'Version' -Value $adtSession.AppVersion
    Set-ItemProperty -Path $marker -Name 'InstallDate' -Value (Get-Date -Format s)

    # End of the Post-Uninstallation phase
    Remove-Item -Path "HKLM:\SOFTWARE\SmartETC\Apps\$($adtSession.AppName)" -Recurse -Force -ErrorAction SilentlyContinue
    ```

3. **Remove the marker.** In `Uninstall-ADTDeployment`, under "&lt;Perform Post-Uninstallation tasks here&gt;", add the `Remove-Item` line from the same block.

4. **Make the Install phase repeatable.** Intune will run the install command again on a device where Firefox is already present. The Firefox MSI does not support a repair through Windows Installer, so the package installs over the existing version. In the Install phase add the switch `-SkipMSIAlreadyInstalledCheck` to the `Start-ADTMsiProcess` line from Lab 10.1 (code below). Without it the toolkit sees that the MSI is already installed and skips the installation without a message.

    ```
    ## <Perform Installation tasks here>
    Start-ADTMsiProcess -Action Install -FilePath 'FirefoxESR.msi' -SkipMSIAlreadyInstalledCheck
    ```

5. **Test locally.** Copy the folder to CL4 and run `Invoke-AppDeployToolkit.exe -DeploymentType Install` from an elevated prompt. Firefox is already installed, so the toolkit log in `C:\Windows\Logs\Software` must show that the MSI is installed again and not skipped. Check the marker: `Get-ItemProperty 'HKLM:\SOFTWARE\SmartETC\Apps\<AppName>'` shows Version and InstallDate.

6. **Repackage.** IntuneWinAppUtil: source folder `C:\ADTSoftware\FirefoxESR`, setup file `Invoke-AppDeployToolkit.exe`, output `C:\Software\Intune\FirefoxESR`.

7. **Update the app.** Intune admin center → Apps → Windows → Mozilla Firefox ESR → Properties → App information → Edit → App package file: select the new .intunewin. Commands and assignment stay as they are.

8. **Change the detection.** Properties → Detection rules → Edit. Remove the `policies.json` rule and add two rules – both must be true: (1) rule type Registry, key path `HKEY_LOCAL_MACHINE\SOFTWARE\SmartETC\Apps\<AppName>`, value name Version, detection method Value exists, associated with a 32-bit app on 64-bit clients = No. (2) rule type File, path `%ProgramFiles%\Mozilla Firefox`, file `firefox.exe`, detection method File or folder exists, 32-bit = No.

9. Delete the marker key on CL4 once by hand and sync. Firefox is installed, but the marker is missing: with the new detection the app counts as not installed, Intune runs the install command again and the package writes the marker. This is exactly the lever Part B pulls remotely.

### Part B – Remediation on demand

1. Note the current InstallDate in the marker key on CL4.

2. Intune admin center → Devices → Scripts and remediations → Remediations → Create: name SCMI-Repair-Firefox. Paste the two scripts below and replace `<AppName>` in both with the `AppName` of your package. Run this script using the logged-on credentials = No, enforce script signature check = No, run script in 64-bit PowerShell = Yes.

    ```powershell
    # Detection script – reports an issue as long as the marker exists
    $marker = 'HKLM:\SOFTWARE\SmartETC\Apps\<AppName>'
    if (Test-Path $marker) { Write-Output 'Marker present'; exit 1 }
    Write-Output 'Marker already removed'; exit 0
    ```

    ```
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
    ```

3. On the Assignments page select **no group**. The remediation is only run on demand: assigned to a group it would remove the marker at every scheduled run and reinstall Firefox again and again.

4. Intune admin center → Devices → Windows → CL4 → … → Run remediation → SCMI-Repair-Firefox → Run remediation.

5. On CL4 follow `HealthScripts.log` in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`: the detection script exits with 1, the remediation script runs, the marker key is gone.

6. About three minutes later the Intune Management Extension restarts. Follow `AppWorkload.log`: Mozilla Firefox ESR is evaluated as not detected, the install command runs, the toolkit log shows the MSI installation.

7. Read the marker key again: InstallDate is newer than the value from step 1.

### Checkpoint

- [ ] The marker key exists after the Intune installation, with Version and InstallDate
- [ ] After the remediation, `AppWorkload.log` shows the app as not detected and installs it again
- [ ] The toolkit log shows that the MSI was installed again, not skipped
- [ ] You can explain why the remediation must not be assigned to a group

> **Note:** Replace `<AppName>` with the `AppName` of your package. Assigned to a group, the remediation would remove the marker on every schedule run. The remediation also deletes the GRS keys under `HKLM\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps`. They hold the re-evaluation schedule of the Win32 apps; with the keys gone, the Intune Management Extension runs detection again at its next check-in instead of waiting for the schedule. The line clears the schedule for all apps, not only for Firefox: apps with a positive detection are left alone, failed apps are retried earlier than after 24 hours. The restart of the Intune Management Extension brings that check-in forward. Deleting `LastFullReportTimeUtc` under `...\Win32Apps\Reporting` makes the next status report a full one – without it the reinstallation happens on the device, but the Intune admin center shows it only much later. The restart is delayed on purpose: the remediation script itself runs inside the Intune Management Extension. Restarting the service at once would stop the script before its result is reported to Intune, so a separate process waits until the report is sent.

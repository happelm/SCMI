---
title: 'Lab 10.1 – Convert Firefox ESR with PSADT'
lab:
    title: 'Lab 10.1 – Convert Firefox ESR with PSADT'
    module: 'Day 2 – Authority, policy, apps'
---

# Lab 10.1 – Convert Firefox ESR with PSADT

**Estimated time:** 35 minutes

**Goal:** Replace the legacy Firefox wrapper with a PSADT v4 package and deploy it via Intune.

1. On your packaging machine: `Install-Module PSAppDeployToolkit -Scope CurrentUser`, then `New-ADTTemplate -Destination C:\ADTSoftware -Name FirefoxESR`.

2. Copy `FirefoxESR.msi` to Files and `policies.json` to SupportFiles (source: `C:\Software\FirefoxESR`).

3. Open `C:\Software\FirefoxESR\Install-Firefox.ps1` and `Uninstall-Firefox.ps1` next to the new `Invoke-AppDeployToolkit.ps1`. The legacy install script does five things: stop Firefox, run the MSI, accept exit codes 0 and 3010, copy `policies.json`, remove the desktop shortcut. Each one gets a place in the template.

4. **Variables.** In the `$adtSession` block at the top set `AppVendor`, `AppName`, `AppVersion` and `AppArch`, and put Firefox into `AppProcessesToClose` (code below). `AppName` must not stay empty: with an empty `AppName` and a single MSI in Files the toolkit switches to Zero-Config MSI and installs the MSI on its own.

    ```powershell
    # Variables – in the $adtSession block
    AppVendor = 'Mozilla'
    AppName = 'Firefox ESR'
    AppVersion = '140'
    AppArch = 'x64'
    AppProcessesToClose = @(@{ Name = 'firefox'; Description = 'Mozilla Firefox' })
    ```

5. **Pre-Install** – nothing to write. The template already calls `Show-ADTInstallationWelcome` with `AppProcessesToClose`. That replaces `Stop-Process`: the user is asked to close Firefox and can defer.

6. **Install** – under "&lt;Perform Installation tasks here&gt;" add the `Start-ADTMsiProcess` line (code below). The file name is enough, the toolkit looks in Files. Silent switches, MSI logging and the handling of exit code 3010 come from the toolkit.

    ```powershell
    # Install phase
    Start-ADTMsiProcess -Action Install -FilePath 'FirefoxESR.msi'
    ```

7. **Post-Install** – under "&lt;Perform Post-Installation tasks here&gt;" copy `policies.json` from SupportFiles and remove the desktop shortcut. Delete the `Show-ADTInstallationPrompt` block at the end of the function: a required deployment should not end with a message box.

    ```powershell
    # Post-Install phase
    Copy-ADTFile -Path "$($adtSession.DirSupportFiles)\policies.json" -Destination "$envProgramFiles\Mozilla Firefox\distribution"
    Remove-ADTFile -Path "$envCommonDesktop\Firefox.lnk"
    ```

8. **Uninstall** – in `Uninstall-ADTDeployment`, under "&lt;Perform Uninstallation tasks here&gt;", call the Firefox uninstaller and remove the remaining folder (code below). Pre-Uninstall again needs nothing: the template closes Firefox with a 60 second countdown.

    ```powershell
    # Uninstall phase
    $helper = "$envProgramFiles\Mozilla Firefox\uninstall\helper.exe"
    if (Test-Path -LiteralPath $helper) { Start-ADTProcess -FilePath $helper -ArgumentList '/S' }
    Remove-ADTFolder -Path "$envProgramFiles\Mozilla Firefox"
    ```

9. Compare: which lines of the legacy script have no counterpart in your package, and which behavior is new?

10. Test locally before Intune sees the package. Copy the folder FirefoxESR to CL4 and run from an elevated prompt: `Invoke-AppDeployToolkit.exe -DeploymentType Install`, then `-DeploymentType Uninstall`, then Install again. Read the toolkit log and the MSI log in `C:\Windows\Logs\Software` after each run.

11. Package with IntuneWinAppUtil: source folder `C:\ADTSoftware\FirefoxESR`, setup file `Invoke-AppDeployToolkit.exe`, output `C:\Software\Intune\FirefoxESR`.

12. Create the Win32 app Mozilla Firefox ESR: install command `Invoke-AppDeployToolkit.exe -DeploymentType Install`, uninstall command `Invoke-AppDeployToolkit.exe -DeploymentType Uninstall`, install behavior System. Return codes: add 1602 as Retry (the user deferred). Detection as in ConfigMgr: file `policies.json` in `%ProgramFiles%\Mozilla Firefox\distribution` exists, associated with a 32-bit app on 64-bit clients = No.

13. Make the deployment visible: on CL4 delete `%ProgramFiles%\Mozilla Firefox\distribution\policies.json` so that the app is no longer detected, and start Firefox. Then assign the app as required to SCMI-CL4-Group and sync CL4.

### Checkpoint

- [ ] Firefox ESR installed by Intune on CL4
- [ ] `about:policies` shows the `policies.json` settings
- [ ] Toolkit log in `C:\Windows\Logs\Software`
- [ ] The close-apps prompt appeared for the user

> **Note:** Typical errors: `policies.json` in Files instead of SupportFiles, detection on the wrong path, v3 function names copied from internet examples.

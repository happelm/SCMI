---
title: 'Lab 10.2 – AI-assisted conversion'
lab:
    title: 'Lab 10.2 – AI-assisted conversion'
    module: 'Day 2 – Authority, policy, apps'
---

# Lab 10.2 – AI-assisted conversion

**Estimated time:** 30 minutes

**Goal:** Convert Notepad++ – both deployment types – into one PSADT package with an AI assistant, and prove it works.

Work on **SCCM** for steps 2 to 12, in one PowerShell window: start **Windows PowerShell as administrator** and keep it open until the package is built. Every command below uses full paths, so it works no matter which folder the window is in. Only the test in step 11 runs on CL4.

1. **Read the source.** ConfigMgr console → Applications → Notepad++ → Deployment Types. There are two: Notepad++ Finance (requirement: global condition SmartETC Department equals Finance, install `Install-Finance.ps1`, detection registry value `Edition = Finance` under `HKLM\SOFTWARE\SmartETC\NotepadPP`) and Notepad++ Standard (install `npp-installer-x64.exe /S`, script detection on `notepad++.exe`). ConfigMgr picks the first deployment type whose requirements are met. A Win32 app has no deployment types – the decision has to move into the package.

2. In the PowerShell window on SCCM, create the package folder `C:\ADTSoftware\NotepadPP` and copy the installer from the ConfigMgr source into its Files folder:

    ```powershell
    New-ADTTemplate -Destination C:\ADTSoftware -Name NotepadPP
    ```

    ```powershell
    Copy-Item C:\Software\NotepadPP\npp-installer-x64.exe C:\ADTSoftware\NotepadPP\Files
    ```

3. **Build one input file.** Copilot accepts only a few uploads per prompt, so everything the model needs goes into a single text file. Run the code block below in the same window. It loads the ConfigMgr module itself, reads the application from the site and changes back to drive C: afterwards. It writes `C:\ADTSoftware\NppInput\NppInput.txt` with four marked sections: the legacy script, the application XML with both deployment types, the untouched template and the list of valid functions.

    ```powershell
    Import-Module "$env:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"
    if (-not (Get-Module PSAppDeployToolkit)) { Import-Module PSAppDeployToolkit }
    $site = (Get-PSDrive -PSProvider CMSite | Select-Object -First 1).Name
    Push-Location "$($site):"
    $appXml = (Get-CMApplication -Name 'Notepad++').SDMPackageXML
    Pop-Location
    $in = 'C:\ADTSoftware\NppInput'
    New-Item -Path $in -ItemType Directory -Force | Out-Null
    $parts = [ordered]@{
        'LEGACY SCRIPT: Install-Finance.ps1'                 = Get-Content -Path 'C:\Software\NotepadPP\Install-Finance.ps1' -Raw
        'CONFIGMGR APPLICATION XML (both deployment types)'  = $appXml
        'TEMPLATE: Invoke-AppDeployToolkit.ps1'              = Get-Content -Path 'C:\ADTSoftware\NotepadPP\Invoke-AppDeployToolkit.ps1' -Raw
        'VALID FUNCTIONS (Get-Command -Module PSAppDeployToolkit)' = (Get-Command -Module PSAppDeployToolkit).Name -join "`r`n"
    }
    $parts.GetEnumerator() |
        ForEach-Object { "===== $($_.Key) =====`r`n$($_.Value)`r`n" } |
        Set-Content -Path "$in\NppInput.txt" -Encoding UTF8
    ```

4. Open `C:\ADTSoftware\NppInput\NppInput.txt` and check it before it leaves your machine: four sections, no credentials, no license keys, no customer names.

5. **Prompt.** Open [Microsoft 365 Copilot Chat](https://m365.cloud.microsoft/chat){:target="_blank" rel="noopener"} with your tenant admin and switch the response mode from the default to the deep reasoning mode (**Think Deeper**). In the quick mode Copilot returns only the changed parts of the template instead of the complete script. Then upload `NppInput.txt` and paste the prompt below. Do not shorten the rules – each one closes a typical gap.

    ```text
    Role: packaging engineer, PSAppDeployToolkit v4.1+, Intune Win32 apps.
    Task: convert the legacy install into the template (both in the attachment).
          The ConfigMgr application has two deployment types (see the XML):
          Finance and Standard. Build ONE package that decides at run time.
    Decision:
     - Read HKLM\SOFTWARE\SmartETC\Department (64-bit view).
     - Value 'Finance' -> Finance edition. Any other value or no value -> Standard.
     - Write the decision to the toolkit log.
    Rules:
     - Use only functions from the section VALID FUNCTIONS.
     - Set AppVendor, AppName, AppVersion in $adtSession.
     - Close processes via $adtSession.AppProcessesToClose.
     - No ServiceUI. No hard-coded user paths.
     - Keep every step of the legacy script or explain why not.
     - Repair must evaluate the department again.
     - Uninstall removes the Edition value.
    Output:
     1. Invoke-AppDeployToolkit.ps1 as ONE complete file in ONE code block:
        the whole template from the first to the last line, with your changes
        built in. Not a diff, not only the changed parts, no "..." or
        "rest unchanged" placeholders. If the answer gets too long, stop at
        the end of a function and continue when I write "continue".
     2. Intune detection rule and return codes
     3. Test checklist: install, uninstall, repair, prompt
    Attachment: NppInput.txt with four sections marked by ===== lines:
                legacy script, ConfigMgr application XML, template, valid functions
    ```

6. Save the answer as `Invoke-AppDeployToolkit.ps1` in `C:\ADTSoftware\NotepadPP` and overwrite the template. Save the prompt, the model name and the date as `Prompt.txt` next to it.

7. **Read before you run.** Check by reading: `AppName` is set (otherwise Zero-Config MSI logic applies), the department is read from `HKLM\SOFTWARE\SmartETC\Department`, a missing value leads to Standard, the installer is started from Files with /S, only the Finance branch writes Edition, the uninstall phase calls `uninstall.exe /S` and removes the Edition value, and the decision is written to the log.

8. **Function check.** Models invent function names that sound right, often from the old v3 toolkit. Copy the code block below, paste it into the PowerShell window on SCCM and press Enter. The block is not part of `Invoke-AppDeployToolkit.ps1` – it is a separate test that you run against the script. The block reads `Invoke-AppDeployToolkit.ps1` without running it, collects every command with -ADT in its name and prints those the installed module does not know. No output is the good result: every ADT function in the script exists. If a name is printed, that line of the script would fail at run time – replace the function or give the name back to Copilot. To see the check react, add a line `Remove-ADTNonsense` to the script, run the block again, and remove the line. The check only looks at names, not at parameters.

    ```powershell
    # Function check – lists every ADT command the script uses that the module does not know
    if (-not (Get-Module PSAppDeployToolkit)) { Import-Module PSAppDeployToolkit }
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            'C:\ADTSoftware\NotepadPP\Invoke-AppDeployToolkit.ps1', [ref]$null, [ref]$null)
    $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true) |
        ForEach-Object { $_.GetCommandName() } | Sort-Object -Unique |
        Where-Object { $_ -like '*-ADT*' -and -not (Get-Command $_ -ErrorAction Ignore) }
    ```

9. **Analyzer.** In the same window, install the module once, then run the analyzer against the script:

    ```powershell
    Install-Module PSScriptAnalyzer -Scope CurrentUser
    ```

    ```powershell
    Invoke-ScriptAnalyzer -Path C:\ADTSoftware\NotepadPP\Invoke-AppDeployToolkit.ps1 -Severity Warning, Error
    ```

10. Fix what the two checks and your reading found – by hand or by giving the finding back to Copilot in the same chat. Write down one thing the model got wrong.<br>
    If you need a working ps1, you can find it in the [Labfiles folder](https://github.com/happelm/SCMI/tree/main/Labfiles): the complete script (built for PSAppDeployToolkit 4.1.8) and `NotepadPP-Blocks.txt` with the parts to paste into your own template.

11. **Test on CL4.** Copy the folder `C:\ADTSoftware\NotepadPP` from SCCM to the same path on CL4. On CL4 start Windows PowerShell as administrator and run the install. CL4 has no Department value: expect the Standard edition, no Edition value under `HKLM\SOFTWARE\SmartETC\NotepadPP`, and the decision in the toolkit log in `C:\Windows\Logs\Software`. Then test the uninstall.

    ```powershell
    C:\ADTSoftware\NotepadPP\Invoke-AppDeployToolkit.exe -DeploymentType Install
    ```

    ```powershell
    C:\ADTSoftware\NotepadPP\Invoke-AppDeployToolkit.exe -DeploymentType Uninstall
    ```

12. **Package and deploy.** Back on SCCM, in the same PowerShell window, package the folder with the IntuneWinAppUtil that you downloaded in Lab 9.1. Run the command below in PowerShell: the source folder is the whole package, the setup file is `Invoke-AppDeployToolkit.exe`, and the result is written to `C:\Software\Intune\NotepadPP`.

    ```powershell
    C:\Software\Tools\IntuneWinAppUtil.exe -c C:\ADTSoftware\NotepadPP -s Invoke-AppDeployToolkit.exe -o C:\Software\Intune\NotepadPP
    ```

    IntuneWinAppUtil always names the file after the setup file, so every PSADT package would be called `Invoke-AppDeployToolkit.intunewin`. Rename it, so that you pick the right file in the upload dialog:

    ```powershell
    Rename-Item C:\Software\Intune\NotepadPP\Invoke-AppDeployToolkit.intunewin NotepadPP.intunewin
    ```

    Then create the Win32 app Notepad++ with this file and the install and uninstall command below, install behavior System, return code 1602 as Retry.

    Install command:

    ```text
    Invoke-AppDeployToolkit.exe -DeploymentType Install
    ```

    Uninstall command:

    ```text
    Invoke-AppDeployToolkit.exe -DeploymentType Uninstall
    ```

13. Detection: one rule that is true for both editions – file `notepad++.exe` in `%ProgramFiles%\Notepad++` exists, associated with a 32-bit app on 64-bit clients = No. The registry rule of the Finance deployment type would report Standard devices as failed.

14. Assign the app as required to SCMI-CL4-Group and sync.

15. Compare with ConfigMgr: where did the two deployment types, the global condition and the two detection methods go?

### Checkpoint

- [ ] The function check returns nothing
- [ ] CL4 has Notepad++ Standard and no Edition value
- [ ] The log shows the department decision
- [ ] You can name one thing the model got wrong

> **Optional:** On CL4 create the string value `Department = Finance` under `HKLM\SOFTWARE\SmartETC` and run the install again in the elevated PowerShell on CL4. Check that the log names the Finance edition and that `Edition = Finance` exists under `HKLM\SOFTWARE\SmartETC\NotepadPP`.
>
> ```powershell
> C:\ADTSoftware\NotepadPP\Invoke-AppDeployToolkit.exe -DeploymentType Install
> ```

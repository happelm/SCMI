---
title: 'Lab 10.2 – AI-assisted conversion'
lab:
    title: 'Lab 10.2 – AI-assisted conversion'
    module: 'Day 2 – Authority, policy, apps'
---

# Lab 10.2 – AI-assisted conversion

**Estimated time:** 30 minutes

**Goal:** Convert Notepad++ – both deployment types – into one PSADT package with an AI assistant, and prove it works.

1. **Read the source.** ConfigMgr console → Applications → Notepad++ → Deployment Types. There are two: Notepad++ Finance (requirement: global condition SmartETC Department equals Finance, install `Install-Finance.ps1`, detection registry value `Edition = Finance` under `HKLM\SOFTWARE\SmartETC\NotepadPP`) and Notepad++ Standard (install `npp-installer-x64.exe /S`, script detection on `notepad++.exe`). ConfigMgr picks the first deployment type whose requirements are met. A Win32 app has no deployment types – the decision has to move into the package.

2. Create the package folder: `New-ADTTemplate -Destination C:\ADTSoftware -Name NotepadPP`. Copy `npp-installer-x64.exe` to Files.

3. **Build one input file.** Copilot accepts only a few uploads per prompt, so everything the model needs goes into a single text file. On SCCM, in the ConfigMgr PowerShell session, run the code block below. It writes `C:\ADTSoftware\NppInput\NppInput.txt` with four marked sections: the legacy script, the application XML with both deployment types, the untouched template and the list of valid functions.

    ```powershell
    # Build one input file for the model – run in the ConfigMgr PowerShell session on SCCM
    Import-Module PSAppDeployToolkit
    $in = 'C:\ADTSoftware\NppInput'
    New-Item -Path $in -ItemType Directory -Force | Out-Null
    $parts = [ordered]@{
        'LEGACY SCRIPT: Install-Finance.ps1'                 = Get-Content -Path 'C:\Software\NotepadPP\Install-Finance.ps1' -Raw
        'CONFIGMGR APPLICATION XML (both deployment types)'  = (Get-CMApplication -Name 'Notepad++').SDMPackageXML
        'TEMPLATE: Invoke-AppDeployToolkit.ps1'              = Get-Content -Path 'C:\ADTSoftware\NotepadPP\Invoke-AppDeployToolkit.ps1' -Raw
        'VALID FUNCTIONS (Get-Command -Module PSAppDeployToolkit)' = (Get-Command -Module PSAppDeployToolkit).Name -join "`r`n"
    }
    $parts.GetEnumerator() |
        ForEach-Object { "===== $($_.Key) =====`r`n$($_.Value)`r`n" } |
        Set-Content -Path "$in\NppInput.txt" -Encoding UTF8
    ```

4. Open `NppInput.txt` and check it before it leaves your machine: four sections, no credentials, no license keys, no customer names.

5. **Prompt.** Open Microsoft 365 Copilot Chat (m365.cloud.microsoft/chat) with your tenant admin, upload `NppInput.txt` and paste the prompt below. Do not shorten the rules – each one closes a typical gap.

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
     1. Invoke-AppDeployToolkit.ps1 (complete)
     2. Intune detection rule and return codes
     3. Test checklist: install, uninstall, repair, prompt
    Attachment: NppInput.txt with four sections marked by ===== lines:
                legacy script, ConfigMgr application XML, template, valid functions
    ```

6. Save the answer as `Invoke-AppDeployToolkit.ps1` in `C:\ADTSoftware\NotepadPP`. Save the prompt, the model name and the date as `Prompt.txt` next to it.

7. **Read before you run.** Check by reading: `AppName` is set (otherwise Zero-Config MSI logic applies), the department is read from `HKLM\SOFTWARE\SmartETC\Department`, a missing value leads to Standard, the installer is started from Files with /S, only the Finance branch writes Edition, the uninstall phase calls `uninstall.exe /S` and removes the Edition value, and the decision is written to the log.

8. **Function check.** Models invent function names that sound right, often from the old v3 toolkit. Open a PowerShell window, change to `C:\ADTSoftware\NotepadPP`, copy the code block below, paste it into the window and press Enter. The block is not part of `Invoke-AppDeployToolkit.ps1` – it is a separate test that you run against the script. The block reads `Invoke-AppDeployToolkit.ps1` without running it, collects every command with -ADT in its name and prints those the installed module does not know. No output is the good result: every ADT function in the script exists. If a name is printed, that line of the script would fail at run time – replace the function or give the name back to Copilot. To see the check react, add a line `Remove-ADTNonsense` to the script, run the block again, and remove the line. The check only looks at names, not at parameters.

    ```powershell
    # Function check – lists every ADT command the script uses that the module does not know
    Import-Module PSAppDeployToolkit
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            (Resolve-Path '.\Invoke-AppDeployToolkit.ps1'), [ref]$null, [ref]$null)
    $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true) |
        ForEach-Object { $_.GetCommandName() } | Sort-Object -Unique |
        Where-Object { $_ -like '*-ADT*' -and -not (Get-Command $_ -ErrorAction Ignore) }
    ```

9. **Analyzer.** `Install-Module PSScriptAnalyzer -Scope CurrentUser`, then `Invoke-ScriptAnalyzer -Path .\Invoke-AppDeployToolkit.ps1 -Severity Warning, Error`.

10. Fix what the two checks and your reading found – by hand or by giving the finding back to Copilot in the same chat. Write down one thing the model got wrong.<br>
    If you need a working ps1, you can find it in the [Labfiles folder](https://github.com/happelm/SCMI/tree/main/Labfiles): the complete script (built for PSAppDeployToolkit 4.1.8) and `NotepadPP-Blocks.txt` with the parts to paste into your own template.

11. **Test on CL4.** Copy the folder NotepadPP to CL4 and run from an elevated prompt: `Invoke-AppDeployToolkit.exe -DeploymentType Install`. CL4 has no Department value: expect the Standard edition, no Edition value under `HKLM\SOFTWARE\SmartETC\NotepadPP`, and the decision in the toolkit log in `C:\Windows\Logs\Software`. Then test `-DeploymentType Uninstall`.

12. **Package and deploy.** IntuneWinAppUtil: source folder `C:\ADTSoftware\NotepadPP`, setup file `Invoke-AppDeployToolkit.exe`, output `C:\Software\Intune\NotepadPP`. Win32 app Notepad++: install command `Invoke-AppDeployToolkit.exe -DeploymentType Install`, uninstall command `Invoke-AppDeployToolkit.exe -DeploymentType Uninstall`, install behavior System, return code 1602 as Retry.

13. Detection: one rule that is true for both editions – file `notepad++.exe` in `%ProgramFiles%\Notepad++` exists, associated with a 32-bit app on 64-bit clients = No. The registry rule of the Finance deployment type would report Standard devices as failed.

14. Assign the app as required to SCMI-CL4-Group and sync.

15. Compare with ConfigMgr: where did the two deployment types, the global condition and the two detection methods go?

### Checkpoint

- [ ] The function check returns nothing
- [ ] CL4 has Notepad++ Standard and no Edition value
- [ ] The log shows the department decision
- [ ] You can name one thing the model got wrong

> **Optional:** On CL4 create the string value `Department = Finance` under `HKLM\SOFTWARE\SmartETC` and run `Invoke-AppDeployToolkit.exe -DeploymentType Install` again from the elevated prompt. Check that the log names the Finance edition and that `Edition = Finance` exists under `HKLM\SOFTWARE\SmartETC\NotepadPP`.

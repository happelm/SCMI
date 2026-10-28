---
title: 'Lab 9.1 – Map Greenshot to the Win32 model'
lab:
    title: 'Lab 9.1 – Map Greenshot to the Win32 model'
    module: 'Day 2 – Authority, policy, apps'
---

# Lab 9.1 – Map Greenshot to the Win32 model

**Estimated time:** 15 minutes

**Goal:** Rebuild Greenshot and its runtime dependency as Win32 apps and deploy them to CL4.

1. Download `IntuneWinAppUtil.exe` (GitHub: microsoft/Microsoft-Win32-Content-Prep-Tool).
2. Package `C:\Software\VCRedist` (setup file `vc_redist.x64.exe`) and `C:\Software\Greenshot` (`greenshot-installer.exe`). Save the packages under `C:\Software\Intune`.
3. **ConfigMgr console**: open the deployment types of Greenshot and Microsoft Visual C++ Redistributable x64 and note install command, uninstall command and detection method of each.
4. **Intune admin center** → Apps → Windows → Add → Windows app (Win32): create **Greenshot** first. Install behavior System. Do not assign the app yet.

    Install command:

    ```text
    greenshot-installer.exe /VERYSILENT /NORESTART /SUPPRESSMSGBOXES /ALLUSERS
    ```

    Uninstall command:

    ```text
    "%ProgramFiles%\Greenshot\unins000.exe" /VERYSILENT /NORESTART
    ```

    Detection rule – manually configured:

    | Setting | Value |
    |---|---|
    | Rule type | File |
    | Path | `%ProgramFiles%\Greenshot` |
    | File or folder | `Greenshot.exe` |
    | Detection method | File or folder exists |
    | Associated with a 32-bit app on 64-bit clients | No |

5. Create **Microsoft Visual C++ Redistributable x64** as the second Win32 app. Install behavior System. Do not assign it.

    Install command:

    ```text
    vc_redist.x64.exe /install /quiet /norestart
    ```

    Uninstall command:

    ```text
    vc_redist.x64.exe /uninstall /quiet /norestart
    ```

6. Detection of the VC++ app – the registry rule is written differently than in ConfigMgr. ConfigMgr stores the hive and the key separately (Local Machine + `SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64`). Intune wants one full key path.

    Key path:

    ```text
    HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64
    ```

    | Setting | Value |
    |---|---|
    | Rule type | Registry |
    | Value name | `Installed` |
    | Detection method | Integer comparison |
    | Operator | Equals |
    | Value | 1 |
    | Associated with a 32-bit app on 64-bit clients | No |

7. Only now connect the two: Greenshot → Properties → Dependencies → add Microsoft Visual C++ Redistributable x64 with Automatically install = Yes.
8. Only then deploy: assign Greenshot as available to the existing device group SCMI-CL4-Group. The VC++ app gets no assignment of its own – it arrives through the dependency.
9. Sync CL4, install Greenshot from the Company Portal and follow `AppWorkload.log` in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`: the dependency is detected and installed first, then Greenshot.

### Checkpoint

- [ ] Greenshot and VC++ installed on CL4
- [ ] Both apps report Installed in Intune
- [ ] You can name what you did not take over from the ConfigMgr app

> **Optional:** Rebuild SmartETC Toolbox as a Win32 app and take the detection over unchanged (file `toolbox.txt` in `%ProgramData%\SmartETC\Tools`). Assign it to SCMI-CL4-Group: the script installs, Intune reports the app as failed because it is not detected after the installation – the same deliberate error as in ConfigMgr. Correct the detection path to `%ProgramData%\SmartETC\Toolbox`.

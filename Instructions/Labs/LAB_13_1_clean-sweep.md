---
title: 'Lab 13.1 – Clean sweep'
lab:
    title: 'Lab 13.1 – Clean sweep'
    module: 'Day 3 – Deliver, clean up, operate'
---

# Lab 13.1 – Clean sweep

**Estimated time:** 30 minutes

**Goal:** Remove ConfigMgr from CL4 and leave exactly one record of CL2 in every system.

1. **Stop the reinstall.** Intune admin center → Groups → SCMI-ConfigMgr-Client → Members: remove CL4. As long as CL4 is a member, the required `ccmsetup.msi` app installs the client again.

2. **Uninstall the client.** Intune admin center → Devices → Scripts and remediations → Platform scripts → Add → Windows: name SCMI-Uninstall-CMClient, upload a .ps1 file with the line below. Run this script using the logged-on credentials = No, enforce script signature check = No, run script in 64-bit PowerShell host = Yes. Assign it to SCMI-CL4-Group. A platform script runs once per device.

    ```powershell
    Start-Process -FilePath "$env:WINDIR\ccmsetup\ccmsetup.exe" -ArgumentList '/uninstall' -Wait
    ```

3. Sync CL4 and restart the Intune Management Extension service. Follow `C:\Windows\ccmsetup\Logs\ccmsetup.log` until the uninstall has finished. `Get-Service CcmExec` must return an error, `C:\Windows\CCM` is gone.

4. Intune admin center → Devices → CL4: the device is still managed by Intune. Note what the device page shows under management and ConfigMgr agent status.

5. **One record in ConfigMgr.** ConfigMgr console → Assets and Compliance → Devices: delete the old CL2 record (the hybrid joined device with the ConfigMgr client) and the CL4 record.

6. **Check before you delete.** Entra admin center → Devices → All devices → search CL2: two objects, one Microsoft Entra hybrid joined (old), one Microsoft Entra joined (new). Open the old one → BitLocker keys and note whether keys are stored there.

7. **Take it out of the sync scope.** On the DC: disable the CL2 computer object and move it from `OU=Cloud\Workstations\Sales` to an OU outside `OU=Cloud`.

8. After the next Cloud Sync cycle (Entra admin center → Entra Connect → Cloud sync → your configuration → Provisioning logs): the old hybrid CL2 object is deleted, only the Entra joined CL2 is left.

### Checkpoint

- [ ] CL4: no CcmExec service, Intune still manages it
- [ ] Entra: exactly one CL2, join type Entra joined
- [ ] ConfigMgr: no CL2

> **Optional:** Unlink the GPOs from `Cloud\Workstations\Sales`.

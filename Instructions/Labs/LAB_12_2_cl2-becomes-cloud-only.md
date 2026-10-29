---
title: 'Lab 12.2 – CL2 becomes cloud-only'
lab:
    title: 'Lab 12.2 – CL2 becomes cloud-only'
    module: 'Day 3 – Deliver, clean up, operate'
---

# Lab 12.2 – CL2 becomes cloud-only

**Estimated time:** 25 minutes

**Goal:** Document CL2's current state, reset it and join it to Entra – without ConfigMgr and without Autopilot.

1. Record the old state: `dsregcmd /status` on CL2, the CL2 record in ConfigMgr, the Entra device object (join type, device ID) and the AD computer object. Note the serial number of CL2 as well:

   ```powershell
   Get-CimInstance Win32_BIOS | Select-Object SerialNumber
   ```

2. Walk through the reset checklist from the slides and note what would be lost on a real device.

3. **Give CL2 a new hardware identity.** The VM may still be registered in Windows Autopilot from an earlier course, in a tenant that is not yours – after the reset, OOBE would then pick up that tenant's profile. Autopilot recognizes the device by its hardware hash; the BIOS serial number and the BIOS GUID of the VM are part of it. A new serial number and GUID make CL2 a device that Autopilot does not know.

    Shut down CL2. On the Hyper-V host, start Windows PowerShell as administrator, download the script from the [Labfiles folder](https://github.com/happelm/SCMI/tree/main/Labfiles) and run it. The script expects the VM name `CL2` – if your VM has a different name in Hyper-V Manager, change `$vmName` in the first lines of the script.

   ```powershell
   Stop-VM -Name CL2
   ```

   ```powershell
   Invoke-WebRequest -Uri 'https://github.com/happelm/SCMI/raw/main/Labfiles/Set-HyperVBiosIdentity.ps1' -OutFile $env:TEMP\Set-HyperVBiosIdentity.ps1
   ```

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File $env:TEMP\Set-HyperVBiosIdentity.ps1
   ```

    The output shows the old and the new values and `ReturnValue: 0`. Start CL2 and run the command from step 1 again: the serial number is new. The ConfigMgr client on CL2 also uses the BIOS GUID as its hardware ID – that does not matter here, because the reset removes the client, and the old record is cleaned up in Lab 13.1.

4. On CL2: Settings → System → Recovery → Reset this PC → Remove everything.

5. When OOBE appears, sign in as User2 with a work or school account.

6. Afterwards: `dsregcmd /status` and the new CL2 in Intune.

### Checkpoint

- [ ] CL2: `AzureAdJoined` YES, `DomainJoined` NO
- [ ] CL2 enrolled in Intune, no ConfigMgr client
- [ ] The old records are noted for Lab 13.1

> **Note:** Do not add CL2 to SCMI-ConfigMgr-Client – CL2 should end cloud-only.

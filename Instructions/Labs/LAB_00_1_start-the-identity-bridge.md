---
title: 'Lab 0.1 – Start the identity bridge'
lab:
    title: 'Lab 0.1 – Start the identity bridge'
    module: 'Day 1 – Assess, bridge, connect'
---

# Lab 0.1 – Start the identity bridge

**Estimated time:** 30 minutes

**Goal:** Sync User1, User2 and the computer objects of CL1/CL2 and complete the hybrid join of both devices.

1. On DC1, open Active Directory Domains and Trusts and add your tenant's onmicrosoft.com default domain as a new UPN suffix.
2. Change the UPNs of User1 and User2 to the new domain suffix.
3. On SRV1, download the provisioning agent from Entra admin center → Entra Connect → Cloud sync → Agents and install it. Sign in with your tenant admin and let the wizard create the gMSA with SMART\Administrator.
4. Entra admin center → Mobility (MDM and WIP) → Microsoft Intune: set the MDM user scope to All.
5. Entra admin center → Cloud sync → New configuration → AD to Microsoft Entra ID sync, domain smart.etc.
6. Configuration → Properties → Basics: enable device sync (preview).
7. Scoping filter: selected organizational units → `OU=Cloud,DC=smart,DC=etc`<br>
    Enable the configuration.
8. Create the service connection point (needs Enterprise Admin): on the DC, run `ConfigureSCP.ps1 -Domain <your verified tenant domain> -TenantId <your tenant ID>`. The script is on the Learn page "Configure device sync with Microsoft Entra Cloud Sync" <https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/device-sync>. It is also in your Labfiles folder.
9. Assign an M365 E5 or EMS E5 license (depending on your tenant) to the new synced users.
10. On CL1 and CL2, sign in and start the scheduled task Automatic-Device-Join (Task Scheduler → Microsoft → Windows → Workplace Join), or run `Start-ScheduledTask -TaskPath '\Microsoft\Windows\Workplace Join\' -TaskName 'Automatic-Device-Join'` in an elevated PowerShell. The join attempt writes the certificate that the sync needs. Then run `dsregcmd /status` on both devices and confirm the hybrid join. User1 and User2 were signed in before the join and have no PRT yet: sign out and in again, wait a minute and check that `AzureAdPrt` is YES.

### Checkpoint

- [ ] User1 and User2 are listed in Entra ID as synchronized users
- [ ] After the task has run, the provisioning logs list CL1 and CL2
- [ ] CL1 and CL2: `dsregcmd /status` shows `AzureAdJoined` YES and `DomainJoined` YES
- [ ] After a new sign-in: `AzureAdPrt` YES for User1 on CL1 and User2 on CL2

> **Note:** Device sync with Cloud Sync is in preview. The order matters: without a registration attempt by the client, `userCertificate` stays empty and the device does not appear in the provisioning logs at all. Use the task, not `dsregcmd /join` or a restart – in the dry run only the task triggered the sync reliably. The SCP is forest-wide: `CN=62a0ff2e-97b9-4513-943f-0d221bd30080` under `CN=Device Registration Configuration,CN=Services` in the configuration partition.

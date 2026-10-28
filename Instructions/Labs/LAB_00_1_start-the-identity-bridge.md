---
title: 'Lab 0.1 – Start the identity bridge'
lab:
    title: 'Lab 0.1 – Start the identity bridge'
    module: 'Day 1 – Assess, bridge, connect'
---

# Lab 0.1 – Start the identity bridge

**Estimated time:** 30 minutes

**Goal:** Sync User1, User2 and the computer objects of CL1/CL2 and complete the hybrid join of both devices.

> **Important:** Do every step on your lab host, never on your own notebook: your corporate browser is often signed in to your production tenant.

1. On DC1, open Active Directory Domains and Trusts and add your tenant's onmicrosoft.com default domain as a new UPN suffix.
2. Change the UPNs of User1 and User2 to the new domain suffix.
3. Entra admin center → Entra Connect → Get started → Manage → **Download provisioning agent** (not *Download Connect Sync*). Copy the setup to SRV1 and install it there. Sign in with your tenant admin, leave **Create gMSA** selected (not *Use custom gMSA*) and enter SMART\Administrator.
4. Entra admin center → Mobility (MDM and WIP) → Microsoft Intune: set the MDM user scope to All.
5. Entra admin center → Entra Connect → Cloud sync → New configuration → AD to Microsoft Entra ID sync, domain smart.etc.
6. Configuration → Properties → Basics: enable device sync.
7. Scoping filter: select **Sync selected organizational units** (not *Sync selected security groups*), enter `OU=Cloud,DC=smart,DC=etc`, select **Add**, then **Save**.<br>
    Enable the configuration.
8. Create the service connection point (needs Enterprise Admin): on the DC, in an elevated PowerShell in the folder of the script, run the command below with your values. The script is on the Learn page "Configure device sync with Microsoft Entra Cloud Sync" <https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/device-sync>. It is also in the [Labfiles folder](https://github.com/happelm/SCMI/tree/main/Labfiles). Unblock the script first (file properties → **Unblock**) and run `Set-ExecutionPolicy RemoteSigned`. The tenant ID is on Entra admin center → Overview.

    ```powershell
    .\ConfigureSCP.ps1 -Domain <your verified tenant domain> -TenantId <your tenant ID>
    ```

9. Assign an M365 E5 or EMS E5 license (depending on your tenant) to the new synced users. If no license is free, delete two or three demo users first – not your admin account, not User1 or User2.
10. On CL1 and CL2, sign in and start the scheduled task Automatic-Device-Join (Task Scheduler → Microsoft → Windows → Workplace Join), or run the command below in an elevated PowerShell. The first run fails and writes the certificate (`userCertificate`) that the sync needs. Wait until CL1 and CL2 appear in the provisioning logs, then start the task a second time (or run `dsregcmd /join`). Then run `dsregcmd /status` on both devices and confirm the hybrid join. User1 and User2 were signed in before the join and have no PRT yet: sign out and in again, wait a minute and check that `AzureAdPrt` is YES.

    ```powershell
    Start-ScheduledTask -TaskPath '\Microsoft\Windows\Workplace Join\' -TaskName 'Automatic-Device-Join'
    ```

### Checkpoint

- [ ] User1 and User2 are listed in Entra ID as synchronized users
- [ ] After the task has run, the provisioning logs list CL1 and CL2
- [ ] CL1 and CL2: `dsregcmd /status` shows `AzureAdJoined` YES and `DomainJoined` YES
- [ ] After a new sign-in: `AzureAdPrt` YES for User1 on CL1 and User2 on CL2

> **Note:** The order matters: without a registration attempt by the client, `userCertificate` stays empty and the device does not appear in the provisioning logs at all. Users show up after a few minutes, computer objects can take up to about 20 minutes, and the provisioning logs lag behind by several minutes. To test a single device, use Provision on demand → Device with its distinguished name. The SCP is forest-wide: `CN=62a0ff2e-97b9-4513-943f-0d221bd30080` under `CN=Device Registration Configuration,CN=Services` in the configuration partition.

> **Note:** A wrong scoping filter produces no error – the configuration shows healthy and syncs nothing. If the scope was wrong, delete the configuration and create it again; that is usually faster than waiting for the changed configuration to take effect.

### If a device does not join

- Event Viewer → Applications and Services Logs → Microsoft → Windows → **User Device Registration** → Admin shows every run of the task and why it failed.
- Check in this order:
  1. The SCP names the right tenant (domain and tenant ID). If not, run `ConfigureSCP.ps1` again with the right values.
  2. The task has run on the client.
  3. The computer object has a value in `userCertificate` (Active Directory Users and Computers → View → Advanced Features → Attribute Editor).
  4. The device is listed in the Cloud Sync provisioning logs. If not, check the scoping filter: OU path, typing errors, OU instead of security group.

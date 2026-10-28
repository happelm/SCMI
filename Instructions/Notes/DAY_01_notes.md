---
title: 'Day 1 notes – Assess, bridge, connect'
---

# Day 1 notes – Assess, bridge, connect

> Summary of what was covered on Day 1, with sources – not a transcript. Recommendations marked "trainer recommendation" are field experience, not Microsoft documentation. "Lab observation" means the trainer saw it in the lab environment; it isn't documented by Microsoft.

## Key takeaways

- The workshop is about the transition from Configuration Manager to Intune, not about either product on its own. Autopilot and app packaging have their own courses; PSADT is used as the packaging framework where Intune alone isn't enough.
- No Intune without a hybrid identity: users (and, for hybrid join, computer objects) must be synced to Microsoft Entra ID first. The lab uses Microsoft Entra Cloud Sync with device sync instead of Connect Sync.
- Hybrid join plus Intune is a five-point program: hybrid identity with an Intune license, computer sync, MDM user scope, service connection point (SCP), and the trigger for MDM enrollment – the Group Policy for automatic MDM enrollment, or Configuration Manager when it manages the enrollment.
- A permanent co-management state is the most expensive outcome: two products, two skill sets. Plan the way out from the start.
- Migrate in waves (workloads × pilot collections), not as a big bang. A sequence that works in the field: compliance, endpoint protection, device configuration, Windows Update, apps last.
- An assessment comes first: count what you have, check what is actually used, and classify every object before you migrate anything.
- Tenant attach shows Configuration Manager devices in the Intune admin center – it is not an Intune enrollment. Co-management enrolls the device and splits responsibility by workload.
- Co-management sliders move responsibility, not policies: nothing is created in Intune and nothing is removed from the device. Apps can come from both sides whatever the slider says.
- Entra joined devices have no AD computer object: OU-based collections never contain them, and the Configuration Manager client authenticates with a Microsoft Entra token.

## 1. Lab environment

| Machine | Role | State at the start of Day 1 |
|---|---|---|
| DC1 | Domain controller, DHCP (domain `smart.etc`) | ready |
| SCCM | Configuration Manager site server, version 2609 | ready |
| SRV1 | Server for the Cloud Sync provisioning agent | empty |
| CL1, CL2 | Windows 11 clients, domain joined, ConfigMgr client | in production (User1 on CL1, User2 on CL2, auto sign-in) |
| CL3, CL4 | Windows 11 clients | in OOBE, set up during Day 1 |

- Clients run Windows 11 26H2, servers Windows Server 2025 (one server still on 2022 – no impact on the labs).
- CL1/CL2 and User1/User2 are in OUs below `OU=Cloud,DC=smart,DC=etc` – only this OU is synced.
- Remote Desktop Connection Manager has all machines. Trainer tip: right-click the group → **Reconnect group** after a resolution change, so the sessions fit your screen.
- Do every step on your lab host, never on your own notebook: your corporate browser is often signed in to your production tenant, and the portals look the same. It also avoids copy-paste problems between machines; a VPN on your own machine can block the course network.
- The tenant comes from the lab hoster. Tenants can differ in licenses (Microsoft 365 E3/E5, EMS E5). For this course the difference doesn't matter – each of them includes Intune.

### The client journey over three days

| Client | Start | End of Day 1 | Later |
|---|---|---|---|
| CL1 | Domain joined, ConfigMgr only | Hybrid joined, co-managed, visible through tenant attach | Workloads move to Intune on Day 2 (compliance, configuration) and Day 3 (updates) |
| CL2 | Domain joined, ConfigMgr only | Hybrid joined, tenant attached | Day 3: reset, Entra joined, Intune only |
| CL3, CL4 | New device (OOBE) | Entra joined, Intune from the first second, ConfigMgr client installed from Intune | Apps come from both sides until the ConfigMgr client is removed |

- **Apps are not a co-management workload switch.** A co-managed device can get apps from Configuration Manager and from Intune at the same time – on purpose, because apps are the biggest migration topic.
- **Cloud first** (CL3/CL4): new devices are Entra joined from the start and only take from Configuration Manager what Intune can't do yet. Trainer recommendation: don't block new devices with a hybrid join just because the migration isn't finished.
- Tenant attach is the overnight task: in the lab it can take 12 to 18 hours until the devices show up (lab observation). There is no known way to speed it up.

Sources: [Co-management overview](https://learn.microsoft.com/intune/configmgr/comanage/overview) · [Co-management workloads](https://learn.microsoft.com/intune/configmgr/comanage/workloads)

## 2. Course scope

- Not a Configuration Manager course and not an Intune course – basic knowledge of both is enough. For Intune basics, see the **fast track** in the [Appendix](../Appendix.html): portal map, terms, assignments, sync cycles and a log mapping.
- **Autopilot** is the Intune way of provisioning the image that is already on the hardware – it replaces OSD, not task sequences in general. It has its own course.
- **Packaging** isn't the main topic, but the app labs use the [PowerShell App Deployment Toolkit (PSADT)](https://psappdeploytoolkit.com/) (community project), the framework most widely used for Win32 apps. It adds functionality Intune doesn't offer on its own.

## 3. Identity bridge with Microsoft Entra Cloud Sync

### Why

- Intune needs Microsoft Entra identities. A user who exists only on-premises can't be managed by Intune.
- **UPN:** single sign-on needs the same user principal name on-premises and in the cloud. The internal domain `smart.etc` doesn't exist in the cloud, so you add a routable UPN suffix in AD and change the users' UPN. In production that is your custom domain (`company.com`); in the lab it is the tenant's `onmicrosoft.com` domain, which works the same way.
- **MDM user scope = All** (Entra admin center → Mobility → Microsoft Intune): devices that register in Entra ID also enroll in Intune. Without it, the device is in Entra ID but not in Intune – and getting it in later is much harder.

### The provisioning agent

- Download: Entra admin center → Entra Connect → Get started → Manage → **Download provisioning agent** – not **Download Connect Sync**.
- The agent runs as a **group managed service account (gMSA)**. In the wizard leave **Create gMSA** selected – **Use custom gMSA** is only for an account that already exists. Creating it needs Domain Admin or Enterprise Admin credentials.
- After installation the agent registers itself; it can show as inactive for a few minutes. All configuration is done in the cloud – you don't touch the server again.
- Microsoft recommends **three active agents** on different servers for high availability. The agent can run on a domain controller; treat its server as tier 0.
- Agents update themselves; auto upgrade can't be disabled.

Sources: [Cloud Sync prerequisites](https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/how-to-prerequisites) · [Cloud Sync FAQ](https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/reference-cloud-sync-faq)

### The configuration

- Entra admin center → Entra Connect → Cloud sync → **New configuration** → **AD to Microsoft Entra ID sync**. (Not *Cross-tenant synchronization* – a different feature.)
- Properties → Basics: **Password hash sync** and **Device sync** enabled. Device sync is disabled by default.
- **Scoping filter:** choose **Sync selected organizational units**, enter the OU, select **Add** and then **Save** – both, otherwise nothing is stored.
- Watch out: choosing **Sync selected security groups** and entering an OU produces no error. The configuration shows healthy, but syncs nothing – an empty sync is green, too. Trainer recommendation: if the scope was wrong, delete the configuration and create a new one; that is often faster than waiting for a changed configuration to take effect.
- The configuration runs three jobs: user and group sync, password hash sync and device sync (`AD2AADDeviceSync`). The overview shows counts for users and groups, not for devices.
- **Provision on demand** tests a single object, including a device (tab **Device**, distinguished name of the computer). Get the DN in Active Directory Users and Computers → View → **Advanced Features** → computer properties → **Attribute Editor** → `distinguishedName`. Useful for testing, not for production.
- Synced groups (like `Cloud Users`) can't be changed in the Entra admin center – their membership comes from AD.

### Device sync status

- Device sync with Cloud Sync is generally available ([Configure device sync](https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/device-sync)). Cloud Sync supports Microsoft Entra hybrid join ([Hybrid scenarios](https://learn.microsoft.com/entra/identity/hybrid/common-scenarios)).
- Cloud Sync isn't for everyone yet: domains with more than 250,000 objects, attribute-based filtering and Windows Hello for Business are listed as Connect Sync scenarios ([Hybrid scenarios](https://learn.microsoft.com/entra/identity/hybrid/common-scenarios)).

## 4. Service connection point and hybrid join

### The five-point program: hybrid join plus Intune

1. **Hybrid identity with an Intune license** – synced users with matching UPN, licensed for Intune
2. **Computer sync** – device sync in the Cloud Sync configuration
3. **MDM user scope** – automatic enrollment in Entra ID
4. **Service connection point (SCP)** in the forest, so the client finds its tenant
5. **Trigger for the MDM enrollment** – the Group Policy for automatic MDM enrollment, but not when Configuration Manager manages the enrollment (co-management)

The join itself is done by the client (scheduled task `Automatic-Device-Join`). It needs network access to `https://enterpriseregistration.windows.net`, `https://login.microsoftonline.com` and `https://device.login.microsoftonline.com`.

Sources: [Configure hybrid join](https://learn.microsoft.com/entra/identity/devices/how-to-hybrid-join) · [Configure device sync](https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/device-sync)

### The SCP

- Connect Sync creates the SCP in its wizard. Cloud Sync can't – Microsoft provides the script `ConfigureSCP.ps1` on the device sync Learn page (also in the Labfiles).
- Run it as an **Enterprise Admin** with `-Domain` (federated domain, otherwise the primary `onmicrosoft.com` domain) and `-TenantId` (Entra admin center → Overview → copy the tenant ID).
- If an SCP exists already, the script replaces its `keywords` values – record the old values first.
- The SCP is `CN=62a0ff2e-97b9-4513-943f-0d221bd30080` under `CN=Device Registration Configuration,CN=Services` in the configuration partition (ADSI Edit → Configuration). The tenant is in the attribute `keywords` (`azureADName`, `azureADId`).
- Downloaded scripts: check file properties for **Unblock** before running. The script isn't signed: `Set-ExecutionPolicy RemoteSigned` (or `Bypass` for the session).

### The join

- On the client, the task `Automatic-Device-Join` (Task Scheduler → Microsoft → Windows → Workplace Join) runs at sign-in and periodically. Without an SCP it fails every time – an error in its last run result is normal before the SCP exists.
- The flow: the client writes a certificate to the `userCertificate` attribute of its computer object, device sync takes the object to Entra ID, and the next run of the task completes the join. Until then the device shows as **Pending** in Entra ID.
- Synced devices don't appear in Entra ID before the client has made its registration attempt.
- In production this happens by itself with sign-ins and restarts. In the lab you start the task manually to save time – or run `dsregcmd /join`, which triggers the same task.
- In public preview since March 2026: **hybrid join using Microsoft Entra Kerberos**. The device registers directly at join time – no sync cycle, no waiting. It needs at least one domain controller with Windows Server 2025 (build 26100.6905 or later) in every domain and Windows 11 build 26100.6584 or later on the clients, so it fits only where those prerequisites are met. Not used in the lab ([What's new, March 2026](https://learn.microsoft.com/entra/fundamentals/whats-new#march-2026) · [How-to](https://learn.microsoft.com/entra/identity/devices/how-to-hybrid-join-using-microsoft-entra-kerberos)).

Sources: [Device registration – how it works](https://learn.microsoft.com/entra/identity/devices/device-registration-how-it-works) · [Pending state](https://learn.microsoft.com/entra/identity/devices/hybrid-join-control#why-a-device-might-be-in-a-pending-state)

### When the join doesn't happen

- **Event log:** Event Viewer → Applications and Services Logs → Microsoft → Windows → **User Device Registration** → Admin. It shows every run of the task and why it failed. The names don't match: the log is *User Device Registration*, the task folder is *Workplace Join*.
- **The first run fails on purpose:** it writes `userCertificate` to the computer object and reports that the target is unknown. Device sync then takes the object to Entra ID (in the lab about five minutes later), and the **second** run of the task registers the device ("Automatic registration completed successfully", result `0x0`).
- Lab observation: without an SCP the task retries about every hour for a while and then stops by itself; it starts again with the next sign-in or restart. In the lab you start it manually; in production sign-ins and restarts do it for you.
- `dsregcmd /join` starts a registration attempt manually, `dsregcmd /leave` removes the device from Entra ID again (for troubleshooting only).
- Checklist when a device doesn't join:
  1. Does the SCP exist and name the right tenant (domain and tenant ID – one wrong character is enough)? If not, run `ConfigureSCP.ps1` again with the right values.
  2. Has the task run on the client?
  3. Does the computer object have a value in `userCertificate` (Attribute Editor)?
  4. Is the device in the Cloud Sync **provisioning logs**? If not, check the scoping filter – OU path, typing errors, OU instead of security group.
  5. Event log *User Device Registration*.

### Reading `dsregcmd /status`

| Field | Hybrid joined (CL1, CL2) | Entra joined (CL3, CL4) |
|---|---|---|
| `AzureAdJoined` | YES | YES |
| `DomainJoined` | YES | NO |
| `EnterpriseJoined` | NO | NO |
| `AzureAdPrt` (SSO State) | YES after the next sign-in | YES |

- Hybrid joined = `AzureAdJoined` YES **and** `DomainJoined` YES. What `dsregcmd` says is the truth – the portal can lag behind.
- `EnterpriseJoined` is the old on-premises device registration against AD FS (Windows 8.1 era); it's always NO today.
- The `DeviceId` in `dsregcmd` is the device ID in Entra ID. Entra ID allows duplicate device names – the ID identifies the device, not the name.
- `NgcSet` NO means Windows Hello for Business isn't set up for the user.

Sources: [Troubleshoot devices with dsregcmd](https://learn.microsoft.com/entra/identity/devices/troubleshoot-device-dsregcmd) · [Troubleshoot hybrid joined devices](https://learn.microsoft.com/entra/identity/devices/troubleshoot-hybrid-join-windows-current)

### Why CL1 and CL2 don't show up in Intune yet

- After the hybrid join the MDM column in Entra ID shows **None**. A domain member doesn't enroll in Intune just because the MDM user scope is set – it also needs a trigger: either the Group Policy **Enable automatic MDM enrollment using default Microsoft Entra credentials**, or Configuration Manager co-management.
- With Configuration Manager in place, let Configuration Manager trigger the enrollment (co-management, Lab 3.2). With the GPO, devices enroll behind Configuration Manager's back. Use the GPO only where there is no Configuration Manager (trainer recommendation).
- Entra joined devices (CL3, CL4) need no GPO – the MDM user scope is enough.

Sources: [Enroll a Windows device automatically using Group Policy](https://learn.microsoft.com/windows/client-management/enroll-a-windows-10-device-automatically-using-group-policy) · [Co-management overview](https://learn.microsoft.com/intune/configmgr/comanage/overview)

### Licenses

- Microsoft 365 admin center (`admin.microsoft.com`, redirects to `admin.cloud.microsoft`) → Users → Active users → select User1 and User2 → **Manage product licenses** → **Assign more**.
- Lab tenants with Microsoft 365 E5 (no Teams) often have no free licenses. Delete two or three of the demo users (not the admin account you work with, not User1 or User2).

## 5. Migration strategy

### Why now

- Configuration Manager's platform scope keeps shrinking: mobile device management and macOS support are gone; current branch is now Windows only.
- Configuration Manager stays relevant where Intune has no answer, first of all for **servers**. Keeping it healthy is part of the plan: upgrade SQL Server and the server OS in time. Both are supported as in-place upgrades – including the OS of the site server ([Upgrade on-premises infrastructure](https://learn.microsoft.com/intune/configmgr/core/servers/manage/upgrade-on-premises-infrastructure)).
- Each current branch version is supported for 18 months ([Support for current branch versions](https://learn.microsoft.com/intune/configmgr/core/servers/manage/current-branch-versions-supported)). Version 2609 is globally available since October 26, 2026 ([Checklist for 2609](https://learn.microsoft.com/intune/configmgr/core/servers/manage/checklist-for-installing-update-2609)).

- Configuration Manager moves to one release per year, with a renewed focus on security, stability and long-term support – no new features are to be expected (announcement on the Microsoft Tech Community, see slides).

### Paths

| Path | When it fits |
|---|---|
| **Permanent hybrid** | Never as a goal. Two products, two skill sets, investment in a product that is winding down. |
| **Big bang** | Small environments only (dozens of apps, not a thousand). |
| **Waves** | Larger fleets: co-management workloads decide *what* moves, pilot collections decide *how many* devices. Start small, widen the rings, then take the next workload. |

- Microsoft doesn't prescribe a workload order. Field-proven order (trainer recommendation): compliance policies → endpoint protection → device configuration → Windows Update policies → apps. The first ones are small and give early wins; apps can keep coming from Configuration Manager in the meantime.
- Questions for the project: hardware refresh cycle (new devices are the cheapest moment to change – an existing device that moves to Entra join gets a new user profile), bandwidth and branch offices, offline devices, and who decides.

### What Configuration Manager does that Intune doesn't

| Configuration Manager | Intune |
|---|---|
| Server management | Intune doesn't manage Windows Server as an MDM device. Microsoft's direction for servers is Azure Arc – a different model. |
| Task sequences (OSD and generic) | None. Autopilot replaces OSD; for chained installs use PSADT or scripts. |
| Software metering | None. The software inventory is improving, but is read-only. |
| Offline content distribution | None – everything comes from the cloud. Low bandwidth: Delivery Optimization. |
| Real-time actions at scale | Limited. Remote actions exist, but not for thousands of devices at once. |

- Intune's strengths: mobile platforms and macOS, Conditional Access, provisioning without images, and management from anywhere with internet access – no VPN or line of sight to a server.

- Windows Server isn't an Intune enrollment platform. Servers can get Defender security settings from Intune through Microsoft Defender for Endpoint security settings management – that isn't server management.

Sources: [Supported operating systems in Intune](https://learn.microsoft.com/intune/fundamentals/ref-supported-platforms) · [Defender for Endpoint security settings management](https://learn.microsoft.com/intune/device-security/microsoft-defender/security-settings-management)

## 6. Assessment: from objects to decisions

| Configuration Manager | In Intune | Note |
|---|---|---|
| Application | Win32 app | An app with no deployments is probably unused – check deployments, inventory and metering before you migrate it. |
| Deployment types | One app per variant | Intune has no deployment types. A second variant is a second app – or one PSADT package with logic. |
| Detection methods, requirements | Exist | Global conditions don't exist. |
| Dependencies, supersedence, return codes | Exist | |
| Collections | Microsoft Entra groups + assignment filters | Intune has no collections of its own. Limiting collections → dynamic group plus filter. Queries on inventory ("all devices with 7-Zip") don't exist – that needs Graph scripting. |
| Maintenance windows | Rings, active hours | Active hours are an inverted maintenance window. Deadlines and grace periods exist. |
| Task sequences | PSADT or scripts | OSD is out of scope (Autopilot). |
| Configuration baseline (report only) | Custom compliance | Can feed Conditional Access. |
| Configuration baseline (with remediation) | Custom compliance + remediation script | Remediations can run on demand; custom compliance runs every eight hours or when the user selects **Check compliance**. |
| Client settings | Mostly obsolete | Cache settings → Delivery Optimization. |
| Reporting (SSRS) | Intune reports, Graph, Power BI | The built-in reports are basic; custom reports need Graph or Power BI. |
| Server patching | Stays in Configuration Manager (or Azure Arc) | |

- Every object ends in one category: **migrate**, **replace**, **retire** or **retain** in Configuration Manager. Lab 1.1 adds **redesign** for things that need a different logic in Intune.
- Every script you build to close a gap is maintenance – plan for it to break sooner or later.
- The template `SCMI_Migration_Plan_Template.xlsx` in the [Labfiles](https://github.com/happelm/SCMI/tree/main/Labfiles), sheet **1 Assessment**, has sample values from the lab site.

Sources: [Win32 app management](https://learn.microsoft.com/intune/app-management/deployment/add-win32) · [Assignment filters](https://learn.microsoft.com/intune/fundamentals/filters/overview) · [Custom compliance settings](https://learn.microsoft.com/intune/device-security/compliance/custom-settings) · [Remediations](https://learn.microsoft.com/intune/device-management/tools/deploy-remediations)

## 7. Identities: registered, hybrid joined, Entra joined

| Join type | Use in this scenario |
|---|---|
| **Microsoft Entra registered** | Personal devices. Not a target for corporate Windows devices – and not supported for co-management. |
| **Microsoft Entra hybrid joined** | The existing fleet (CL1, CL2): AD domain member, registered in Entra ID. A bridge, not the destination. |
| **Microsoft Entra joined** | The future fleet (CL3, CL4): no computer account in AD. |

- Trainer recommendation: don't plan hybrid join as the permanent state – new features increasingly target Entra joined devices. Make the switch to Entra join with the hardware refresh. Co-management works with Entra joined devices too, so the switch doesn't have to be a hard cut.
- Before a device goes Entra joined, whatever Group Policy does for it must exist in Intune – Entra joined devices get no GPOs.
- In Entra ID, hybrid joined devices have no owner. On an Entra joined device, the user who set it up is the owner.
- **Changing the sync scope deletes objects.** A computer or user that leaves the scope is deleted in Entra ID. A hybrid joined device then falls back to on-premises only, and everything it got from Intune is gone. Plan scope changes carefully.
- Connect Sync and Cloud Sync can run side by side as long as they don't sync the same objects. That allows a gradual move: scope a part of the objects to Cloud Sync, take it out of Connect Sync, repeat ([Cloud Sync migration](https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/migrate-azure-ad-connect-to-cloud-sync)).

Sources: [Microsoft Entra hybrid joined devices](https://learn.microsoft.com/entra/identity/devices/concept-hybrid-join) · [Co-management prerequisites](https://learn.microsoft.com/intune/configmgr/comanage/overview#prerequisites)

### Single sign-on

- The user gets a **Primary Refresh Token (PRT)** – on a device that joined while the user was signed in, only after the next sign-in. With the PRT, browser and apps sign in to Microsoft 365 without a password.
- In the European Economic Area, Windows asks once whether the Windows account may sign in to other Microsoft apps ("Continue to sign in?"). Since the **July 2026** security update, administrators can accept this prompt automatically on managed devices with Entra ID accounts by a registry setting (also deployable with Intune). Learn lists Windows 11 24H2 and 25H2 ([Admin control for SSO prompts](https://learn.microsoft.com/entra/identity/devices/sso-admin-control)). Lab observation: it works on Windows 11 26H2 too.
- Entra joined devices can access on-premises resources (`\\dc1`) with the synced account – no password prompt. Lab observation: it works only from the second sign-in.
- With Windows Hello for Business or passkeys, access to on-premises resources needs **Microsoft Entra Kerberos / cloud Kerberos trust**; otherwise SSO on-premises works only with a password ([Introduction to Microsoft Entra Kerberos](https://learn.microsoft.com/entra/identity/authentication/kerberos)). Not part of this course.

### Entra joined devices and Configuration Manager

- An Entra joined device has no AD computer object: AD System Discovery doesn't find it and **OU-based collections never contain it** – `All Workstations` in the lab is OU-based. Collections that target such devices need other criteria.
- Plan the targeting before the first Entra joined device gets apps from Configuration Manager.

## 8. Tenant attach

| | Tenant attach | Co-management |
|---|---|---|
| What happens | Configuration Manager uploads its devices to the Intune admin center | The device also enrolls in Intune (MDM) |
| Intune enrollment | No – MDM in Entra ID stays **None** | Yes – MDM shows Configuration Manager / co-managed |
| Who manages | Configuration Manager only | Per workload: Configuration Manager or Intune |
| Lab | CL2 | CL1 |

- Only devices with a Configuration Manager client are uploaded. You can limit the upload to one collection.
- **Purpose:** one view for the first-level helpdesk: client details, timeline, Resource Explorer, machine and user policy, app evaluation cycle, CMPivot, run scripts, install or uninstall apps that are deployed to the device. It doesn't replace the Configuration Manager console for second-level work.
- **Endpoint security** policies (antivirus, firewall, attack surface reduction) can be created in Intune for tenant attached devices – the platform shows "(ConfigMgr)", and Configuration Manager applies them.
- Communication is outbound only, through the service connection point – no inbound firewall rules.
- **Prerequisites:** a Global Administrator for the onboarding (the wizard creates an app registration), an Intune license for the admin account – without it sign-in fails with "An unanticipated error occurred" – and a working administration service. No Azure subscription and **no cloud management gateway** needed: co-management itself doesn't require a CMG, only internet-based clients do.
- **Permissions:** clear **Enforce Configuration Manager RBAC for cloud console requests** in the wizard and set **Use Intune RBAC** in Intune → Tenant administration → Connectors and tokens → Microsoft Endpoint Configuration Manager. Otherwise the admin needs a matching (non-synced) account in Configuration Manager RBAC (trainer recommendation: use Intune RBAC).
- **Logs** on the site server: `CMGatewaySyncUploadWorker.log` (upload) and `CMGatewayNotificationWorker.log` (actions from the admin center). The "CMGateway" names have nothing to do with the cloud management gateway.
- The first upload runs on a schedule – the log shows the next run time. Wait for it.

Sources: [Tenant attach prerequisites](https://learn.microsoft.com/intune/configmgr/tenant-attach/prerequisites) · [Device sync and device actions](https://learn.microsoft.com/intune/configmgr/tenant-attach/device-sync-actions) · [Troubleshoot tenant attach](https://learn.microsoft.com/intune/configmgr/tenant-attach/troubleshoot)

## 9. Co-management

### Prerequisites

1. Hybrid identity – a device that isn't hybrid joined can't be co-managed
2. Configuration Manager client on the device
3. MDM user scope (automatic enrollment)
4. An Intune license for the **user** – the license is per user, not per device

### Automatic enrollment

| Setting (Cloud Attach → Enablement) | Effect |
|---|---|
| **None** | No device enrolls in Intune |
| **Pilot** | Only members of the pilot collection enroll (lab: `Pilot-CoMgmt` with CL1) |
| **All** | All eligible Configuration Manager clients enroll |

Flow: the client gets the co-management settings with the machine policy, triggers the MDM enrollment, appears in Intune as co-managed, and applies the workload authority. `CoManagementHandler.log` on the client shows each step.

### Workloads

- Workloads: compliance policies, device configuration, endpoint protection, Windows Update policies, Office Click-to-Run apps, client apps and resource access policies. Resource access is no longer supported in Configuration Manager since 2203, and since 2403 its slider is fixed on Intune – that's why it is already on the right. Switching device configuration also moves resource access and endpoint protection.
- A slider decides **who is in charge** of a workload: Configuration Manager, Pilot Intune (only the pilot collection on the **Staging** tab) or Intune.
- A slider **doesn't** create Intune policies, doesn't copy Configuration Manager settings and doesn't remove anything Configuration Manager already put on the device.
- Rollback: make the pilot collection smaller or move the slider back. Not everything rolls back – Windows and Office versions that Intune installed stay at the later version. With **Pilot Intune** for endpoint protection and device configuration, Intune doesn't remove a policy when you unassign it; that needs the slider on **Intune**.
- **Client apps** are the exception: even with the slider on Intune, the device still gets Configuration Manager apps. Apps can come from both sides.
- Proof is on the device, not in the console: Configuration Manager control panel → General → **Co-management capabilities** is a bitmask. 8197 = no workload moved; CL1 with compliance policies on Pilot Intune shows 8199.

### What you see after enrollment

- For a while CL1 shows up twice in Intune: once from tenant attach, once from the enrollment. The records merge after some minutes.
- After the merge, the Configuration Manager pages of the device disappear from the Intune admin center and come back after about 12 to 18 hours (lab observation). That's the overnight task in Lab 4.2.

### Primary user

- Intune: the primary user is a static assignment (by default the user who enrolled), changeable in the device properties. Configuration Manager calculates user device affinity from usage data with configurable thresholds.
- Removing the primary user makes the device a **shared device**. The Company Portal can still install available apps there, but device actions like reset, rename or retire and uninstalling apps aren't available.

Sources: [Co-management overview](https://learn.microsoft.com/intune/configmgr/comanage/overview) · [Co-management workloads](https://learn.microsoft.com/intune/configmgr/comanage/workloads) · [Change a device's primary user](https://learn.microsoft.com/intune/device-management/inventory-and-status/find-primary-user) · [User device affinity in Configuration Manager](https://learn.microsoft.com/intune/configmgr/apps/deploy-use/link-users-and-devices-with-user-device-affinity)

## 10. The Configuration Manager client on Entra joined devices

- No client push and no AD discovery for Entra joined devices. The client authenticates with a **Microsoft Entra token** instead.
- What it takes in the lab:
  - Site in **Enhanced HTTP** (no PKI needed).
  - **Azure Services → Cloud Management** in the Configuration Manager console: the wizard creates a server app and a client app in Entra ID. Give them names you'll recognize later; the server app's secret expires and must be renewed.
  - The site's **SMS Issuing** root certificate (the valid one with the longest lifetime) deployed to the devices with an Intune trusted certificate profile – the device has no domain trust. Make sure it arrived before the client installs.
  - `/NoCRLCheck` in the command line – an Enhanced HTTP certificate has no revocation list.
  - Tenant ID, client app ID (`AADCLIENTAPPID`) and the server app's Application ID URI (`AADRESOURCEURI`) in `CCMSETUPCMD`. Replace the placeholders completely, including the angle brackets.
- Three ways to install the client from Intune:
  1. **Line-of-business app** with `ccmsetup.msi` from `<install dir>\bin\i386` – the documented way, used in the lab.
  2. Win32 app – only if you need retries or dependencies.
  3. Co-management settings in Intune – for Windows Autopilot; the client content comes from a cloud management gateway.
- With a CMG, the console shows the finished command line on the Cloud Attach → Enablement tab. Without one, you build it yourself.
- Intune limits the command line to 1,024 characters.
- Lab observations: refreshing the browser during the LOB upload cancels it without a warning. The trusted certificate profile shows "Windows 8.1 and later" as platform – that's normal.

Sources: [Install clients using Microsoft Entra ID](https://learn.microsoft.com/intune/configmgr/core/clients/deploy/deploy-clients-cmg-azure) · [Client installation properties](https://learn.microsoft.com/intune/configmgr/core/clients/deploy/about-client-installation-properties) · [Deploy clients to Intune MDM-managed devices](https://learn.microsoft.com/intune/configmgr/core/clients/deploy/deploy-clients-to-windows-computers#intune-mdm-managed-windows-devices) · [Prepare internet-based devices for co-management](https://learn.microsoft.com/intune/configmgr/comanage/how-to-prepare-win10#install-the-configuration-manager-client)

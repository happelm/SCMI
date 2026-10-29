---
title: 'Day 3 notes – Deliver, clean up, operate'
---

# Day 3 notes – Deliver, clean up, operate

> Summary of what was covered on Day 3, with sources – not a transcript. Recommendations marked "trainer recommendation" are field experience, not Microsoft documentation. "Lab observation" means the trainer saw it in the lab environment; it isn't documented by Microsoft. Community tools are named as such.

## Key takeaways

- Intune has no repair action for a required app. The most stable lever is the detection rule: a company marker in the registry, plus a remediation that runs on demand and removes it (Lab 10.3). It's a trainer method, not a supported Microsoft procedure.
- Patching without a software update point means no approval, no WSUS, no catalog sync. Update rings set deferral, deadline and restart behavior; a feature update policy pins the Windows version. Moving the Windows Update slider is only half of the switch – the Configuration Manager software update client setting has to follow.
- Delivery Optimization replaces distribution points and BITS throttling – for Windows updates and for Win32 apps. Microsoft Connected Cache adds a dedicated cache, on a distribution point or standalone.
- Most daily Configuration Manager actions have an Intune counterpart. The differences are in the details: device query on multiple devices reads cached inventory, Remote Help now also works unattended, Collect diagnostics replaces the trip to the device.
- There's no in-place path from hybrid joined to Entra joined. The supported way is a reset – with a new user profile, and with old records in AD, Entra ID, Configuration Manager and Intune that you clean up yourself.
- Most migration steps can be rolled back (sliders, groups, assignments). The identity change of a device can't. Define rollback criteria and an end of the project before you start.

## 1. Morning: tenant attach upload and AI-assisted packaging

- The upload scope of tenant attach (Cloud Attach properties → Upload) decides which devices show Configuration Manager data and actions in the Intune admin center. Devices outside the upload collection – here CL3 and CL4 until Lab 4.2 – have no Configuration Manager node, even when the client is installed.
- Lab 10.2 with Microsoft 365 Copilot Chat: in the default quick response mode Copilot returned only the changed parts of the PSADT template instead of the complete script, and ignored the instruction to return it in full. With **Think Deeper** it returned the complete script (lab observation). Check the length of the result before you package it – a script of half the expected size is incomplete. The lab now also loads the Configuration Manager cmdlets in the same PowerShell session and uses full paths.
- Trainer recommendation: for an AI-assisted lab, keep a tested fallback file in the Labfiles folder. Results of a language model aren't reproducible from run to run.

## 2. Repair a required app (Lab 10.3)

- For a required app, **Reinstall** in the Company Portal can't be used while detection is positive, and there's no repair action in Intune. Changing the assignment to available, or adding a second available assignment of the same app, isn't a production answer (trainer recommendation).
- The pattern: the PSADT package writes a marker key at the end of the Post-Install phase (`HKLM\SOFTWARE\SmartETC\Apps\<AppName>` with Version and InstallDate) and removes it in Post-Uninstall. The detection rule checks the marker. A remediation without assignment, run on demand from the device page, removes the marker – the app counts as not installed and Intune runs the install command again.
- `-SkipMSIAlreadyInstalledCheck` on `Start-ADTMsiProcess` makes the install phase repeatable. Without it PSADT sees the MSI as installed and skips the installation. The Firefox ESR MSI doesn't support a Windows Installer repair, so the package installs over the existing version.
- A consistent marker per app (company key, one subkey per app name, optionally the version) is easier to maintain than a different file or registry check per app (trainer recommendation). An app that updates itself makes the version in the marker stale – it's a tag, not an inventory.
- The remediation also deletes the GRS keys under `HKLM\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps` and the `LastFullReportTimeUtc` value under `...\Win32Apps\Reporting`, and restarts the Intune Management Extension with a delay. Without the GRS keys detection runs at the next check-in; without the reporting value the next status report is a full one. The restart is delayed because the remediation runs inside the IME – restarting it at once loses the result of the script. The registry layout is undocumented and has changed before, so the method can break with an IME update.
- Lab observation: a registry detection rule with a file path in the key field doesn't count as "not detected" – detection fails with an error and Intune doesn't install the app at all.
- Replacing the package file of an existing Win32 app (Properties → App information → App package file) works and saves rebuilding the app. Trainer recommendation: in production create a new app and supersede the old one instead, so that reporting still tells you which version is where.
- Timing: the IME checks for new Win32 app assignments every hour and after a service or device restart. After a restart the IME log shows a randomized delay before the PowerShell and Win32 app workloads check in (lab observation: 70 to 165 seconds). Since service release 2609 Intune uses push notifications for admin-initiated changes to Win32 apps.

Sources: [Win32 app management](https://learn.microsoft.com/intune/app-management/deployment/win32#prerequisites) · [What's new in Intune – Faster delivery of Win32 apps (2609)](https://learn.microsoft.com/intune/whats-new/#week-of-september-28,-2026-service-release-2609) · [Run remediation on demand](https://learn.microsoft.com/intune/device-management/actions/run-remediation)

## 3. Windows updates without a software update point

| Configuration Manager | Intune |
|---|---|
| Software update point, WSUS, catalog sync, approval | Windows Update client policies – the device gets updates from Windows Update |
| Automatic deployment rules | Update rings with deferral periods |
| Maintenance windows | Active hours, restart settings and deadlines – or the new Windows maintenance window policies (below) |
| Upgrade task sequence, servicing plans | Feature update policy that pins a version |
| Software update reports | Windows Update reports in Intune |

- **Rings:** small inner rings with short deferral, large outer rings with longer deferral. A problem shows up in the small ring first. Quality update deferral is 0 to 30 days.
- **Feature updates:** pin the version with a feature update policy (Lab 11.1: Windows 11, version 26H2). Set the feature update deferral in the update ring to 0 when you use a feature update policy. The device stays on the pinned version until you change the policy. Requirements: Pro, Enterprise or Education edition, Entra joined or hybrid joined (registered isn't enough), telemetry at least *Required*, the service *Microsoft Account Sign-In Assistant* (`wlidsvc`) not disabled, and a license with the Windows Autopatch entitlement.
- **Deadlines (Windows 11, version 22H2 and later):** the deadline counts from the time the device discovered the update in a scan, not from the release date. The grace period counts from the pending restart. The effective deadline is the later of the two. Before it, users can schedule the restart and Windows restarts outside active hours (**Auto reboot before deadline** = Yes). After it, the restart is forced regardless of active hours. In the ring settings the deadline is 2 to 30 days and the grace period 0 to 7 days. Because the grace period starts only at the pending restart, a device that comes back after a longer time switched off isn't restarted at once – Microsoft names users back from vacation as the reason.
- **Automatic update behavior** with deadlines: the deadline ignores the download, install and restart settings of *Configure Automatic Updates*. Since the December 10, 2024 update for Windows 11, version 22H2 and later, these settings are respected before the deadline and ignored after it.
- **Maintenance windows:** since the January 2026 non-security update, Windows 11, version 24H2 and later has native maintenance window policies (Update CSP `MaintenanceWindow*`, Group Policy). Microsoft names user-less and critical-use devices – kiosks, medical and manufacturing equipment – as the target. Use either maintenance windows or deadlines, not both: an expired deadline still wins.
- **Expedite:** a quality update policy can expedite a specific security update; the restart is enforced after 0 to 2 days.
- **Hotpatch:** monthly security updates that install without a restart. Baseline months with a restart are January, April, July and October; in the other eight months hotpatches apply. Requirements: Windows 11, version 24H2 or later, an x64 CPU, virtualization-based security on, the current baseline, and an eligible license – Windows Enterprise E3/E5, Microsoft 365 F3, Education A3/A5, Microsoft 365 Business Premium or Windows 365 Enterprise. Microsoft can release an extra baseline with a restart outside the quarter for security reasons. Since the May 2026 security update hotpatch is on by default for eligible devices in Windows Autopatch.
- **Windows Autopatch** builds on rings and policies and automates the ring assignment. Licenses: Microsoft 365 Business Premium, Windows Enterprise E3/E5 (also in Microsoft 365 F3, E3, E5), Education A3/A5, VDA E3/E5. Support requests to the Autopatch team are E3+ and F3 only.
- **Drivers and firmware** come through Windows Update; Autopatch and driver update policies can approve or hold them. Trainer observation: with current Dell, HP and Lenovo business hardware, a clean Windows installation enrolled in Intune had all drivers after a few hours.
- **Group Policy:** remove Windows Update GPOs from hybrid joined devices, or they conflict with the rings. The workload slider doesn't touch GPOs. The same model applies to Microsoft 365 Apps updates.
- **Co-management:** after moving the Windows Update policies workload to Intune, adjust the Configuration Manager client settings manually – a custom client setting that disables software updates for the moved collection (Lab 11.1). Microsoft notes that the Configuration Manager client keeps delivering third-party updates while Software Updates = Yes; set it to No when Configuration Manager has to be out of the update path entirely, for example for Windows Autopatch.

Sources: [Update rings policy settings](https://learn.microsoft.com/intune/device-updates/windows/ref-update-ring-settings#user-experience-settings) · [Enforce compliance deadlines and maintenance windows](https://learn.microsoft.com/windows/deployment/update/wufb-compliancedeadlines) · [Manage Windows feature updates](https://learn.microsoft.com/intune/device-updates/windows/manage-feature-updates#prerequisites) · [Expedite policies for quality updates](https://learn.microsoft.com/intune/device-updates/windows/configure-expedite-policy) · [Hotpatch updates](https://learn.microsoft.com/windows/deployment/windows-autopatch/manage/windows-autopatch-hotpatch-updates) · [What's new – hotpatch on by default (2603)](https://learn.microsoft.com/intune/whats-new/#week-of-march-30,-2026-service-release-2603) · [Windows Autopatch prerequisites](https://learn.microsoft.com/windows/deployment/windows-autopatch/prepare/windows-autopatch-prerequisites#licenses-and-entitlements) · [Co-management workloads – Windows Update policies](https://learn.microsoft.com/intune/configmgr/comanage/workloads#windows-update-policies) · [Integrate Windows Update client policies with Configuration Manager](https://learn.microsoft.com/intune/configmgr/sum/deploy-use/integrate-windows-update-client-policies#co-management-with-microsoft-intune)

## 4. Content delivery: Delivery Optimization and Connected Cache

- Content comes from the Microsoft content delivery network. Delivery Optimization (DO) lets devices share pieces of it peer to peer. It's used for Windows updates and also for Intune Win32 apps.
- Plan DO with the network team: peer groups, bandwidth limits and cache size have to match the topology (trainer recommendation).
- **Download mode:** the default is LAN (1). Group (2) lets devices share across subnets within a group. The group ID can come from the AD site, the authenticated domain SID, a DHCP option, the DNS suffix or the Entra tenant ID. Lab 11.1 uses the DNS suffix.
- **Bandwidth:** DO limits are in KB/s or in percent; Configuration Manager BITS limits are in Kbps. Lab 11.1 rebuilds the BITS client setting of the branch with an absolute maximum and percentages for business hours.
- **Cache:** the default maximum cache age is 3 days (259,200 seconds); Intune configures it in days. The default cache size is 20 % of the available disk space. There's no Configuration Manager client cache for Intune content – Win32 app content is removed after the installation.
- **Check on the client:** `Get-DOConfig -Verbose` for the active values, `Get-DeliveryOptimizationStatus` for running downloads and the share that came from peers.
- **Microsoft Connected Cache:** a dedicated cache for DO content, useful where peers are rare or come and go (laptops, small branches).
  - On a Configuration Manager distribution point: a checkbox in the DP properties. Requires an on-premises DP without other site roles, and Windows Enterprise E3/E5 or Education A3/A5 licenses for the devices that use it. It serves cloud-managed content (Windows Update client policies, Microsoft 365 Apps, Win32 apps for co-managed devices), not Configuration Manager software update deployments.
  - Standalone: Microsoft Connected Cache for Enterprise and Education (GA), for environments without distribution points. Hosts: Windows 11 or Windows Server 2022 and later (through WSL) or Ubuntu 24.04. Managed in the Azure portal; an Azure pay-as-you-go subscription is needed, the resources aren't charged.
  - A variant for internet service providers is in preview.

Sources: [Delivery Optimization reference](https://learn.microsoft.com/windows/deployment/do/waas-delivery-optimization-reference#delivery-optimization-options) · [What is Microsoft Connected Cache?](https://learn.microsoft.com/windows/deployment/do/waas-microsoft-connected-cache) · [Connected Cache with Configuration Manager](https://learn.microsoft.com/intune/configmgr/core/plan-design/hierarchy/microsoft-connected-cache#prerequisites-and-limitations) · [Connected Cache FAQ](https://learn.microsoft.com/windows/deployment/do/mcc-ent-faq)

## 5. Daily operations: Configuration Manager actions in Intune

| Configuration Manager | Intune |
|---|---|
| Client notification | Sync (starts an MDM and an IME check-in) |
| Scripts, configuration items | Remediations, platform scripts |
| CMPivot | Device query |
| Remote control | Remote Help (attended and unattended) |
| Collecting logs on the device | Collect diagnostics |
| BitLocker management (MBAM) | BitLocker policy, encryption report, key rotation |
| OSD task sequences | Windows Autopilot |

- **Device query:** on a single device it queries the device in real time. Device query for multiple devices (Devices → Device query) reads collected inventory, not the device – it shows nothing until a properties catalog policy collects the data on Windows. Device query is part of Advanced Analytics, an Intune advanced capability – included in Microsoft 365 E3 and E5 since July 2026 (see Day 2 notes). The query language is KQL. The properties catalog can also collect registry values from `HKEY_LOCAL_MACHINE` (single value, all values under a key, or one value across subkeys; at most 100 keys per device).
- **Remote Help unattended:** a helper signs in to a corporate Windows device with their own credentials, without a user present. Requirements: physical, corporate-owned, Intune-managed x64 device, Entra joined or hybrid joined, Azure Virtual Desktop agent and bootloader installed, Remote Desktop enabled, IME installed, and the permission *Remote Help app – Windows unattended control remote sign-in* (not in the built-in Help Desk Operator role). Lab observation: unattended control worked on the lab VMs, although Microsoft lists physical devices only.
- **Collect diagnostics:** Devices → device → Collect diagnostics; download it from Monitor → Device diagnostics → … → Download. It collects command output (`ipconfig /all`, `dsregcmd /status`, `msinfo32`, `certutil`, firewall and proxy settings, battery and energy report), registry keys, event logs, the IME logs and the Configuration Manager client logs. The MDM logs are in `mdmlogs-<date>.cab` inside the zip – extract the cab to get `MDMDiagHtmlReport.html`, the same report as Settings → Accounts → Access work or school → Export your management log files. A collection is kept for 28 days, up to 10 per device. For app installation problems the Win32 app installation details offer Collect diagnostics with up to 25 file paths of your own (.log, .txt, .dmp, .cab, .zip, .xml, .evtx, .evtl); the collection takes about 15 to 20 minutes.
- **BitLocker:** CL3 and CL4 (Entra joined) were encrypted without any BitLocker policy, the recovery key is in Entra ID; CL1 (hybrid joined) wasn't, although the encryption report showed it as ready (lab observation). Windows device encryption finishes only after the recovery key is backed up – to Entra ID for Entra joined devices, to AD DS for domain joined devices when the recovery policy allows it. Since Windows 11, version 24H2 more devices qualify. The report: Devices → Monitor → Encryption report.
- **Edition:** subscription activation steps Windows Pro up to Enterprise when a user with a Windows Enterprise E3/E5 license signs in to an Entra joined or hybrid joined device – no KMS, no MAK, no image change. The device renews the license about every 30 days and falls back to Pro when the subscription expires. One user license covers up to five devices.

Sources: [Device query for multiple devices](https://learn.microsoft.com/intune/advanced-analytics/device-query-multiple-devices) · [Properties catalog – registry key inventory](https://learn.microsoft.com/intune/device-configuration/collect-device-properties#feature-details-and-usage) · [Planning for Remote Help](https://learn.microsoft.com/intune/remote-help/plan#requirements-and-prerequisites) · [Collect diagnostics](https://learn.microsoft.com/intune/device-management/actions/collect-diagnostics) · [Win32 app troubleshooting – collect diagnostic file](https://learn.microsoft.com/troubleshoot/mem/intune/app-management/troubleshoot-win32-app-install#collect-diagnostic-file) · [BitLocker device encryption](https://learn.microsoft.com/windows/security/operating-system-security/data-protection/bitlocker/#device-encryption) · [Windows subscription activation](https://learn.microsoft.com/windows/deployment/windows-subscription-activation)

## 6. Reset actions

| Action | What it does | Enrollment afterwards |
|---|---|---|
| **Wipe** | Factory reset, removes user data, settings and MDM policies | Device leaves Intune; with Autopilot it goes through Autopilot again |
| Wipe – keep enrollment state and user account | Reset with Windows "keep my files" | Device stays enrolled |
| Wipe – continue even if the device loses power | Reset, overwrites free space; can leave some devices unbootable – for lost or stolen corporate devices | Device leaves Intune |
| **Fresh Start** | Reinstalls the latest Windows and removes preinstalled (OEM) apps | With *Retain user data*: stays Entra joined and re-enrolls at the next sign-in; without it: OOBE completed, BYOD devices leave Entra ID and Intune |
| **Autopilot Reset** | Removes personal files, apps and settings, reapplies the original configuration | Stays Entra joined and enrolled; Entra joined devices only, not hybrid joined |
| **Retire** | Removes company data, apps and settings deployed by Intune, keeps personal data – meant for personal and mobile devices | Unenrolls. For Entra joined Windows devices the admin center marks it as not supported: the device leaves Entra ID and users can't sign in with their Entra account anymore |

- Wipe, Fresh Start and Autopilot Reset use the Windows reset ("Reset this PC") remotely and need a working Windows Recovery Environment. Removing WinRE or the recovery partition breaks them; for Autopilot Reset Microsoft documents `reagentc.exe /enable`.
- Autopilot Reset is meant for a new user in the same organization. Trainer observation: most organizations wipe instead – a few minutes slower, but nothing of the previous user stays.
- Before a retire or delete of a BitLocker-protected Entra joined device, back up the recovery key and the local admin credentials: Intune removes the key protectors and leaves BitLocker suspended.

Sources: [Wipe](https://learn.microsoft.com/intune/device-management/actions/wipe#how-to-wipe-a-device-from-the-intune-admin-center) · [Fresh Start](https://learn.microsoft.com/intune/device-management/actions/fresh-start#how-to-run-fresh-start-from-the-intune-admin-center) · [Autopilot Reset](https://learn.microsoft.com/autopilot/windows-autopilot-reset) · [Retire](https://learn.microsoft.com/intune/device-management/actions/retire#user-experience)

## 7. From hybrid joined to cloud-only (Lab 12.2)

- There's no tool or command that turns a hybrid joined device into an Entra joined device. A manual unjoin and Entra join is possible, but the user gets a new profile. The supported way is a reset with Windows Autopilot – for an existing device, or with new hardware. A Configuration Manager task sequence can automate the reset into Autopilot (*Windows Autopilot for existing devices*).
- Trainer recommendation: in most projects the identity change comes with the hardware refresh; resetting devices in use is the exception.
- **Reset checklist:** user data (OneDrive Known Folder Move, Windows Backup for settings), apps available from Intune, policies ready in Intune, BitLocker recovery key or BitLocker suspended if data on the disk must survive, and the old records in AD, Entra ID, Configuration Manager and Intune.
- **Replace** in Intune terms: apps from Intune, settings from Windows Backup, data from OneDrive. There's no USMT.
- Lab observation: a cloned lab VM had been registered in Windows Autopilot of another tenant in an earlier course. After the reset OOBE picked up that tenant's profile, and starting without a network no longer got past OOBE on 26H2. A new BIOS serial number and BIOS GUID (Labfiles `Set-HyperVBiosIdentity.ps1`, run on the Hyper-V host with the VM switched off) give the VM a new hardware hash that Autopilot doesn't know.
- After the reset CL2 appears twice in Entra ID (old hybrid joined, new Entra joined) and twice in Intune (the tenant attach record and the new enrolled device). They don't merge – the old records have to be removed (Lab 13.1). Static group memberships don't carry over to the new device object; dynamic groups evaluate it again.

Sources: [Windows Autopilot Reset – hybrid joined devices](https://learn.microsoft.com/autopilot/windows-autopilot-reset) · [Windows Autopilot for existing devices](https://learn.microsoft.com/autopilot/tutorial/existing-devices/existing-devices-workflow)

## 8. Rollback and clean sweep (Lab 13.1)

- **Reversible:** workload sliders, pilot collections, co-management itself, policy and app assignments, group memberships. **One way:** the identity change of a device (hybrid → Entra joined) and a reset or deletion. An application that needs a domain controller can't go back once the device is Entra joined – find such apps before the wave.
- Mixed is fine – per device, not on the same device: CL1/CL2 hybrid, CL3/CL4 Entra joined, and all policies and apps work on both.
- **Rolling back a workload:** apps installed by Intune stay installed. Settings written by Intune can stay on the device until Configuration Manager overwrites them. When you move Windows Update back to Configuration Manager, enable the software update client setting again – and the Intune-authored Windows Update state under the MDM PolicyManager isn't removed automatically; unassign the device from the Intune ring first.
- One device with a problem: take it out of the pilot collection. A whole wave with a problem: stop the wave and find the cause. A problem that also occurs with Configuration Manager isn't solved by a rollback (trainer recommendation).
- Rollback criteria are risk management: likelihood × impact gives a score, the highest score gets attention first. Define the end of the project – for example all workloads in Intune, no Configuration Manager client, one record per device, GPOs unlinked. The end state is your decision, not Microsoft's; it doesn't have to be "Configuration Manager switched off".
- **Remove the client:** `ccmsetup.exe /uninstall`, log in `C:\Windows\ccmsetup\Logs\ccmsetup.log`. Since version 2111 it also removes the `ccmsetup.msi` bootstrap – so first remove the device from the group of the Intune app that installs the client, or the app installs it again.
  - As a platform script it runs once per device. Platform scripts run through the IME (`AgentExecutor.log`, remediations in `HealthScripts.log`). The IME checks for new scripts after every reboot; in the lab, restarting the IME service brought the run forward (lab observation).
  - Leftovers stay: the company marker keys, settings written by baselines or remediations, scheduled tasks. Decide which ones you keep.
- **Records:** delete the old Configuration Manager records. The tenant attach record in Intune goes away with the Configuration Manager record, not by deleting it in Intune. In AD, disable the computer object and move it out of the sync scope – Cloud Sync then deletes the device in Entra ID at its next cycle.
- **Entra ID has no automatic cleanup.** Use the activity timestamp (`ApproximateLastSignInDateTime`) and the stale devices view, and script the cleanup with Microsoft Graph PowerShell: disable, wait, then delete. Back up BitLocker keys first.
- **Device soft delete (preview, since May 2026):** a deleted Entra device object is kept for 30 days with its BitLocker recovery keys and LAPS password and can be restored. Supported for Entra joined, hybrid joined and registered devices. Microsoft documents both a portal path (Entra ID → Devices → Deleted devices) and, for the preview, restore through Microsoft Graph or PowerShell only.
- **Intune device cleanup rules** hide devices that haven't checked in for 30 to 270 days. They trigger no action on the device and don't remove the Entra object.
- **Decommissioning the site** comes last: all workloads and apps in Intune, clients removed, tenant attach and co-management switched off from the Configuration Manager side, then the app registrations, service accounts, SQL, distribution points and the System Management container. The AD schema extensions stay.

Sources: [Uninstall the Configuration Manager client](https://learn.microsoft.com/intune/configmgr/core/clients/manage/manage-clients#uninstall-the-client) · [PowerShell scripts on Windows devices](https://learn.microsoft.com/intune/device-management/tools/run-powershell-scripts-windows) · [Cloud Sync – recover a deleted device](https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/device-sync#recover-a-deleted-device) · [Manage stale devices](https://learn.microsoft.com/entra/identity/devices/manage-stale-devices) · [Device soft delete (preview)](https://learn.microsoft.com/entra/identity/devices/concept-soft-delete-devices) · [Device cleanup rules](https://learn.microsoft.com/intune/governance/configure-cleanup-rules)

## 9. Your migration plan (Lab 15.1)

- The workbook `SCMI_Migration_Plan_Template.xlsx` in the Labfiles folder follows the course: assessment, target state per device population (join type today and target, path), workload authority and what stays in Configuration Manager (for example server patching), waves with scope, staging collection, owner, go and rollback criteria, risks with likelihood × impact, six phases with exit criteria, and app tracking per deployment type.
- End state of the lab: CL1 hybrid joined and co-managed, with compliance, endpoint protection, device configuration and Windows Update on Intune, apps still from Configuration Manager. CL2 reset and Entra joined, Intune only. CL3 Entra joined with the Configuration Manager client. CL4 Intune only, client removed.

## 10. Staying current and reporting

- **What's new in Intune** (weekly, larger service releases monthly) is the most reliable source – features often appear there without an earlier announcement. **In development** and the **Microsoft 365 roadmap** (filter on Intune) show plans without dates. Trainer recommendation: read What's new every one or two weeks.
- **Audit logs** show every change in Intune with old and new values. For longer retention and analysis send them with Reports → Diagnostics settings to a Log Analytics workspace (needs an Azure subscription) and query them with KQL.
- **Intune Data Warehouse:** historical Intune data, refreshed daily, as an OData feed (Reports → Intune Data warehouse) for Power BI or any OData client. Fact tables typically hold 30 days. Reading needs the Reports permission in Intune. Co-managed data from Configuration Manager isn't in it.
- **Log viewers:** OneTrace comes with Support Center (`cd.latest\SMSSETUP\Tools\SupportCenter\SupportCenterInstaller.msi` on the site server). [cmtrace.dev](https://cmtrace.dev) is a browser-based viewer for CMTrace-format logs (community tool by Florian Salzmann): no installation, the file is read locally in the browser.
- The link collection for this course is under **Resources** at the bottom of the lab guide.

Sources: [What's new in Microsoft Intune](https://learn.microsoft.com/intune/whats-new/) · [Send Intune log data to Azure Monitor](https://learn.microsoft.com/intune/governance/integrate-azure-monitor#send-logs-to-azure-monitor) · [Connect to the Data Warehouse with Power BI](https://learn.microsoft.com/intune/developer/data-warehouse/connect-power-bi#load-the-data-in-power-bi-using-the-odata-link) · [Data Warehouse data model](https://learn.microsoft.com/intune/developer/data-warehouse/ref-data-model) · [Support Center OneTrace](https://learn.microsoft.com/intune/configmgr/core/support/support-center-onetrace)

---
title: 'Appendix'
lab:
    title: 'Appendix'
    module: 'Appendix'
---

# Appendix

## Fast track – Intune for ConfigMgr admins

New to Intune? These three tables cover what the labs assume: where things are in the portal, what assignments do, and when a device picks up a change.

### Portal map

Intune admin center: `https://intune.microsoft.com`

| You look for | Intune admin center | ConfigMgr counterpart |
|---|---|---|
| A device and everything assigned to it | Devices → All devices → device | Assets and Compliance → Devices |
| Apps | Apps → All apps (Windows: Apps → Windows) | Software Library → Applications |
| Settings | Devices → Configuration (settings catalog) | Client settings, baselines, GPO |
| Compliance | Devices → Compliance | Configuration baselines (compliance part) |
| Scripts and remediations | Devices → Scripts and remediations | Scripts, baselines with remediation |
| Windows updates | Devices → Windows updates | Software Updates, ADRs |
| Enrollment, Autopilot | Devices → Device onboarding → Enrollment | Client push, OSD |
| Security settings (AV, firewall, BitLocker, LAPS) | Endpoint security | Endpoint Protection |
| Groups | Groups (Microsoft Entra ID) | Collections |
| Roles, scope tags, connectors | Tenant administration | Administration → Security, Hierarchy |
| Reports | Reports, and per object: Device status | Monitoring, Reporting |

### From ConfigMgr terms to Intune terms

| ConfigMgr | Intune | Difference to keep in mind |
|---|---|---|
| Collection | Microsoft Entra group, optionally with an assignment filter | No limiting collection. Filters narrow an assignment by device properties at check-in. |
| Application, deployment type | App (Win32 `.intunewin`), detection rule, requirement rule | One deployment type per app. Dependencies and supersedence exist. |
| Deployment Required / Available | Assignment Required / Available / Uninstall | Available needs a user (Company Portal). |
| Configuration baseline | Settings catalog profile, compliance policy, remediation | Configuration sets, compliance checks, remediation fixes – three objects instead of one. |
| Client agent `CcmExec` | Windows MDM client plus Intune Management Extension (IME) | MDM handles settings, the IME handles Win32 apps, scripts and remediations. |
| Machine Policy Retrieval (default 60 min) | MDM sync (about every 8 h) plus push notifications | See sync cycles below. |
| Maintenance window | Update ring deadlines, active hours, restart settings | No general maintenance window. |
| Security role, security scope | Intune role, scope tag | Scope tags filter what an admin sees. |

### Assignments

- **Targets are Entra groups** – user groups or device groups, each with **Include** and **Exclude**. Do not mix: include users and exclude devices (or the reverse) gives results you do not expect. Keep include and exclude of the same type.
- **Assignment filters** narrow an assignment by device properties (OS, model, ownership, enrollment profile). They are evaluated at check-in and do not wait for group processing – faster and more predictable than dynamic device groups.
- **Dynamic groups take time.** After enrollment, the device has to land in the group first. Until then, nothing assigned to that group arrives.
- **User or device?** User-assigned settings follow the user to every device. Device-assigned settings apply regardless of who signs in.
- **Conflicts** are resolved per setting, not per policy: compliance settings win over configuration settings; two configuration profiles with different values for the same setting show **Conflict** and neither value is applied reliably.

### Sync cycles (Windows)

| Event | When the device checks in |
|---|---|
| New enrollment | Every 3 minutes for 15 minutes, every 15 minutes for 2 hours, then about every 8 hours |
| Maintenance sync | About every 8 hours, at most once every 6.5 hours |
| Change in Intune (assignment, policy, group membership) | Push notification to online devices – immediately up to a few hours. Adding an app as *Available* sends no notification. |
| Win32 apps, scripts, remediations | Separate IME check-in, about every 8 hours, and after every IME or device restart. Platform scripts run once; a failed script is retried at the next three IME check-ins. |

Do not wait – trigger a sync:

- Intune admin center → Devices → device → **Sync** (MDM sync)
- On the device: Settings → Accounts → Access work or school → account → **Info** → **Sync** (MDM sync)
- Company Portal → Settings → **Sync** (MDM sync and IME check-in)
- Elevated PowerShell: `Restart-Service -Name IntuneManagementExtension` (IME check-in)

Reports in the portal lag behind the device. When the portal and the log disagree, the log is right.

## Deliberate dirt – do not fix

| Object | Purpose |
|---|---|
| SmartETC Toolbox deployed to Dept-Sales | Detection points to the wrong folder – failed deployment visible via tenant attach |
| Adobe Reader 2019 | Distributed, never deployed – dead content |
| 7Zip | Duplicate application without deployment type |
| TEST_alt_Kopie, Neue Sammlung (2), Win10 Upgrade Wave 3 - DONE | Empty or meaningless collections |
| Finance Laptops, All Laptops | Empty on VMs – limiting chain and chassis query |

## Log map

| Question | Where to look |
|---|---|
| Join state, PRT | `dsregcmd /status` |
| Hybrid join chain | Event Viewer → Microsoft → Windows → User Device Registration → Admin |
| MDM enrollment and policy errors | Event Viewer → DeviceManagement-Enterprise-Diagnostics-Provider → Admin |
| Co-management state | `CoManagementHandler.log`, `ConfigInfo` registry value |
| Cloud-first client registration | `ccmsetup.log`, `ClientIDManagerStartup.log`, `LocationServices.log` |
| Tenant attach upload and actions | `CMGatewaySyncUploadWorker.log`, `CMGatewayNotificationWorker.log` (site server) |
| Win32 apps from Intune | `IntuneManagementExtension.log`, `AppWorkload.log` |
| Platform scripts, remediations | `AgentExecutor.log`, `HealthScripts.log` |
| PSADT packages | `C:\Windows\Logs\Software` |
| ConfigMgr apps | `AppDiscovery.log`, `AppEnforce.log` |
| ConfigMgr baselines | `CIAgent.log`, `DcmWmiProvider.log` |
| Windows Update, Delivery Optimization | `Get-WindowsUpdateLog`, `Get-DeliveryOptimizationStatus` |

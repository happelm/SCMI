---
title: 'Day 2 notes – Authority, policy, apps'
---

# Day 2 notes – Authority, policy, apps

> Summary of what was covered on Day 2, with sources – not a transcript. Recommendations marked "trainer recommendation" are field experience, not Microsoft documentation. "Lab observation" means the trainer saw it in the lab environment; it isn't documented by Microsoft. Community tools are named as such.

## Key takeaways

- Three layers decide who manages a co-managed device: the co-management policy (workload sliders), the Intune co-management settings (override), and the device itself, which merges both. Read the result on the device, not in the console.
- A device that enrolled in Intune first – like CL3 and CL4 – keeps Intune as its authority. The sliders don't apply to it; Configuration Manager still delivers apps.
- Group Policy is not a co-management workload. Moving the device configuration slider changes nothing about GPOs: a migrated GPO and the original GPO both apply until you remove the GPO.
- `MDMWinsOverGP` only covers settings of the Policy CSP. It's a safety net for the transition, not a solution – don't configure the same setting in a GPO and in Intune.
- Intune targets Microsoft Entra groups, narrowed by assignment filters. There are no collections, no OU queries and no queries on inventory; some logic moves into the app (requirement rules) or into scripts.
- Rebuild Configuration Manager apps as Win32 apps: install command, detection and return codes carry over almost unchanged. Deployment types, global conditions and OR in detection rules don't exist – that logic moves into the package, for example with the PowerShell App Deployment Toolkit (PSADT).

## 1. Morning check: what converged overnight

- Tenant attach and Intune enrollment create two records for a co-managed device; a background process merges them. After the merge, the Configuration Manager pages of the device are missing for about 12 to 24 hours (lab observation).
- When the merge doesn't happen, the trainer deleted the tenant attach and set it up again later – it worked on the third attempt (lab observation, no documented fix).
- Trainer observation: assignments in the Intune admin center sometimes don't stick when a policy is created with a group in one go (seen often with Android). Workaround: create the policy without an assignment, then add the group in the properties.

## 2. Who governs? Workload authority

| Layer | What it does |
|---|---|
| Co-management policy | The workload sliders in Configuration Manager (Configuration Manager, Pilot Intune, Intune) |
| Intune co-management settings | **Override co-management policy and use Intune for all workloads** – Intune decides for every workload |
| The device | Merges both and applies the result – visible as **Co-management capabilities** and in `CoManagementHandler.log` |

- The registry value `ConfigInfo` under `HKLM\SOFTWARE\Microsoft\DeviceManageabilityCSP\Provider\MS DM Server` shows the authority: `1` = Intune, `2` = Configuration Manager (the sliders apply), no value = the device isn't enrolled in Intune (CL2).
- A Windows 11 device that enrolls in Intune first and gets no co-management settings policy keeps Intune as management authority. Installing the Configuration Manager client as an app doesn't change that. `CoManagementHandler.log` says: *Workloads are explicitly set by Intune Co-Management Profile so not using ConfigMgr set workloads.* Co-management capabilities then show 2147479807.
- Even then, **Configuration Manager apps still install** (PuTTY from Software Center on CL3). Windows updates don't come from Configuration Manager – that's a workload of its own. Use case: Entra joined devices that still need apps from Configuration Manager while the app migration isn't finished.
- **Co-management settings in Intune** (Devices → Enrollment → Windows → Co-management settings) are meant for Windows Autopilot: they install the Configuration Manager client during the enrollment status page and set the authority. Microsoft documents a cloud management gateway as a requirement. Changing the authority on devices that are already provisioned isn't supported; the regular way is to reset the device with Autopilot.
- **Capabilities bitmask:** base value plus one bit per workload that is on Intune. The resource access bit (4) is always set (the slider is fixed on Intune). CL1 with compliance on Pilot Intune: 8199. Workload flags in the logs: compliance 2, resource access 4, Windows Update 16. Switching device configuration also switches endpoint protection.
- Trainer recommendation: start with compliance – Intune is the only compliance source Conditional Access accepts, and the work is small.

Sources: [How to enroll with Windows Autopilot (co-management)](https://learn.microsoft.com/intune/configmgr/comanage/autopilot-enrollment#requirements) · [Co-management workloads](https://learn.microsoft.com/intune/configmgr/comanage/workloads) · [Troubleshoot co-management workloads](https://learn.microsoft.com/troubleshoot/mem/intune/comanage-configmgr/troubleshoot-co-management-workloads)

## 3. Policies: from Configuration Manager and Group Policy to Intune

| Source | In Intune |
|---|---|
| Configuration baseline / configuration item | Compliance policy (custom compliance) and remediation script |
| Antimalware and firewall policies | Endpoint security |
| Client settings (cache, restart, BITS) | Spread over other places; cache → Delivery Optimization. Restart behavior is set per app. |
| Branding | Company Portal customization |
| Hardware inventory extensions | Properties catalog (device inventory) – fewer properties than Configuration Manager |
| Software metering, maintenance windows | Not available – redesign or drop |
| Group Policy | Settings catalog (via Group Policy analytics) |

### Remediations

- Detection script plus remediation script. The detection script exits with `1` when the issue exists; only then the remediation runs. What the script writes to standard output shows up in the portal and in `HealthScripts.log`.
- Up to **200 script packages** per tenant – consolidate instead of one script per small task (trainer recommendation).
- **Licensing:** remediations need Windows Enterprise E3/E5 (also in Microsoft 365 F3/E3/E5), Education A3/A5 or Windows VDA for the users. Microsoft 365 Business Premium doesn't include it.
- Before the first use, confirm the license: Intune admin center → Tenant administration → Connectors and tokens → **Windows data** → **I confirm that my tenant owns one of these licenses** = On. Until then, creating a remediation is greyed out.
- Remediations need the Intune Management Extension on the device. It's installed automatically when a Win32 app, a PowerShell script or a remediation is assigned – the Company Portal as a required app is a simple way to get it there early (trainer recommendation).
- **Run remediation** on a single device works on demand, without an assignment.
- Script signing: Intune doesn't enforce a signature by default (**Enforce script signature check** = No). Signing protects the script from changes, but every edit means signing again.

Sources: [Remediations](https://learn.microsoft.com/intune/device-management/tools/deploy-remediations) · [Windows license verification](https://learn.microsoft.com/intune/privacy/enable-windows-diagnostic-data#enable-windows-license-verification) · [Custom compliance settings](https://learn.microsoft.com/intune/device-security/compliance/custom-settings)

### Group Policy analytics

- Save the GPO as an **XML** report in the Group Policy Management Console (not HTML) and import it in Intune admin center → Devices → Group Policy analytics. The report shows which settings have an MDM equivalent.
- **Migrate** offers only the supported settings and creates a normal settings catalog profile – editable afterwards.
- What doesn't migrate: Group Policy Preferences (drive maps, printers, shortcuts), logon scripts, WMI filters, security filtering, loopback processing. For drive maps and similar tasks, use scripts (remediations).
- Many ADMX-backed settings are in the settings catalog; third-party ADMX files can be imported into Intune.
- Don't migrate 40 GPOs into 40 profiles – regroup by topic (security, user experience, technical) (trainer recommendation).
- Community tool: [intunesettings.app](https://intunesettings.app) lists the settings catalog with descriptions and OMA-URIs.

- The XML file must be smaller than 4 MB. If several GPOs set the same setting to different values, the migration wizard reports the conflict and you pick one.

Sources: [Import and analyze GPOs](https://learn.microsoft.com/intune/device-configuration/import-group-policy-analytics) · [Migrate GPOs to a settings catalog policy](https://learn.microsoft.com/intune/device-configuration/migrate-group-policy)

## 4. Conflicts between Group Policy and Intune

- Group Policy writes to `HKLM\SOFTWARE\Policies\…`, Intune (Policy CSP) to `HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\…` – different places, different value names. Applications decide which one they read.
- Without a rule, the last writer wins: `gpupdate` sets one value, the next Intune sync the other – a flip-flop.
- **MDMWinsOverGP** (settings catalog: Control Policy Conflict → MDM Wins Over GP): MDM policies of the Policy CSP block the equivalent Group Policy. It doesn't apply to other CSPs, for example the Defender CSP or the PassportForWork CSP (Windows Hello for Business) – there Microsoft documents a race condition. The event log *DeviceManagement-Enterprise-Diagnostics-Provider → Admin* shows "MDM wins over GP … the GP setting is blocked".
- The clean solution: Group Policy must not reach Intune-managed devices, at least not with conflicting settings.
- Two Intune profiles with different values for the same setting show a conflict in the portal; you have to resolve it by hand. There is no precedence like site/domain/OU.
- **Tattooing:** settings generally revert when a profile is removed, but not always. If a value stays after the profile is gone and the device has synced, delete it by hand or by script.

Sources: [Policy CSP – ControlPolicyConflict](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-controlpolicyconflict#mdmwinsovergp)

## 5. Targeting: from collections to groups and filters

| Collection type | In Intune |
|---|---|
| Direct membership (`Pilot-CoMgmt`) | Assigned group |
| Query on an attribute Entra ID knows (OS version) | Dynamic group or assignment filter |
| OU query | No OU in Entra ID – `device.deviceTrustType` separates hybrid joined (`ServerAd`) from Entra joined (`AzureAd`), but not by OU. Alternative: sync AD groups. |
| Query on inventory (chassis, installed software) | Not available – requirement rule in the app or a script |
| Include / exclude | Group assignment with exclusion |
| Limiting collection | Dynamic group plus filter |

- **Dynamic groups** are Entra objects; **filters** are Intune objects with their own properties (for example the enrollment profile). A filter only sees devices enrolled in Intune: CL2 (tenant attached only) is in a dynamic group with the OS version rule, but not in the filter preview. It wouldn't get Intune policies anyway.
- Dynamic groups take time to recalculate, more in large tenants. Avoid them where timing matters, for example during Autopilot (trainer recommendation).
- Don't mix user and device groups in include and exclude of one assignment – it isn't reliable.
- Device objects in Entra ID have `extensionAttribute1`–`15`, set with Microsoft Graph and usable in dynamic group rules – a way to carry a value like a department or site to the device ([Dynamic membership rules](https://learn.microsoft.com/entra/identity/users/groups-dynamic-membership#rules-for-devices) · [Update device extension attributes via PowerShell (Microsoft Tech Community)](https://techcommunity.microsoft.com/blog/coreinfrastructureandsecurityblog/update-entra-id-device-extension-attributes-via-powershell--create-dynamic-secur/4449989)).
- Trainer recommendations: decide on a naming convention on day one (for example platform – target – purpose), use the description fields for date, version and change, keep the number of groups small.
- There is no built-in backup of the Intune configuration. Community tool: [IntuneManagement](https://github.com/Micke-K/IntuneManagement) (MIT license) exports, imports, compares and documents policies and profiles.

Sources: [Assignment filters](https://learn.microsoft.com/intune/fundamentals/filters/overview) · [Dynamic membership rules](https://learn.microsoft.com/entra/identity/users/groups-dynamic-membership)

## 6. App anatomy: Configuration Manager app vs. Win32 app

| Configuration Manager | Win32 app in Intune |
|---|---|
| Content on distribution points (UNC) | `.intunewin` package uploaded to Intune – encrypted, can't be downloaded again from the portal |
| Several deployment types per app | One package per app |
| Detection with AND/OR | Several rules are always AND – for OR use a detection script |
| Requirements, global conditions | Requirement rules (file, registry, script) – no global conditions |
| Install for system / user / system if device | System **or** user |
| Logon requirement | Not available – a system install on a device group also runs with nobody signed in |
| Return codes | The same; defaults include 0, 1707, 3010 (soft reboot), 1641 (hard reboot), 1618 (retry) |
| Dependencies, supersedence | Available. Dependency graph up to 100 apps, supersedence up to 10 apps per graph; supersedence per app with **Uninstall previous version** Yes/No |
| Revisions | Not available |

- Registry detection: write the key as `HKEY_LOCAL_MACHINE\…` or `HKLM\…`, not in PowerShell notation `HKLM:\…`. Watch the 32-bit/64-bit view – use **Associated with a 32-bit app on 64-bit clients** instead of writing `WOW6432Node` yourself.
- **Hidden dependencies:** a requirement can depend on a value that another package writes (in the lab: the branding package writes the department for Notepad++). If that package doesn't come along, the requirement never matches.
- Retry: Intune retries a failed install three times, five minutes apart; after that the 24-hour reevaluation schedule applies.
- Logs on the device: `IntuneManagementExtension.log`, `AppWorkload.log` (installs, detection, applicability – similar to `AppEnforce.log`) and `HealthScripts.log` in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
- **Routes per app:** retire, replace with a Store app, rebuild as Win32, wrap with PSADT, or turn it into a remediation if the "app" only writes a setting.
- Store apps (Microsoft Store app (new)) update themselves – no version management, but no control over when the update arrives either. Trainer recommendation: prefer them where nothing speaks against it.
- **Enterprise App Catalog** (Enterprise App Management): prepared Win32 apps with update management. Since July 2026 Microsoft 365 E5 includes it, along with Endpoint Privilege Management and Microsoft Cloud PKI (rolling out); Microsoft 365 E3 gets Remote Help and Advanced Analytics ([What's new, June 29, 2026](https://learn.microsoft.com/intune/whats-new/#week-of-june-29,-2026-service-release-2606) · [Planning guide – licensing](https://learn.microsoft.com/intune/fundamentals/planning-guide#step-3---determine-costs-and-licensing)).
- Third-party catalogs (for example Patch My PC, Robopack) automate packaging and updates for standard software. Whether they pay off depends on how much of your portfolio is standard software (trainer recommendation). WinGet's community repository isn't curated the way the Microsoft Store is – check where a tool really downloads from.
- Packaging: `IntuneWinAppUtil.exe -c <source folder> -s <setup file> -o <output folder>`. Creating the app in Intune can be scripted with Microsoft Graph; that needs consent for the Graph app in Entra ID.

Sources: [Add a Win32 app](https://learn.microsoft.com/intune/app-management/deployment/add-win32) · [Win32 app supersedence](https://learn.microsoft.com/intune/app-management/deployment/configure-win32-supersedence) · [Troubleshoot Win32 apps (logs)](https://learn.microsoft.com/intune/app-management/deployment/troubleshoot-win32#troubleshooting-app-issues-by-using-logs) · [Enterprise App Management](https://learn.microsoft.com/intune/app-management/deployment/enterprise-app-management)

## 7. PowerShell App Deployment Toolkit (PSADT) v4

- Open-source framework for Win32 installations: consistent logging (CMTrace format, `C:\Windows\Logs\Software`), close-apps prompt with deferral, MSI handling with exit codes, file and shortcut functions. Self-contained – everything is in the package folder.
- `Install-Module PSAppDeployToolkit`, then `New-ADTTemplate -Destination <folder> -Name <app>` creates the structure: `Files` (installers), `SupportFiles`, `Assets`, `Config`, `Strings` and the signed module. The only file you edit is `Invoke-AppDeployToolkit.ps1` with the phases Pre-Install, Install, Post-Install, Uninstall and Repair.
- The Intune command lines are always the same: `Invoke-AppDeployToolkit.exe -DeploymentType Install` / `Uninstall`. Only the detection differs per app.
- A user deferral ends with exit code 1602; map it as **Retry** in Intune.
- v4 renamed the functions (`*-ADT*`). AI assistants often mix in v3 names – tell them explicitly to use v4.1 and give them the list from `Get-Command -Module PSAppDeployToolkit` (Lab 10.2).
- Since v4.1 the dialogs run in a separate process in the user's session; ServiceUI is no longer needed ([PSADT 4.1 release](https://psappdeploytoolkit.com/blog/2025/08/07/psadt-4.1) · [Architecture](https://psappdeploytoolkit.com/docs/explanation/architecture), project documentation).
- Troubleshooting chain on the device: `IntuneManagementExtension.log` (policy arrived) → `AppWorkload.log` (install and detection) → PSADT log (what happened inside the package).
- PSADT can replace simple task sequences: install, copy, set registry values, install the next app – in one package.
- Intune has no repair action for apps – Lab 10.3 shows a workaround with a marker and a remediation on demand.

Sources: [PSAppDeployToolkit](https://psappdeploytoolkit.com/) (project site)

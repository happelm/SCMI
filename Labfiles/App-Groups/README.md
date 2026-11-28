# Group of devices with an app installed (instead of a query collection)

Course demo for SCMI, follow-up to Lab 8.1 step 9 ("Has 7-Zip installed → no group, no filter"). Status: **draft, not run as a whole script yet.** The read calls were checked with app-only Graph on 2026-11-28; adding and removing members was not run yet.

## Problem

ConfigMgr builds collections from installed software inventory (`SMS_G_System_ADD_REMOVE_PROGRAMS`). In Intune there is no equivalent target: neither a dynamic group rule nor an assignment filter can read installed apps. Lab 8.1 solves the typical intent with a requirement rule or supersedence on the Win32 app. When you really need a group (for example for a policy, a license reclaim or an uninstall), a script can keep one in sync.

## Files

| File | Purpose |
| --- | --- |
| `Sync-AppInstalledGroup.ps1` | Report mode by default, `-Apply` adds and removes group members |
| `Grant-RunbookGraphPermissions.ps1` | One-time: assign the Graph app roles to an Automation account's managed identity (only for the runbook setup) |

## How it works

1. `GET deviceManagement/detectedApps` (Intune Discovered apps), keep Windows entries whose name matches `-AppName` (`-like`, for example `7-Zip*`). Every version is its own entry, so several versions end up in one group.
2. `GET detectedApps/{id}/managedDevices` per entry. The relation returns stub objects (`azureADDeviceId` empty), so each device is read again from `managedDevices/{id}`. Devices that return 404 are skipped: a deleted device can still be listed under an app (seen in the lab tenant).
3. `azureADDeviceId` → Entra device object (`GET devices?$filter=deviceId eq '…'`).
4. Compare with the direct device members of the group: add missing devices, remove devices that no longer have the app. Users or groups in the target group are reported and left alone.

Safety nets: `-MaxChanges` (default 50) per run; if no device has the app at all, nothing is removed unless `-AllowEmptyGroup` (a typo in the app name must not empty the group); the group must be an assigned security group.

## How fresh is the data (Learn)

Source: [Intune Discovered apps](https://learn.microsoft.com/intune/app-management/discovered-apps)

- Win32 apps (Add/Remove Programs): collected by the Intune Management Extension **every 24 hours** per device. Store apps: every 7 days.
- **Co-managed devices with the client apps workload on Configuration Manager don't collect Win32 inventory through the IME.** They show up only after the client apps workload has moved to Intune – the group fills up as the migration progresses.
- New devices without a signed-in Entra user: first Win32 inventory can take up to 7 days.
- Successor: [App inventory](https://learn.microsoft.com/intune/app-management/deployment/enhanced-app-inventory) (properties catalog policy, several times a day). Learn lists it for Microsoft Entra joined Windows 10/11 devices. A Graph API for it was not found on Learn yet (2026-11-28); when there is one, step 1 can switch the source.

## Demo (about 10 minutes, no Azure needed)

1. ConfigMgr console → Device Collections → **Has 7-Zip installed** → membership rule: the old way.
2. Intune admin center → Apps → Monitor → **Discovered apps** → search `7-Zip` → open the entry → devices.
3. Entra admin center → Groups → New group: Security, **SCMI-DEV-Has-7Zip**, membership type Assigned, no members. Copy the object ID.
4. On the trainer machine, in Windows PowerShell (needs `Microsoft.Graph.Authentication`):

   ```powershell
   .\Sync-AppInstalledGroup.ps1 -AppName '7-Zip*' -GroupId <object-id>
   .\Sync-AppInstalledGroup.ps1 -AppName '7-Zip*' -GroupId <object-id> -Apply
   ```

   The first run only reports, the second fills the group. Point out which devices are missing and why (client apps workload still on ConfigMgr).
5. Removal: uninstall 7-Zip on one device, wait for the next IME inventory (up to 24 hours – prepare this before the demo), run again with `-Apply`: the device leaves the group.
6. Show the production setup on one slide or in the portal: Automation account, managed identity, runbook, daily schedule.

## Production setup in Azure Automation

1. Automation account with system-assigned managed identity, PowerShell 7.4 runtime, module `Microsoft.Graph.Authentication` imported.
2. `Grant-RunbookGraphPermissions.ps1 -ManagedIdentityObjectId <object-id>` assigns (pattern from [Learn](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/assign-app-role-managed-identity-powershell)):

   | Permission (application) | Why |
   | --- | --- |
   | `DeviceManagementManagedDevices.Read.All` | detectedApps and managedDevices ([List detectedApps](https://learn.microsoft.com/graph/api/intune-devices-detectedapp-list?view=graph-rest-1.0)) |
   | `Device.Read.All` | Entra device lookup |
   | `GroupMember.ReadWrite.All` | read the group, add and remove members |

3. Import the runbook, run it with `-UseManagedIdentity` without `-Apply`, check the output, then schedule it daily with `-UseManagedIdentity -AppName '7-Zip*' -GroupId <object-id> -Apply`. One schedule per app/group pair.

## Limits

- Delay: up to 24 hours from install to inventory, plus the schedule, plus Intune assignment processing. Not suited for anything that must react within minutes.
- Discovered apps only see what Windows lists in Add/Remove Programs (Win32) or as a Store app.
- Graph calls are sequential, one per device: fine for a demo and for a few hundred devices. For thousands of devices switch to `$batch`, as in the Primary User example.

## VERIFY before showing it as working

- VERIFY: full run in the SCMI tenant, report mode and `-Apply` (add and remove).
- VERIFY: `GroupMember.ReadWrite.All` is enough to read the group properties (`groupTypes`, `securityEnabled`) app-only.
- VERIFY: 404 handling of `Invoke-MgGraphRequest` in Windows PowerShell 5.1 (the script checks the status code and the error text).
- VERIFY: which SCMI clients report 7-Zip in Discovered apps while their client apps workload is still on ConfigMgr.

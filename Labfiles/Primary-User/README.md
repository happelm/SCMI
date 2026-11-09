# Recalculate the Intune primary user (ConfigMgr-style user device affinity)

Course example for SCMI. Status: **draft, not tested in a tenant.** Logic was tested with PowerShell 7.4 against mocked Graph responses only.

## Problem

ConfigMgr recalculates user device affinity continuously (usage minutes or logon-based). Intune sets the primary user during or right after enrollment and only changes it when an admin changes it. Windows devices in particular end up with the wrong primary user after a handover, a reassignment, or when IT staff enrolled the device (hybrid join and co-management: the first user to sign in becomes primary user).
Source: [Change a device's primary user](https://learn.microsoft.com/intune/device-management/inventory-and-status/find-primary-user)

## Files

| File | Purpose |
| --- | --- |
| `Update-IntunePrimaryUser.ps1` | Runbook: report mode by default, `-Apply` to change |
| `Grant-RunbookGraphPermissions.ps1` | One-time: assign Graph app roles to the Automation account's managed identity |

## How it works

1. List managed devices (Graph beta), keep corporate Windows devices with `joinType` `azureADJoined` or `hybridAzureADJoined`. Learn supports a primary user change only on Windows, Entra joined or hybrid joined.
2. Per device via `$batch` (10 devices per batch):
   - `usersLoggedOn` (`userId`, `lastLogOnDateTime`), [loggedOnUser](https://learn.microsoft.com/graph/api/resources/intune-devices-loggedonuser?view=graph-rest-beta), beta only.
   - `GET managedDevices/{id}/users` for the current primary user. Do not use `userPrincipalName` on the device object: it can stay on the old user after a change ([Microsoft Q&A](https://learn.microsoft.com/answers/questions/1664274/graph-api-manageddevices-not-updating-primary-user), community).
3. Keep only eligible users with a logon inside `-LookbackDays`:
   - resolves to an Entra user (local accounts and deleted users drop out),
   - not matching `-ExcludeUpnPattern`, not in `-ExcludeUserGroupId`,
   - account enabled and Intune service plan `INTUNE_A` (`c1ec4a95-1f05-45b3-a911-aa3fa01094f5`) enabled. Learn: the primary user must be licensed for Intune. ([service plan reference](https://learn.microsoft.com/entra/identity/users/licensing-service-plan-reference))
4. Rule (`-Mode`):

   | Mode | Changes when | Use |
   | --- | --- | --- |
   | `SoleUser` (default) | exactly one eligible user logged on in the window, and it is not the primary user | personal devices, very few false positives |
   | `PrimaryAbsent` | primary user did not log on in the window; newest eligible user wins | handover scenarios, more changes |

5. Skips: device categories in `-ExcludeDeviceCategory` (default `Shared`, `Kiosk`), device name patterns, and devices without primary user (Intune treats them as shared devices) unless `-IncludeDevicesWithoutPrimaryUser`.
6. `-Apply`: `POST managedDevices/{id}/users/$ref` with `{"@odata.id":"https://graph.microsoft.com/beta/users/{userId}"}`, max `-MaxChanges` per run, then re-reads the `users` relation (`Changed` / `ChangedUnconfirmed`). CSV report every run.

## What a change does (Learn)

- Shows in Intune and Entra (device owner) after up to 10 minutes.
- Does not touch local group membership (local Administrators) and does not change "Enrolled by".
- Company Portal: other users see "This device is already assigned to someone in your organization…" and have limited functionality.

## Setup in Azure Automation

1. Automation account with system-assigned managed identity, PowerShell 7.4 runtime, module `Microsoft.Graph.Authentication` imported.
2. Assign app roles with `Grant-RunbookGraphPermissions.ps1` (pattern from [Learn](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/assign-app-role-managed-identity-powershell)). Role changes on managed identities can take a while to apply because tokens are cached (same article).

   | Permission (application) | Why |
   | --- | --- |
   | `DeviceManagementManagedDevices.ReadWrite.All` | read devices, set primary user (community: RealmJoin, Anoop C Nair) |
   | `User.Read.All` | resolve user, `accountEnabled`, `assignedPlans` |
   | `GroupMember.Read.All` | only with `-ExcludeUserGroupId` (Learn lists `GroupMember.ReadBasic.All` as least privileged for transitive members) |

3. Import the runbook, run it with `-UseManagedIdentity` in report mode for one or two weeks, review the CSVs, then schedule daily with `-UseManagedIdentity -Apply -MaxChanges 25`.

## Limits

- `usersLoggedOn` holds the last logon per user, not usage time. This is not the ConfigMgr usage-minutes logic. For real usage time, collect it on the device (for example a remediation script sending to Log Analytics) and let the runbook decide from the workspace.
- Graph beta: properties and behavior can change without notice.
- With co-management, ConfigMgr already calculates UDA. There, syncing ConfigMgr's primary users to Intune (variant 1) is the better source.

## VERIFY before showing it as working

- VERIFY: `POST .../managedDevices/{id}/users/$ref` is only community-documented (Intune.Graph module on PowerShell Gallery, RealmJoin runbook). Learn documents reading the `users` relationship only.
- VERIFY: does the POST replace an existing primary user, or is `DELETE .../users/$ref` needed first? (`DELETE` removes the primary user, Anoop C Nair, community.)
- VERIFY: app-only permission `DeviceManagementManagedDevices.ReadWrite.All` is sufficient for the write (no Learn page for the write).
- VERIFY: does `usersLoggedOn` list local accounts (non-GUID `userId`) or RDP/Fast User Switching logons? The script ignores IDs that do not resolve to an Entra user.
- VERIFY: Graph throttling with large tenants. The script retries 429/503/504 in `$batch` and relies on the SDK retry for single calls.

## Sources

- Learn: [Change a device's primary user](https://learn.microsoft.com/intune/device-management/inventory-and-status/find-primary-user)
- Learn: [managedDevice resource (beta)](https://learn.microsoft.com/graph/api/resources/intune-devices-manageddevice?view=graph-rest-beta), [loggedOnUser (beta)](https://learn.microsoft.com/graph/api/resources/intune-devices-loggedonuser?view=graph-rest-beta)
- Learn: [List group transitive members](https://learn.microsoft.com/graph/api/group-list-transitivemembers?view=graph-rest-1.0)
- Learn: [Assign an application role to a managed identity](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/assign-app-role-managed-identity-powershell)
- Community: [Intune.Graph Set-PrimaryUser](https://www.powershellgallery.com/packages/Intune.Graph/0.1.24/Content/ManagedDevices%5CSet-PrimaryUser.ps1), [RealmJoin Set Primary User](https://docs.realmjoin.com/automation/runbooks/runbook-references/device/general/set-primary-user), [Anoop C Nair: remove primary user](https://www.anoopcnair.com/removing-primary-user-from-intune-device-using/), [svdbusse: primary user to last logged-on user](https://svdbusse.github.io/SemiAnnualChat/2020/03/21/Changing-Intune-Primary-User-To-Last-Logged-On-User.html)

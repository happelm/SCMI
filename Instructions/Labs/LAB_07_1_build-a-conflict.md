---
title: 'Lab 7.1 – Build a conflict'
lab:
    title: 'Lab 7.1 – Build a conflict'
    module: 'Day 2 – Authority, policy, apps'
---

# Lab 7.1 – Build a conflict

**Estimated time:** 15 minutes

**Goal:** Create a real Group Policy / Intune conflict on CL1 with the SmartScreen setting from Lab 6.1, and prove in the registry and the event log which side wins.

1. On CL1 check that GPO-01 applies (`gpresult /r`) and read `HKLM\SOFTWARE\Policies\Microsoft\Windows\System`: `EnableSmartScreen = 1` and `ShellSmartScreenLevel = Block` come from the GPO.
2. Intune: open SCMI-GPO-01 from Lab 6.1 and set the SmartScreen setting Prevent Override For Files In Shell to Disabled – the opposite of GPO-01. The same setting now arrives from both sides.
3. Add Control Policy Conflict → MDM Wins Over GP = enabled to SCMI-GPO-01.
4. Run an MDM sync on CL1 and read the registry key again. Intune does not write there: its values are under `HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\SmartScreen` (`EnableSmartScreenInShell`, `PreventOverrideForFilesInShell`). Read both places: `ShellSmartScreenLevel` is gone from the Policies key.
5. Open Event Viewer → DeviceManagement-Enterprise-Diagnostics-Provider → Admin and find two events for `ShellSmartScreenLevel`.
6. Run `gpupdate /force` and read the key again: the value stays away. The event log shows a new "MDM wins over GP … the GP setting is blocked" event, this time with operation Set – Group Policy tried to write the value and was blocked.
7. Set the SmartScreen setting in SCMI-GPO-01 back to its original value and sync.

### Checkpoint

- [ ] You can show where each side writes its value
- [ ] The event log names the blocked GP setting `ShellSmartScreenLevel`: operation Delete after the sync, operation Set after gpupdate, and the value stays away
- [ ] You can explain why `MDMWinsOverGP` does not replace removing the GPO

> **Note:** MDM Wins Over GP only covers settings of the Policy CSP, and Microsoft documents a race condition for settings that are configured on both sides without it. Use it as a safety net during the transition. The clean solution is to remove the setting from the GPO once Intune delivers it.

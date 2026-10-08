---
title: 'Lab 8.1 – Rebuild three collections'
lab:
    title: 'Lab 8.1 – Rebuild three collections'
    module: 'Day 2 – Authority, policy, apps'
---

# Lab 8.1 – Rebuild three collections

**Estimated time:** 10 minutes

**Goal:** Translate three lab collections – and decide which one should not be rebuilt at all.

1. **Read the source.** ConfigMgr console → Assets and Compliance → Device Collections. For Pilot-CoMgmt, Windows 11 - Build 26300 and Has 7-Zip installed open Properties → Membership Rules and note three things each: the rule type (direct or query), where the data comes from (a named device, hardware inventory, installed software inventory) and the current members.
2. **Pilot-CoMgmt → assigned group.** The collection has one direct rule: CL1. Intune admin center → Groups → New group: type Security, name **SCMI-DEV-Ring-Pilot**, membership type Assigned, add the device CL1. A hand-picked pilot stays hand-picked.
3. **Windows 11 - Build 26300 filter.** The collection queries BuildNumber from hardware inventory. Intune admin center → Tenant administration → Assignment Filters → Create → Managed devices: name **SCMI-Win11-Build**, platform Windows 10 and later, rule `(device.osVersion -startsWith "10.0.26300")` with the build number from the collection name.
4. In the filter, select Preview devices. Compare the list with the members of the collection: which devices are in the collection but not in the preview, and which are in the preview but not in the collection? The collection sees ConfigMgr clients with hardware inventory, the filter sees devices that are enrolled in Intune.
5. Open the assignment of any app or profile you created (do not save): a filter is not a target on its own. It is added to a group assignment in Include or Exclude mode and is evaluated when the device checks in.
6. **Has 7-Zip installed → no group, no filter.** The collection queries installed software. Neither a dynamic group nor a filter can read installed software. Write down what the collection was for – typically "give the update only to devices that already have the product" – and express that intent in Intune: a requirement rule on the Win32 app (file, registry or script) so the app is only applicable where 7-Zip exists, or supersedence for a version update.
7. Summarise the three translations in one line each: collection, rule type, Intune construct, and what is different afterwards.
8. Optional: Groups → New group, membership type Dynamic Device, rule `(device.deviceTrustType -eq "ServerAD")`. Which collection of the lab comes closest to this group, and what does it lose compared with the OU query?

### Checkpoint

- [ ] SCMI-DEV-Ring-Pilot contains CL1
- [ ] The filter preview lists the expected devices
- [ ] You can explain why Has 7-Zip installed has no target equivalent
- [ ] You can name a device that is in the collection Windows 11 - Build … but not in the filter preview, and say why

> **Note:** Keep the groups – they are used again in M9, M10 and M11.

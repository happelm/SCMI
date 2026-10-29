---
title: 'Lab 11.1 – Updates for the pilot ring'
lab:
    title: 'Lab 11.1 – Updates for the pilot ring'
    module: 'Day 3 – Deliver, clean up, operate'
---

# Lab 11.1 – Updates for the pilot ring

**Estimated time:** 25 minutes

**Goal:** Hand Windows updates for CL1 to Intune and replace the branch bandwidth rule with Delivery Optimization.

1. Intune admin center → Devices → Windows updates → Update rings: create SCMI-Ring-Pilot (quality deferral 0, deadline 2 days, grace period 1 day), assign to SCMI-DEV-Ring-Pilot.
2. Feature updates: create a policy SCMI-Anchor for Windows 11, version 26H2, same group.
3. **Delivery Optimization instead of the BITS client setting.** In ConfigMgr, the client setting **CS - Branch Graz BITS** throttles BITS for the fictional branch Graz: 512 Kbps from 8:00 to 17:00, 4096 Kbps outside these hours. With the Windows Update workload on Intune, the updates no longer come through the ConfigMgr client and BITS, but through Delivery Optimization – the client setting no longer applies to them. Rebuild its intent in Delivery Optimization.

    Watch the units: ConfigMgr counts kilobits per second (Kbps), Delivery Optimization kilobytes per second (KB/s). 4096 Kbps ÷ 8 = 512 KB/s is the upper limit. Delivery Optimization has no second absolute value for business hours; the business hours limit is a percentage. When Max Background Download Bandwidth is set, that percentage is calculated from it: 512 Kbps ÷ 8 = 64 KB/s, and 64 KB/s are 12.5 % of 512 KB/s – the field takes whole numbers, so 12 %.

    Intune admin center → Devices → Configuration → Create → Windows 10 and later → Settings catalog: name SCMI-DO. Add settings → search for **Delivery Optimization** and add the settings below:

    | Setting | Value | Why |
    |---|---|---|
    | DO Download Mode | Group (2) | Peers share content across subnets, but only within their group |
    | DO Group Id Source | DNS Suffix (4) | The group is formed from the DNS suffix of the network connection |
    | DO Max Background Download Bandwidth (in KB/s) | 512 | Upper limit, 4096 Kbps |
    | DO Set Hours To Limit Background Download Bandwidth | Enabled | |
    | – From / To | 8 AM / 5 PM | Business hours as in the client setting |
    | – during business hours (percentage) | 12 | 12 % of 512 KB/s ≈ 64 KB/s = 512 Kbps |
    | – outside business hours (percentage) | 100 | 100 % of 512 KB/s = 4096 Kbps |

    You do not type a suffix anywhere: with DNS Suffix (4) every device reads the suffix of its own network connection and uses it as its group. In the lab DC1 hands out `smart.etc` by DHCP, so all clients end up in one group. In production a branch has its own suffix (for example `graz.contoso.com`), so the branch devices share content only among themselves. If a device has no suffix, Delivery Optimization falls back to its default: AD site, then domain SID, then Entra tenant ID.

    Assign the profile to SCMI-DEV-Ring-Pilot.

4. ConfigMgr: create a custom client setting CS - Pilot-CoMgmt with Software Updates = No and deploy it to Pilot-CoMgmt. The slider only moves the authority for the Windows Update policies – the software update agent of the ConfigMgr client stays active until a client setting switches it off. Microsoft: "After moving the Windows Update workload to Intune, the client settings in Configuration Manager need to be adjusted manually."
5. Cloud Attach properties → Workloads: Windows Update policies = Pilot Intune.
6. Sync CL1, run Machine Policy Retrieval. Check `HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Update`, Settings → Windows Update, the connection-specific DNS suffix with `ipconfig /all` and the active Delivery Optimization values with `Get-DOConfig -Verbose` (download mode, group ID source, bandwidth limits). `Get-DeliveryOptimizationStatus` shows the running downloads and how much came from peers.

### Checkpoint

- [ ] PolicyManager\current\device\Update shows the ring values on CL1
- [ ] Settings → Windows Update shows that policies are managed by your organization
- [ ] `CoManagementHandler.log`: Windows Update on Intune

> **Note:** Feature update reports can take hours – do not wait for them.

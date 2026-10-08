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
3. Settings catalog profile SCMI-DO: download mode Group (2), group ID source DNS suffix, and the intent of CS - Branch Graz. That client setting limits BITS to 512 Kbps from 08:00 to 17:00 and to 4096 Kbps outside. ConfigMgr counts kilobits, Delivery Optimization kilobytes: 4096 Kbps = 512 KB/s. So set Max Background Download Bandwidth (in KB/s) = 512 and Set Business Hours to Limit Background Download Bandwidth: 8 to 17, 12 % during business hours (12 % of 512 KB/s ≈ 64 KB/s = 512 Kbps), 100 % outside. Same group.
4. ConfigMgr: create a custom client setting CS - Pilot-CoMgmt with Software Updates = No and deploy it to Pilot-CoMgmt. The slider only moves the authority for the Windows Update policies – the software update agent of the ConfigMgr client stays active until a client setting switches it off. Microsoft: "After moving the Windows Update workload to Intune, the client settings in Configuration Manager need to be adjusted manually."
5. Cloud Attach properties → Workloads: Windows Update policies = Pilot Intune.
6. Sync CL1, run Machine Policy Retrieval. Check HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Update, Settings → Windows Update and Get-DeliveryOptimizationStatus.

### Checkpoint

- [ ] PolicyManager\current\device\Update shows the ring values on CL1
- [ ] Settings → Windows Update shows that policies are managed by your organization
- [ ] CoManagementHandler.log: Windows Update on Intune

> **Note:** Feature update reports can take hours – do not wait for them.

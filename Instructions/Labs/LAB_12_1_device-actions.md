---
title: 'Lab 12.1 – Device actions'
lab:
    title: 'Lab 12.1 – Device actions'
    module: 'Day 3 – Deliver, clean up, operate'
---

# Lab 12.1 – Device actions

**Estimated time:** 10 minutes

**Goal:** Use the daily actions from Intune on an enrolled device and see what tenant attach offers for a ConfigMgr-only device.

1. CL4 in Intune: run the remediation SCMI-RemoteRegistry-Disabled from Lab 6.2 on demand and Collect diagnostics.
2. Download the diagnostics zip and find the IME logs in it.
3. CL2 in Intune: compare the available actions with CL4 and run the script Get Co-Management State (CL2 → CM Scripts → Run script, as in Lab 3.1). It is one of the ConfigMgr Run Scripts of the lab site and reads `ConfigInfo` under `HKLM\SOFTWARE\Microsoft\DeviceManageabilityCSP\Provider\MS DM Server` – the value from Lab 5.1. Expected for CL2: an empty result, because CL2 is not enrolled in Intune. The script runs through the ConfigMgr client, triggered from the Intune admin center.

### Checkpoint

- [ ] Diagnostics zip of CL4 downloaded
- [ ] You can explain why CL2 has no Sync or Wipe

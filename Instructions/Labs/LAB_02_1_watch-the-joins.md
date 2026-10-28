---
title: 'Lab 2.1 – Watch the joins'
lab:
    title: 'Lab 2.1 – Watch the joins'
    module: 'Day 1 – Assess, bridge, connect'
---

# Lab 2.1 – Watch the joins

**Estimated time:** 15 minutes

**Goal:** Complete the Entra join of CL3/CL4 and compare it with the hybrid join of CL1/CL2 – see what each step left behind.

1. Start with CL3 and CL4: complete OOBE with a work or school account – User1 on CL3, User2 on CL4, each as `User1@<your tenant domain>`, not the admin. Pasting doesn't work in the Hyper-V console during OOBE: use **Clipboard → Type clipboard text**. After OOBE, switch to the enhanced session.
2. Cloud Sync provisioning logs: find CL1 and CL2 – they are listed only after their first join attempt.
3. Sign in on CL1 (User1) and CL2 (User2). Both devices are already hybrid joined from Lab 0.1.
4. Run `dsregcmd /status` on CL1 and CL3 and compare the Device State and SSO State sections.

### Checkpoint

- [ ] CL1/CL2: `AzureAdJoined` YES, `DomainJoined` YES
- [ ] CL3/CL4: `AzureAdJoined` YES, `DomainJoined` NO
- [ ] All four devices in Entra ID with the right join type
- [ ] CL3/CL4 visible in Intune

> **Note:** If CL1/CL2 are not joined by the end of the lab, continue with Module 3 – co-management needs CL1 only in the second half of the module.

> **Note:** If you completed OOBE with the admin account by accident, change the primary user of the device in the Intune admin center (device → Properties) to User1 or User2.

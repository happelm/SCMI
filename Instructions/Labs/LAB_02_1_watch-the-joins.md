---
title: 'Lab 2.1 – Watch the joins'
lab:
    title: 'Lab 2.1 – Watch the joins'
    module: 'Day 1 – Assess, bridge, connect'
---

# Lab 2.1 – Watch the joins

**Estimated time:** 15 minutes

**Goal:** Complete the Entra join of CL3/CL4 and compare it with the hybrid join of CL1/CL2 – see what each step left behind.

1. Start with CL3 and CL4: complete OOBE with a work or school account – User1 on CL3, User2 on CL4.
2. Cloud Sync provisioning logs: find CL1 and CL2 – they are listed only after their first join attempt.
3. Sign in on CL1 (User1) and CL2 (User2). Both devices are already hybrid joined from Lab 0.1.
4. Run dsregcmd /status on CL1 and CL3 and compare the Device State and SSO State sections.

### Checkpoint

- [ ] CL1/CL2: AzureAdJoined YES, DomainJoined YES
- [ ] CL3/CL4: AzureAdJoined YES, DomainJoined NO
- [ ] All four devices in Entra ID with the right join type
- [ ] CL3/CL4 visible in Intune

> **Note:** If CL1/CL2 are not joined by the end of the lab, continue with Module 3 – co-management needs CL1 only in the second half of the module.

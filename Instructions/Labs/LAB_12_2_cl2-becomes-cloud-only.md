---
title: 'Lab 12.2 – CL2 becomes cloud-only'
lab:
    title: 'Lab 12.2 – CL2 becomes cloud-only'
    module: 'Day 3 – Deliver, clean up, operate'
---

# Lab 12.2 – CL2 becomes cloud-only

**Estimated time:** 25 minutes

**Goal:** Document CL2's current state, reset it and join it to Entra – without ConfigMgr and without Autopilot.

1. Record the old state: dsregcmd /status on CL2, the CL2 record in ConfigMgr, the Entra device object (join type, device ID) and the AD computer object.
2. Walk through the reset checklist from the slides and note what would be lost on a real device.
3. On CL2: Settings → System → Recovery → Reset this PC → Remove everything.
4. While the reset runs, disconnect the network from the VM. When OOBE appears, reconnect the network and sign in as User2 with a work or school account. The disconnected network skips Autopilot – the VM may still be registered there from an earlier course.
5. Afterwards: dsregcmd /status and the new CL2 in Intune.

### Checkpoint

- [ ] CL2: AzureAdJoined YES, DomainJoined NO
- [ ] CL2 enrolled in Intune, no ConfigMgr client
- [ ] The old records are noted for Lab 13.1

> **Note:** Do not add CL2 to SCMI-ConfigMgr-Client – CL2 should end cloud-only.

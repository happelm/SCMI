---
title: 'Lab 3.1 – Attach your site'
lab:
    title: 'Lab 3.1 – Attach your site'
    module: 'Day 1 – Assess, bridge, connect'
---

# Lab 3.1 – Attach your site

**Estimated time:** 20 minutes

**Goal:** Upload your devices to the Intune admin center and run a first action from the cloud.

1. ConfigMgr console → Administration → Cloud Services → Cloud Attach → Configure Cloud Attach. Sign in with your tenant admin.
2. Upload: upload devices to the Intune admin center, collection All Workstations. On the same tab, clear "Enforce Configuration Manager RBAC for cloud console requests that interact with Configuration Manager".
3. Enablement: automatic enrollment in Intune = None (for now).
4. Finish the wizard and follow CMGatewaySyncUploadWorker.log on SCCM.
5. Intune admin center → Tenant administration → Connectors and tokens → Microsoft Endpoint Configuration Manager: open the banner "You can also manage user permissions from Intune", set Use Intune RBAC to On and apply.
6. Wait some minutes, then sign out of the Intune admin center and sign in again.
7. Intune admin center → Devices → All devices → CL2 → Scripts: run Get Uptime.

### Checkpoint

- [ ] CL1 and CL2 visible in Intune, managed by ConfigMgr
- [ ] Script result for CL2 shown in the portal
- [ ] CMGatewayNotificationWorker.log shows the action
- [ ] Entra admin center → Devices: the MDM column of CL1 and CL2 still shows None – tenant attach is not an MDM enrollment

> **Note:** The Run Scripts must be approved in the console (Software Library → Scripts) before they can run. With Intune RBAC your Global Administrator account is sufficient, but the scripts only appear after a fresh sign-in.

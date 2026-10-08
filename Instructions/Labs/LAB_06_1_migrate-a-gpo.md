---
title: 'Lab 6.1 – Migrate a GPO'
lab:
    title: 'Lab 6.1 – Migrate a GPO'
    module: 'Day 2 – Authority, policy, apps'
---

# Lab 6.1 – Migrate a GPO

**Estimated time:** 10 minutes

**Goal:** Analyze the lab GPOs and move GPO-01 to Intune for a device where Intune is in charge.

1. GPMC on the DC: save GPO-01, GPO-02 and GPO-03 as XML reports (right-click → Save Report…, type XML).
2. Intune admin center → Devices → Manage devices → Group Policy analytics → Import the three files.
3. Compare the MDM support per GPO and open the per-setting view of GPO-02.
4. Select the supported settings of GPO-01 → Migrate → create a settings catalog profile SCMI-GPO-01.
5. Cloud Attach properties → Workloads: Device configuration = Pilot Intune.
6. Assign SCMI-GPO-01 to a new device group SCMI-CL1-Group with CL1, sync CL1 and check the values under `HKLM\SOFTWARE\Microsoft\PolicyManager\current\device`.

### Checkpoint

- [ ] GPO-01 settings arrive on CL1 from Intune
- [ ] You can name three settings of GPO-02 that do not migrate
- [ ] Device configuration on CL1: Intune (pilot)

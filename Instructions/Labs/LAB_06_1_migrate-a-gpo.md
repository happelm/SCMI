---
title: 'Lab 6.1 – Migrate a GPO'
lab:
    title: 'Lab 6.1 – Migrate a GPO'
    module: 'Day 2 – Authority, policy, apps'
---

# Lab 6.1 – Migrate a GPO

**Estimated time:** 10 minutes

**Goal:** Analyze the lab GPOs, rebuild GPO-01 as an Intune profile and apply it to CL1 – next to the GPO, not instead of it.

### Part A – Analyze and migrate the GPO

1. GPMC on the DC: save GPO-01, GPO-02 and GPO-03 as XML reports (right-click → Save Report…, type XML).
2. Intune admin center → Devices → Manage devices → Group Policy analytics → Import the three files.
3. Compare the MDM support per GPO and open the per-setting view of GPO-02.
4. Select the supported settings of GPO-01 → Migrate → create a settings catalog profile SCMI-GPO-01.

### Part B – Let Intune configure CL1

5. Cloud Attach properties → Workloads: Device configuration = Pilot Intune. This slider decides whether Intune configuration profiles or ConfigMgr configuration items apply on the co-managed device. It does not touch Group Policy.
6. Assign SCMI-GPO-01 to a new device group SCMI-CL1-Group with CL1, sync CL1 and check the values under `HKLM\SOFTWARE\Microsoft\PolicyManager\current\device`.
7. On CL1 run `gpresult /r`: GPO-01 is still listed under Applied Group Policy Objects. CL1 now receives the same settings from two sides.

### Checkpoint

- [ ] GPO-01 settings arrive on CL1 from Intune
- [ ] You can name three settings of GPO-02 that do not migrate
- [ ] Device configuration on CL1: Intune (pilot)
- [ ] GPO-01 still applies on CL1

> **Note:** Migrating a GPO copies its settings into Intune – it does not switch the GPO off. As long as CL1 is in the domain and in the scope of GPO-01, Group Policy keeps writing its values. Which side wins when both deliver the same setting is the topic of Lab 7.1. The GPO is unlinked only when Intune delivers every setting and the device population no longer needs it.

---
title: 'Lab 3.2 – Co-manage CL1'
lab:
    title: 'Lab 3.2 – Co-manage CL1'
    module: 'Day 1 – Assess, bridge, connect'
---

# Lab 3.2 – Co-manage CL1

**Estimated time:** 25 minutes

**Goal:** Enroll CL1 into co-management and move the first workload to Intune for the pilot.

1. Cloud Attach properties → Enablement: automatic enrollment = Pilot, pilot collection Pilot-CoMgmt.
2. On CL1 as User1, check dsregcmd /status: AzureAdPrt must be YES (Lab 0.1). Open Edge once and confirm the single sign-on prompt. Then trigger Machine Policy Retrieval & Evaluation Cycle (Configuration Manager control panel → Actions).
3. Follow CoManagementHandler.log on CL1 until the MDM enrollment completes.
4. Cloud Attach properties → Staging: pilot collection Pilot-CoMgmt for all workloads.
5. Workloads: move Compliance policies to Pilot Intune and select the Pilot-CoMgmt Collection under Staging.

### Checkpoint

- [ ] CL1 shows Co-managed in Intune – a second CL1 entry "ConfigMgr" is expected until both records are merged
- [ ] CL2 stays ConfigMgr only
- [ ] Entra admin center → Devices: the MDM column of CL1 now names Configuration Manager, CL2 still shows None
- [ ] Compliance policies: Pilot Intune
- [ ] CoManagementHandler.log without errors
- [ ] Configuration Manager control panel → General → Co-management capabilities: CL1 = 8199 (8192 base + 4 Resource access + 2 Compliance policies + 1 co-management enabled), CL2 = 8197 (no Compliance bit: CL2 is not in Pilot-CoMgmt)

> **Note:** If enrollment does not start, check the MDM user scope, the license of User1 and the hybrid join state of CL1 (PRT). A user who has never confirmed the single sign-on prompt (shown in the EU) causes an error in the user MDM sync – opening the browser once after the hybrid join resolves it. A user who was already signed in while the device joined has no PRT (AzureAdPrt NO) until the next sign-in.

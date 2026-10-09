# SCMI – Migrating from Configuration Manager to Microsoft Intune

Lab instructions for the three-day SCMI transformation workshop.

- **Read online:** <https://happelm.github.io/SCMI/>

## Labs

### Day 1 – Assess, bridge, connect

By the end of Day 1 your users are synced, CL1/CL2 are hybrid joined, CL3/CL4 are Entra joined, the site is attached to your tenant, CL1 is co-managed and CL3 runs a ConfigMgr client installed from Intune.

| Lab | Title | Time |
|---|---|---|
| 0.1 | [Start the identity bridge](Instructions/Labs/LAB_00_1_start-the-identity-bridge.md) | 30 min |
| 1.1 | [Assess your site](Instructions/Labs/LAB_01_1_assess-your-site.md) | 15 min |
| 2.1 | [Watch the joins](Instructions/Labs/LAB_02_1_watch-the-joins.md) | 15 min |
| 3.1 | [Attach your site](Instructions/Labs/LAB_03_1_attach-your-site.md) | 20 min |
| 3.2 | [Co-manage CL1](Instructions/Labs/LAB_03_2_co-manage-cl1.md) | 25 min |
| 4.1 | [Bring CL3 into ConfigMgr](Instructions/Labs/LAB_04_1_bring-cl3-into-configmgr.md) | 30 min |
| 4.2 | [Prepare the night](Instructions/Labs/LAB_04_2_prepare-the-night.md) | 10 min |

### Day 2 – Authority, policy, apps

By the end of Day 2 GPO-01 runs as a settings catalog profile on CL1, the first conflict is resolved, and CL4 – on Intune for all workloads since Day 1 – gets Greenshot, Firefox ESR and Notepad++ from Intune.

| Lab | Title | Time |
|---|---|---|
| 5.0 | [Morning check](Instructions/Labs/LAB_05_0_morning-check.md) | 10 min |
| 5.1 | [Who governs?](Instructions/Labs/LAB_05_1_who-governs.md) | 25 min |
| 6.1 | [Migrate a GPO](Instructions/Labs/LAB_06_1_migrate-a-gpo.md) | 10 min |
| 6.2 | [Turn a configuration item into a remediation](Instructions/Labs/LAB_06_2_turn-a-configuration-item-into-a-remediation.md) | 15 min |
| 7.1 | [Build a conflict](Instructions/Labs/LAB_07_1_build-a-conflict.md) | 15 min |
| 8.1 | [Rebuild three collections](Instructions/Labs/LAB_08_1_rebuild-three-collections.md) | 10 min |
| 9.1 | [Map Greenshot to the Win32 model](Instructions/Labs/LAB_09_1_map-greenshot-to-the-win32-model.md) | 15 min |
| 10.1 | [Convert Firefox ESR with PSADT](Instructions/Labs/LAB_10_1_convert-firefox-esr-with-psadt.md) | 35 min |
| 10.2 | [AI-assisted conversion](Instructions/Labs/LAB_10_2_ai-assisted-conversion.md) | 30 min |
| 10.3 | [Repair a required app](Instructions/Labs/LAB_10_3_repair-a-required-app.md) | 30 min (optional) |

#### Before you leave

- [ ] Firefox and Notepad++ deployments on CL4 installed
- [ ] All VMs of your pod running

### Day 3 – Deliver, clean up, operate

By the end of Day 3 Windows updates for CL1 come from Intune, CL2 is cloud-only, CL4 runs without ConfigMgr, every device has exactly one record – and you leave with a draft migration plan for your own environment.

| Lab | Title | Time |
|---|---|---|
| 11.0 | [Morning check](Instructions/Labs/LAB_11_0_morning-check.md) | 10 min |
| 11.1 | [Updates for the pilot ring](Instructions/Labs/LAB_11_1_updates-for-the-pilot-ring.md) | 25 min |
| 12.1 | [Device actions](Instructions/Labs/LAB_12_1_device-actions.md) | 10 min |
| 12.2 | [CL2 becomes cloud-only](Instructions/Labs/LAB_12_2_cl2-becomes-cloud-only.md) | 25 min |
| 13.1 | [Clean sweep](Instructions/Labs/LAB_13_1_clean-sweep.md) | 30 min |
| 14.1 | [Break and fix](Instructions/Labs/LAB_14_1_break-and-fix.md) | 25 min |
| 15.1 | [Your migration plan](Instructions/Labs/LAB_15_1_your-migration-plan.md) | 35 min |

### Appendix

[Deliberate dirt, log map](Instructions/Appendix.md)

## About this guide

Every lab in the SCMI workshop builds on the previous one – work through them in order and do not reset your pod between days. Each lab lists its goal, the steps at task level (not every click) and a checkpoint you confirm before moving on.

- **Steps** say what to do and where. Menu paths use → between levels.
- **Checkpoint** items are the definition of done. If one fails, tell the trainer before you continue – later labs depend on it.
- **Notes** explain what to expect and where it typically goes wrong.

### Your lab pod

One isolated pod and one Microsoft 365 E3 or E5 tenant per participant – nothing is shared, co-management settings are site-wide.

| System | Role | State at the start |
|---|---|---|
| DC1 | AD DS and DNS, domain smart.etc | `OU=Cloud` is the sync scope (User1, User2, CL1, CL2) |
| SCCM | Primary site ETC, ConfigMgr 2609, Enhanced HTTP | Grown content: apps, collections, baselines, policies, GPOs. Sources in `C:\Software`, share \SCCM\Software$ |
| SRV1 | Windows Server 2025, domain joined, Sync Server | Operating system only |
| CL1 | Windows 11 26H2, domain joined, ConfigMgr client | `OU=Cloud\Workstations\Finance` – your pilot device |
| CL2 | Windows 11 26H2, domain joined, ConfigMgr client | `OU=Cloud\Workstations\Sales` – becomes cloud-only on Day 3 |
| CL3 / CL4 | Windows 11 26H2, no domain | In OOBE – you join them to Entra ID on Day 1 |
| Tenant | Microsoft 365 E3 or E5 | Your tenant admin account from your lab hoster (GoDeploy etc.) |

### Accounts

| Account | Where | Used for |
|---|---|---|
| SMART\Administrator | DC1, SCCM | Domain and ConfigMgr administration |
| User1 | Synced from `OU=Cloud` | Finance user, local administrator – CL1, CL3 |
| User2 | Synced from `OU=Cloud` | Sales user, local administrator – CL2, CL4 |
| Tenant admin | Your tenant | Entra admin center, Intune admin center, Cloud Attach |

Passwords are on the pod card from the trainer.

### Objects you will meet

- **Collections:** All Workstations, Dept-Finance, Dept-Sales, Pilot-CoMgmt (CL1), Workstations - Production, MW-Workstations Sat 22-02, All Laptops, Finance Laptops, Has 7-Zip installed, Users-App-PuTTY
- **Applications:** 7-Zip 24.09 / 25.01 (supersedence), Greenshot (depends on VC++ Redistributable), Notepad++ (two deployment types), PuTTY, Mozilla Firefox ESR, SmartETC Toolbox (deliberately broken), Adobe Reader 2019 (never deployed)
- **Legacy:** package SmartETC Branding, task sequence TS - Finance App Bundle (legacy)
- **Compliance:** BL - Workstation Security, BL - Reporting Only
- **GPOs:** GPO-01 to GPO-04
- **Run Scripts:** Get Uptime, Get Co-Management State, Clear CCM Cache

### Tools

- CMTrace or OneTrace for all .log files – ConfigMgr client logs in `C:\Windows\CCM\Logs`, Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`
- Intune admin center: intune.microsoft.com · Entra admin center: entra.microsoft.com

## Known issues and feedback

Known issues, workarounds and corrections are tracked in the [Issues](https://github.com/happelm/SCMI/issues) tab. If something in a lab does not work as described, check the open issues first, then open a new one with the lab number and the step.

## Contributing

Trainers and participants may fork this repository. Pull requests are welcome and are merged after review.

(c) Enterprise Training Center

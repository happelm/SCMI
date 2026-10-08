---
title: 'Lab 5.1 – Who governs?'
lab:
    title: 'Lab 5.1 – Who governs?'
    module: 'Day 2 – Authority, policy, apps'
---

# Lab 5.1 – Who governs?

**Estimated time:** 25 minutes

**Goal:** Read the workload authority of all four clients, explain why CL1/CL2 follow the site and CL3/CL4 follow Intune – and build the policy that would change it, without assigning it.

1. On CL1 to CL4: Configuration Manager control panel → General → Co-management capabilities. Note the value per client and decode it with the workload table from the slides.
2. On all four clients read ConfigInfo under HKLM\SOFTWARE\Microsoft\DeviceManageabilityCSP\Provider\MS DM Server. 1 = Intune is the management authority, 2 = Configuration Manager, no value = the device is not enrolled in Intune.
3. On CL3 open CoManagementHandler.log. Find the value the site sends (Merged value for setting 'CoManagementSettings_Capabilities') and the value the client applies (Workloads flag retrieved). Read the line that explains the difference.
4. Compare with CoManagementHandler.log on CL1: here the value from the site is applied.
5. On CL3, signed in as User1, open Software Center and install PuTTY. Intune is the authority for every workload on this device, including Client apps – and the ConfigMgr deployment still installs. Authority decides who delivers policies and Intune apps, it does not switch off ConfigMgr deployments.
6. Intune admin center → Devices → Enrollment → Windows → Co-management Settings → Create: name SCMI-CoMgmt-Settings. Walk through the settings as if you were going to use it: automatically install the Configuration Manager client, the command-line arguments (your parameters from Lab 4.1) and, under Advanced, "Override co-management policy and use Intune for all workloads".
7. Save the policy without an assignment. Do not assign it to any group.
8. Decide for each setting combination which ConfigInfo value a new device would end up with, and compare with the slide "Who's in Charge?".

### Checkpoint

- [ ] CL1: ConfigInfo 2, capabilities 8199
- [ ] CL2: no ConfigInfo value, capabilities 8197
- [ ] CL3 and CL4: ConfigInfo 1, capabilities 2147479807
- [ ] You can explain the value of each device and who decides its workloads
- [ ] PuTTY is installed on CL3 from Software Center, although Intune is the management authority
- [ ] SCMI-CoMgmt-Settings exists and has no assignment
- [ ] The table "Who governs which device" matches your pod

> **Note:** CL3 and CL4 enrolled in Intune first, so Intune is their authority and the workload sliders of the site have no effect on them. The co-management settings policy installs the client and sets the authority only during the Autopilot enrollment status page, and Microsoft documents a cloud management gateway as a requirement. Changing it for devices that are already provisioned is described as non-deterministic – that is why the policy stays unassigned in this lab. Setting ConfigInfo to 2 by hand is possible, but unusual in production.

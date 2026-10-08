---
title: 'Lab 4.1 – Bring CL3 into ConfigMgr'
lab:
    title: 'Lab 4.1 – Bring CL3 into ConfigMgr'
    module: 'Day 1 – Assess, bridge, connect'
---

# Lab 4.1 – Bring CL3 into ConfigMgr

**Estimated time:** 30 minutes

**Goal:** Install the ConfigMgr client on CL3 from Intune and watch it register without an AD account.

1. ConfigMgr console → Administration → Cloud Services → Azure Services → Configure Azure Services → Cloud Management. Sign in with your tenant admin, let the wizard create the server app and the client app, and enable Microsoft Entra user discovery.

2. Entra admin center → App registrations → All applications: open the two apps the wizard created. Note the Application (client) ID of the client app and the Application ID URI of the server app (Overview or Expose an API). The tenant ID is on the Entra overview page.

3. Copy ccmsetup.msi from &lt;site install dir&gt;\bin\i386 to your admin workstation.

4. Create a device group SCMI-ConfigMgr-Client with CL3.

5. Export the site's "SMS Issuing" root certificate as a .cer file from the ConfigMgr console (Administration → Overview → Security → Certificates). It is not visible in certlm.msc on the site server.

6. Intune admin center → Devices → Configuration → Create → Windows 10 and later → Templates → Trusted certificate: upload the .cer file, destination store Computer certificate store – Root, assign to SCMI-ConfigMgr-Client.

7. On CL3: sync, then confirm in certlm.msc that SMS Issuing is listed under Trusted Root Certification Authorities. Do not continue before it is there.

8. Intune admin center → Apps → Windows → Add → Line-of-business app: upload ccmsetup.msi, command-line arguments:

    ```text
    CCMSETUPCMD="/NoCRLCheck /mp:https://SCCM.smart.etc SMSSITECODE=ETC SMSMP=https://SCCM.smart.etc AADTENANTID=<tenant ID> AADCLIENTAPPID=<client app ID> AADRESOURCEURI=<server app ID URI>"
    ```

9. Assign the app as required to SCMI-ConfigMgr-Client.

10. On CL3: follow C:\Windows\ccmsetup\Logs\ccmsetup.log, then ClientIDManagerStartup.log and LocationServices.log in C:\Windows\CCM\Logs. The folder C:\Windows\CCM only appears once ccmsetup got its token from the management point.

11. On SCCM: follow CCM_STS.log and MP_RegistrationManager.log.

12. Restart CL3 after the client is installed. In the ConfigMgr console run Update Membership on All Systems and on the collections you want to check: the lab collections only refresh once a day.

13. On CL3 open the Configuration Manager control panel and read Co-management capabilities, then open C:\Windows\CCM\Logs\CoManagementHandler.log.

Troubleshooting the client installation:

- MSI error 1639 (invalid command-line argument): the closing quotation mark of CCMSETUPCMD is missing or is a typographic quote. Type the quotes by hand. MSI log: C:\Windows\System32\config\systemprofile\AppData\Local\mdm{ProductCode}.log.
- A corrected command line can take a while to reach the device. Once the bootstrap MSI is installed, Intune does not run it again: test changed parameters locally with C:\Windows\ccmsetup\ccmsetup.exe and the same parameters.
- ccmsetup.log shows 800B010A for https://SCCM.smart.etc/CCM_STS: the SMS Issuing root certificate is not trusted on the client yet.
- ccmsetup.log shows 80092012: the certificate revocation check failed, /NoCRLCheck is missing in the command line.
- In both cases ccmsetup ends with CCM_E_NO_TOKEN_AUTH (0x87d00455) and retries every 10 minutes.

What you see on CL3 and CL4, and why:

- Co-management capabilities = 2147479807 (0x7FFFF0FF), not 8197. CoManagementHandler.log shows that the site policy arrived (Capabilities 8197) and is ignored: "Workloads are explicitly set by Intune Co-Management Profile so not using ConfigMgr set workloads".
- Reason: a Windows 11 device that enrolled in Intune first and has no co-management settings policy keeps Intune as management authority. Installing the ConfigMgr client as an app does not change that. Intune manages all workloads, whatever the sliders in ConfigMgr say.
- Intune therefore lists all workloads as Intune-managed for CL3 and CL4. The ConfigMgr client still delivers tenant attach actions, inventory and ConfigMgr app deployments.
- CL3 and CL4 are not members of All Workstations: that collection queries the AD OU, and an Entra joined device has none. Software Center stays empty except for user-targeted deployments (PuTTY for members of GG-App-PuTTY).
- The ConfigMgr nodes of CL3 and CL4 in the Intune admin center can take until the next day to appear.

### Checkpoint

- [ ] CL3 in the console: Client = Yes, active
- [ ] CL3 is not in All Workstations – and you know why
- [ ] Configuration Manager control panel on CL3 shows site ETC
- [ ] Software Center opens on CL3

Sync CL3 from Settings → Accounts if the app does not arrive.

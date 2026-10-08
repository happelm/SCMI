---
title: 'Appendix'
lab:
    title: 'Appendix'
    module: 'Appendix'
---

# Appendix

## Deliberate dirt – do not fix

| Object | Purpose |
|---|---|
| SmartETC Toolbox deployed to Dept-Sales | Detection points to the wrong folder – failed deployment visible via tenant attach |
| Adobe Reader 2019 | Distributed, never deployed – dead content |
| 7Zip | Duplicate application without deployment type |
| TEST_alt_Kopie, Neue Sammlung (2), Win10 Upgrade Wave 3 - DONE | Empty or meaningless collections |
| Finance Laptops, All Laptops | Empty on VMs – limiting chain and chassis query |

## Log map

| Question | Where to look |
|---|---|
| Join state, PRT | dsregcmd /status |
| Hybrid join chain | Event Viewer → Microsoft → Windows → User Device Registration → Admin |
| MDM enrollment and policy errors | Event Viewer → DeviceManagement-Enterprise-Diagnostics-Provider → Admin |
| Co-management state | CoManagementHandler.log, ConfigInfo registry value |
| Cloud-first client registration | ccmsetup.log, ClientIDManagerStartup.log, LocationServices.log |
| Tenant attach upload and actions | CMGatewaySyncUploadWorker.log, CMGatewayNotificationWorker.log (site server) |
| Win32 apps from Intune | IntuneManagementExtension.log, AppWorkload.log |
| Platform scripts, remediations | AgentExecutor.log, HealthScripts.log |
| PSADT packages | C:\Windows\Logs\Software |
| ConfigMgr apps | AppDiscovery.log, AppEnforce.log |
| ConfigMgr baselines | CIAgent.log, DcmWmiProvider.log |
| Windows Update, Delivery Optimization | Get-WindowsUpdateLog, Get-DeliveryOptimizationStatus |

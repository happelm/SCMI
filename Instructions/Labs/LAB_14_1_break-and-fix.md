---
title: 'Lab 14.1 – Break and fix'
lab:
    title: 'Lab 14.1 – Break and fix'
    module: 'Day 3 – Deliver, clean up, operate'
---

# Lab 14.1 – Break and fix

**Estimated time:** 25 minutes

**Goal:** In pairs, one breaks and one diagnoses – using the five layers (identity, enrollment, authority, delivery, execution) and the log map only.

1. Pick a scenario and break it on your partner's pod while they look away.
2. Partner: write down the suspected layer before opening any log.
3. Diagnose and fix. Note the evidence that proved the cause.
4. Swap roles and pick another scenario. Time-box: 10 minutes per scenario.

| Scenario | Symptom for the partner | How to break it |
|---|---|---|
| A · Authority | A new settings catalog profile does not apply on CL1 | Device configuration slider to ConfigMgr |
| B · Detection | Firefox Win32 app reports Failed on CL4 although Firefox runs | Change the detection path of the Firefox app |
| C · Targeting | Notepad++ is assigned to CL4 but never shows up | Exclude filter on deviceName CL4 on the assignment |
| D · Signing | A ConfigMgr script detection fails again on CL1 | Custom client setting, PowerShell execution policy All Signed, deployed to Pilot-CoMgmt |

### Checkpoint

- [ ] Two scenarios solved per person
- [ ] For each: layer, evidence, fix
- [ ] One runbook line you would give your helpdesk

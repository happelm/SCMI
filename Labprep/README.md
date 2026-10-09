# SCMI Lab Population

Populates the SCMI pod (smart.etc / site ETC) with realistic, deliberately "grown" content for the
ConfigMgr-to-Intune migration workshop.

## Two modes: shared base image vs. SCMI

The pod image is shared with the Intune courses (MDDMI etc.). The scripts therefore run in two stages.

**Stage A – base image (safe for all courses)**

| # | Script | Where | Effect |
|---|--------|-------|--------|
| 1 | `01-AD-Populate.ps1` | DC | OUs, users, groups, GPOs – **GPO links created disabled** |
| 2 | `02-Prepare-Sources.ps1` | SCCM | Installers + `\\SCCM\Software$` |
| 3 | `03-CM-Populate.ps1` | SCCM | All ConfigMgr **objects**, **no deployments** |
| 4 | wait, then `03-CM-Populate.ps1` again | SCCM | Steps depending on discovery/HINV (Pilot-CoMgmt, build collection) |

Nothing lands on the clients. Intune course demos (7-Zip as Win32 app, Edge/DeviceLock profiles)
behave as before.

**Stage B – SCMI only (before the course or as a checkpoint)**

```powershell
.\01-AD-Populate.ps1 -EnableGpoLinks        # on the DC – only flips link state
.\03-CM-Populate.ps1 -EnableDeployments     # on SCCM – apps, package, baselines, client settings, AM policy
```

Allow ~1 h afterwards so CL1/CL2 have installed the apps, run the baselines and reported state –
otherwise the assessment in M1 and the failed Toolbox deployment in M3 are not visible yet.

## Starting state of a pod

| Object | State in the image | Role in SCMI |
|---|---|---|
| CL1 | domain joined, ConfigMgr client, `OU=Cloud` → moved to `Cloud\Workstations\Finance` | existing fleet, pilot wave |
| CL2 | domain joined, ConfigMgr client, `OU=Cloud` → moved to `Cloud\Workstations\Sales` | existing fleet, converted to cloud-only in M12 |
| CL3 / CL4 | created per student before the course, in OOBE | Entra joined by the student; ConfigMgr client via Intune in M4 |
| User1 / User2 | `OU=Cloud`, synced by the student | User1 → Finance/PuTTY groups, User2 → Sales |

Hybrid join is set up by each student during Day 1 (Cloud Sync device sync + SCP).

All scripts are idempotent and write a `*-results.csv` next to themselves.

## Sync scope

`OU=Cloud` remains the only sync scope. The script creates `OU=Workstations` **inside** it, so
CL1/CL2 stay in scope after the move. `OU=Company` (5 extra users, groups) is deliberately
**not** synced – it gives the ConfigMgr side realistic AD content without cluttering the tenant.
Use `-SkipComputerMove` to leave CL1/CL2 directly in `OU=Cloud`.

## Manual steps after the scripts

1. **Approve the three Run Scripts** (Software Library → Scripts), or enable author self-approval in Hierarchy Settings.
2. **GPO-02 Legacy Mix** – add in GPMC for realism (no cmdlet support):
   - User → Preferences → Drive Maps: `S:` → `\\SCCM\Software$`
   - User → Policies → Windows Settings → Scripts → Logon: any `.cmd`
   - User → Folder Redirection → Documents → `\\SCCM\Home$\%USERNAME%` (share does not need to exist)
3. **Hardware inventory extension**: Default Client Settings → Hardware Inventory → enable one extra class (e.g. `Win32_Battery` or `Win32_TPM`).
4. **Custom return code** on *SmartETC Toolbox* DT: add `1234 = Failure (custom)` – documented example for M8.
5. **Antimalware / firewall policy settings**: adjust exclusions etc. in the console if you want more content than the defaults.
6. **Leave E-HTTP disabled** – participants enable it in M4.

## Deliberate "dirt" (do not fix)

| Object | Purpose |
|---|---|
| `SmartETC Toolbox` deployed to Dept-Sales | Detection points to wrong folder → failed deployment, visible in Tenant Attach |
| `Adobe Reader 2019` | Distributed, never deployed → dead content |
| `7Zip` | Duplicate application without deployment type |
| `7-Zip 25.01` | Supersedes 24.09, not deployed |
| `TEST_alt_Kopie`, `Neue Sammlung (2)`, `Win10 Upgrade Wave 3 - DONE` | Empty / meaningless collections |
| `Finance Laptops`, `All Laptops` | Empty on VMs – limiting chain and chassis query demo |
| `TS - Finance App Bundle (legacy)` | App chain with reboot, never deployed |
| `SmartETC Branding` package | Classic package model with two programs; `/reg:64` trap documented in `install.cmd` |

## Mapping to modules

| Content | Module |
|---|---|
| Collections, dirt, metering, queries, TS | M1 Assessment |
| Pilot-CoMgmt, Run Scripts, Toolbox failure | M3 Tenant Attach / Co-Management |
| OU-based collections (CL3/CL4 missing!) | M4 Cloud-first clients |
| Antimalware policy, client settings | M5 Workload authority, M6 Policy migration |
| CIs & baselines | M6 (baseline → compliance + remediation) |
| GPO-01…03 | M6 Group Policy Analytics |
| GPO-04 | M7 Conflict resolution |
| All applications, global condition, 2 DTs, dependency, supersedence | M8 / M9 |
| Boundary groups HQ / Graz, BITS client settings | M11 Content distribution |

## Known uncertainties

The ConfigMgr script has not yet been run against a 2609 site. Steps tagged `[VERIFY]` use cmdlets
whose parameter sets have changed between releases in the past (global conditions, client
settings, discovery, Endpoint Protection, task sequence steps, script CIs). A failed step is logged
in the CSV and does not abort the run – fix and rerun.

Collection queries assume the AD System Discovery OU format `SMART.ETC/CLOUD/WORKSTATIONS` (parameter `-WksOUPath`).

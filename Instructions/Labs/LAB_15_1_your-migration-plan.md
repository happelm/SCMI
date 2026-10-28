---
title: 'Lab 15.1 – Your migration plan'
lab:
    title: 'Lab 15.1 – Your migration plan'
    module: 'Day 3 – Deliver, clean up, operate'
---

# Lab 15.1 – Your migration plan

**Estimated time:** 35 minutes

**Goal:** Draft the migration plan for your own environment in the workbook `SCMI_Migration_Plan_Template.xlsx` and present it in three minutes.

**Why:** For three days you moved workloads, apps and devices in the lab pod. Your own environment has more devices, more applications and more people who have to agree. The workbook turns what you did here into a plan you can take back to your project – it is the same structure as Modules 1 to 13, one sheet per question.

Download [SCMI_Migration_Plan_Template.xlsx](https://github.com/happelm/SCMI/raw/main/Labfiles/SCMI_Migration_Plan_Template.xlsx) from the [Labfiles folder](https://github.com/happelm/SCMI/tree/main/Labfiles) and open it in Excel. Start on the sheet **Start**: enter your company or environment, your name and the date. Yellow cells are your input; grey rows are examples from the lab pod that you overwrite or delete. Workload authority, routes, status and ratings are drop-down lists – pick a value instead of typing it, so the sheets stay comparable.

You will not finish every sheet in 35 minutes, and you do not need exact numbers. An estimate you can explain is worth more than an empty cell. Mark open values in the Notes column and fill them in after the course.

1. **Assessment** – sheet **1 Assessment**. Count what you have to migrate: devices with the ConfigMgr client and their join type, applications and deployment types, packages and task sequences, GPOs, identities. The column "Where to get it" tells you where each number comes from; the column "Lab (SCMI pod)" shows the values of the lab for comparison. Count deployment types, not applications – a deployment type is the unit of effort in the app factory.

2. **Target state** – sheet **2 Target state**. Split your devices into populations, for example sales laptops, shop floor PCs or kiosks. For each population decide the target join type and the path to get there: Entra joined via Autopilot for new devices, hybrid joined until the next hardware refresh, or a reset. In the table **Workload authority** set the target per co-management workload, the wave in which it moves and the prerequisite it depends on. In the table **Stays in ConfigMgr** write down what remains – servers, for example – with owner and an end date or review date.

3. **Waves** – sheet **3 Waves**. Plan the first three waves. Each row needs a scope, the workloads that move, the staging collection and the Entra group behind it, and the required apps that must be ready. Agree the go and rollback criteria before the wave starts, and name a rollback owner – a person, not a team. The example row shows the order used in the course; Microsoft allows any order.

4. **Risks** – sheet **4 Risks**. Name your top five risks. Rate likelihood and impact from 1 to 3; the sheet calculates the score and highlights everything from 6 upwards. For each risk write a mitigation and an owner. The column "Course ref" links the risk to the module where you practiced the answer.

5. **Phases** – sheet **5 Phases**. The six phases from Assess to Clean sweep are given, with a default exit criterion each. Write your own exit criterion, owner and target date next to it. Phases 2 to 4 overlap in practice; the exit criterion is what makes progress measurable. Give the clean sweep a date as well – without one, the ConfigMgr site keeps running for years.

6. **App tracking** – optional, sheet **App tracking**. If you have time left, list a few of your own deployment types and pick a route for each: retire, Store or WinGet, Win32, or PSADT wrap. The example row is Firefox ESR from Lab 10.1. After the course this sheet becomes the tracking list of your app factory.

7. **Prepare three minutes.** Go back to the sheet **Start**: the summary at the bottom is calculated from the other sheets – deployment types, planned waves, risks with a score of 6 or more, the clean sweep date. The counts include the grey example rows until you delete them. Pick three things for your talk: your target state, your first wave and your biggest risk. You will present them to the group – the others ask one question each.

### Checkpoint

- [ ] A plan you can present in three minutes
- [ ] Every wave has a rollback owner
- [ ] The clean sweep has a date

**Note:** The workbook is yours to keep. Save it with your company name and use it as the starting point of the project – the sheet Start has a version field for that.

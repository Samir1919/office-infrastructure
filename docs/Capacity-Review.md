# Proxmox Host Capacity Review

**Status:** Full production sizing decision pending; limited CRM pilot approved
**Scope:** `pve01` capacity only; this document does not change VM resources or architecture.

## Current confirmed capacity

| Item | Value |
|---|---:|
| Proxmox host | `pve01` |
| Host memory | 16 GB DDR4 |
| Current production VMs | 7 |
| Current VM memory allocation | 7 × 2 GB = 14 GB |
| Nominal memory left before host overhead | 2 GB |
| Local runtime storage | 1 TB NVMe, LVM-Thin |
| Motherboard | MSI `B450M-A PRO MAX II (MS-7C52)`, revision 2.0 |
| Memory slots | 2 DDR4 slots; both occupied |
| Installed memory | 2 × 8 GB DDR4-3200, non-ECC unbuffered, 1.2 V, single-rank |
| Installed DIMM part number | `HKED4081CAA2F2HB1` in both channels |
| Board maximum | 64 GB across 2 slots |
| Current BIOS | AMI `A.20`, release date reported by SMBIOS as 2024-04-09; MSI package family `7C52vA2` |

The 14 GB total is the configured baseline allocation, not a guarantee of actual RAM use. Even so, it leaves too little headroom for the Proxmox host, filesystem cache, temporary peaks, or application deployment.

## Approved target service profile

| Service | Target RAM | Target disk |
|---|---:|---:|
| CRM | 4 GB | 40 GB |
| Database | 8 GB | 100 GB+ |
| FreePBX | 4 GB | 40 GB |
| Website | 2 GB | 30 GB |
| ERP | 4 GB | 40 GB |
| Nginx Proxy Manager | 2 GB | 20 GB |
| Monitoring | 2 GB | 20 GB |
| **Total** | **26 GB** | **290 GB+** |

The 26 GB target excludes Proxmox host memory, operating-system cache, growth headroom, and any future service overhead.

## Capacity assessment

| Measure | Calculation | Result |
|---|---|---:|
| Current baseline VM allocation | 7 × 2 GB | 14 GB |
| Target VM allocation | 4 + 8 + 4 + 2 + 4 + 2 + 2 GB | 26 GB |
| Minimum host reserve for Proxmox and cache | Planning reserve | 4 GB |
| Target plus host reserve | 26 + 4 GB | 30 GB |
| Target plus 20% VM headroom and host reserve | 26 + 5.2 + 4 GB | 35.2 GB |

**Conclusion:** 16 GB cannot safely run the approved target profile. A 32 GB host would leave little operating headroom after the 30 GB target-plus-host-reserve requirement. No application should be deployed at its target resource profile until the owner approves a capacity decision.

## Approved constrained CRM pilot

The owner has approved a preparation and canary exception while the current hardware remains unchanged. This does **not** change the target service profile or approve a VM resize.

| Pilot boundary | Approved state |
|---|---|
| In scope | `db01` MongoDB prerequisite design and `crm01` Node.js CRM canary preparation |
| VM resources | Keep both VMs at the current 2 vCPU / 2 GB / 32 GB baseline |
| Public access | None; no DNS, NPM publication, or router forwarding |
| Migration | Test import only after source MongoDB facts are documented; no production cutover yet |
| Other services | ERP, FreePBX, website, NPM publication, monitoring rollout remain out of scope |
| Required observation | Host/VM CPU, memory, swap, disk/LVM-Thin capacity, and MongoDB health |

If sustained memory pressure, swap activity, disk pressure, or unacceptable CRM/MongoDB response time appears, stop the pilot and defer further deployment until hardware is upgraded. The calculated requirement remains above 35.2 GB; the confirmed two-slot board makes a matched 64 GB kit the practical recommendation.

### Migrated canary observation — 2026-07-19

The following read-only observation was taken after the test migration and owner browser validation. It is a point-in-time pilot result, not approval for production sizing or cutover.

| Measure | `crm01` | `db01` |
|---|---:|---:|
| vCPU / guest memory | 2 / 1,900 MB | 2 / 1,900 MB |
| Available memory | 1,413 MB | 1,414 MB |
| Swap used | 0 MB | 0 MB |
| Root filesystem used | 22% | 22% |
| Observed load | `0.00 0.00 0.00` | Low; peak sample `0.19 0.09 0.03` |
| Service evidence | CRM container healthy; `/healthz` 200; 46.28 MiB container memory; 0 recent error-level matches | `mongod` active; 205 MB resident memory; 14 current connections; 275 leads and 4 users |

No VM-level stop condition was observed. The owner subsequently approved and provisioned a dedicated privilege-separated Proxmox API token with the built-in `PVEAuditor` role. Its effective permissions contain audit privileges only; provisioning and validation follow [Proxmox Read-Only API Access](Proxmox-Read-Only-API.md).

### Proxmox host observation — 2026-07-19

| Measure | Validated result |
|---|---:|
| Proxmox VE | `9.2.4` |
| API-reported usable memory | 13.54 GiB |
| Memory used / remaining | 8.22 GiB / 5.32 GiB (`60.72%` used) |
| Swap used / total | 0 GiB / 8 GiB |
| Load average | `0.03 0.04 0.06` |
| Root filesystem | 8.36 GiB / 93.93 GiB (`8.90%` used) |
| `local-lvm` | Active; 48.02 GiB used / 793.80 GiB total (`6.05%` used) |
| `local-lvm` available | 745.77 GiB |
| Running production VMs | `crm01`, `db01`, `web01`, `erp01`, `npm01` |
| Stopped production VMs | `pbx01`, `mon01` |

The host and migrated CRM pilot showed no current stop condition. This is a point-in-time result with two production VMs stopped; it does not demonstrate that all seven production VMs or the 26 GB target service profile can run safely on the current host. The practical 64 GB production planning recommendation remains unchanged.

## Options and trade-offs

| Option | Benefits | Risks / limitations |
|---|---|---|
| Keep 16 GB | No hardware cost; suitable for baseline automation and limited lab validation | Insufficient for the target profile; production application rollout is blocked |
| Upgrade to 32 GB (2 × 16 GB) | Standard matched dual-channel kit; lower cost | Below the calculated 35.2 GB target-plus-headroom requirement; not recommended for the full plan |
| Upgrade to 48 GB | Meets the arithmetic minimum | No standard symmetric capacity using the board's two occupied slots; mixed 32+16 or 24 GB DIMMs add compatibility/dual-channel uncertainty and are not recommended |
| Upgrade to 64 GB (2 × 32 GB) | Board maximum; matched dual-channel kit; strongest growth, backup, monitoring, and recovery headroom | Higher cost; exact BIOS/QVL or vendor board-compatibility must be confirmed before purchase |

## Recommendation

The MSI board's two-slot layout makes **64 GB as a matched 2 × 32 GB DDR4-3200 kit** the recommended practical production target. Although 48 GB exceeds the calculated 35.2 GB planning requirement, it does not map cleanly to a standard matched symmetric kit on this board. A 32 GB kit remains below the planning requirement.

MSI's official specification lists two DDR4 slots, 64 GB maximum capacity, dual-channel operation, and non-ECC unbuffered UDIMM support. AMD specifies up to DDR4-3200 for the installed Ryzen 7 5700G. Use a matched 1.2 V non-ECC UDIMM kit; do not combine the existing 8 GB modules with new modules or depend on an overclocked memory profile for the infrastructure baseline. See the [MSI motherboard specification](https://www.msi.com/Motherboard/B450M-A-PRO-MAX-II/Specification) and [AMD Ryzen 7 5700G specification](https://www.amd.com/en/support/downloads/drivers.html/processors/ryzen/ryzen-5000-series/amd-ryzen-7-5700g.html).

This is a recommendation, not an approved resource change. The owner must choose an option before any VM resize or Phase 5 application rollout.

### Owner deferral — 2026-07-19

The owner has deferred the entire BIOS, RAM, and hardware-upgrade subject and will manage any future upgrade decision independently. Until the owner explicitly reopens it, no further compatibility research, vendor confirmation, purchase preparation, firmware work, hardware change, or upgrade reminder is in scope. Project work continues on the current 16 GB host with the existing VM allocations and monitoring boundaries. This deferral does not make the full 26 GB target allocation safe and does not authorize any VM resize.

## BIOS and memory qualification — 2026-07-19

The host reports AMI BIOS `A.20` with SMBIOS release date `2024-04-09`. MSI's support page maps the `A.20` generation to stable package `7C52vA2`, which includes AGESA ComboAm4v2PI `1.2.0.C`. MSI lists Ryzen 7 5700G support from the board's initial `A0` BIOS, and its board specification requires only ComboPI `1.0.0.3` or newer for 64 GB support. The current firmware therefore satisfies the published CPU and capacity prerequisites; a BIOS update is not required solely to recognize 64 GB.

MSI lists stable `7C52vA5` dated `2025-09-30` as the newest non-beta firmware, with AGESA ComboAm4v2PI `1.2.0.F`. Updating may provide newer firmware fixes, but it is a separate maintenance change with outage, settings-reset, and flash-failure risk. If approved, perform it with the current known-good memory, stable power, recorded BIOS settings, and a separately validated rollback/recovery plan before replacing RAM. Do not use a beta firmware for this infrastructure baseline.

MSI's Ryzen 5000G memory QVL was last updated in 2023. It confirms that the board can operate two tested 32 GB DIMMs, including Kingston `KVR26N19D8/32`, TEAMGROUP `TED432G2666C19BK`, and ADATA `AD4U2666732G19-B`, but those listed 32 GB examples are DDR4-2666 rather than DDR4-3200. The Kingston model is also discontinued, so availability and warranty quality may be poor.

Kingston's current `KVR32N22D8/32` is a technically suitable candidate: 32 GB, DDR4-3200, CL22, 2Rx8, non-ECC, unbuffered, 1.2 V, and JEDEC-standard operation. Two identical modules would match the board's electrical specification and AMD's supported memory speed. This is an engineering compatibility inference, not an exact MSI-QVL confirmation; Kingston's board configurator confirms the board's 64 GB/two-socket limit but did not directly qualify this part in the retrieved result. Purchase it only after the seller or Kingston confirms exact-board support and provides a return option.

| Acquisition path | Exact part | Benefits | Risks / limitations |
|---|---|---|---|
| QVL-first | 2 × Kingston `KVR26N19D8/32` | MSI QVL explicitly shows two-DIMM support | DDR4-2666; discontinued; sourcing and warranty risk |
| Current-spec candidate | 2 × Kingston `KVR32N22D8/32` | JEDEC DDR4-3200, 1.2 V, current 32 GB modules; matches board/CPU published specifications | Not explicitly present in MSI's old QVL; vendor confirmation and return policy required |

Avoid XMP-only 1.35 V gaming kits as the infrastructure baseline. Whichever option is selected, use two identical modules from the same part/revision and do not reuse the existing 8 GB DIMMs.

Qualification sources: [MSI BIOS, CPU and memory compatibility](https://www.msi.com/Motherboard/B450M-A-PRO-MAX-II/support), [MSI board specification](https://www.msi.com/Motherboard/B450M-A-PRO-MAX-II/Specification), [Kingston board configurator](https://www.kingston.com/en/memory/search/model/109179/msi-b450m-a-pro-max-ii-motherboard), [Kingston `KVR32N22D8/32` specification](https://www.kingston.com/datasheets/KVR32N22D8_32.pdf), and [AMD Ryzen 7 5700G specification](https://www.amd.com/en/support/downloads/drivers.html/processors/ryzen/ryzen-5000-series/amd-ryzen-7-5700g.html).

## Required validation before a decision

Hardware-upgrade validation is deferred. If the owner explicitly reopens the subject later, review these previously gathered facts against then-current hardware, firmware, availability, and project requirements before making any decision. Until then, retain the current allocations and use the pilot stop conditions for ongoing work.

## Decision record

| Decision item | Owner decision |
|---|---|
| Hardware-upgrade work | Deferred by owner; no action or follow-up until explicitly reopened |
| Selected host memory target | No current selection; previous 64 GB recommendation retained only as historical analysis |
| Current BIOS | `A.20` recorded; sufficient for published CPU/64 GB prerequisites |
| BIOS update | Out of scope until owner explicitly reopens the subject |
| Hardware compatibility confirmed | Board-level 64 GB support confirmed; QVL-listed DDR4-2666 and non-QVL current DDR4-3200 paths documented; exact purchase remains pending |
| Maintenance window | Not applicable while deferred |
| VM resize plan approved | Not approved; existing allocation retained for limited CRM pilot |

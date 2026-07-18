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

If sustained memory pressure, swap activity, disk pressure, or unacceptable CRM/MongoDB response time appears, stop the pilot and defer further deployment until hardware is upgraded. The recommended 48 GB minimum and 64 GB preferred planning targets remain unchanged.

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

The host and migrated CRM pilot showed no current stop condition. This is a point-in-time result with two production VMs stopped; it does not demonstrate that all seven production VMs or the 26 GB target service profile can run safely on the current host. The 48 GB minimum and 64 GB preferred production planning recommendations remain unchanged.

## Options and trade-offs

| Option | Benefits | Risks / limitations |
|---|---|---|
| Keep 16 GB | No hardware cost; suitable for baseline automation and limited lab validation | Insufficient for the target profile; production application rollout is blocked |
| Upgrade to 32 GB | May support strictly phased, reduced-resource testing | Marginal for the complete target profile; limited host/cache/growth headroom |
| Upgrade to 48 GB | Covers the calculated 35.2 GB planning requirement with useful headroom | Requires compatible RAM purchase and a maintenance window |
| Upgrade to 64 GB | Stronger growth and recovery headroom for databases, monitoring, backups, and future services | Higher cost; compatibility must be confirmed |

## Recommendation

Use **48 GB as the minimum production planning target** before Phase 5 application deployment. Prefer **64 GB** if compatible with `pve01` and budget allows, because the project includes future database growth, backup activity, monitoring, and disaster-recovery work.

This is a recommendation, not an approved resource change. The owner must choose an option before any VM resize or Phase 5 application rollout.

## Required validation before a decision

1. Confirm `pve01` motherboard RAM-slot count, supported DIMM capacity, and compatible DDR4 specification.
2. Record current Proxmox memory use, swap state, CPU load, and LVM-Thin free space.
3. Confirm that 48 GB or 64 GB is physically achievable with the installed memory layout.
4. Select the approved target capacity and maintenance window.
5. Update the VM resource plan only after owner approval, then validate and snapshot affected VMs before application deployment.

## Decision record

| Decision item | Owner decision |
|---|---|
| Selected host memory target | Pending; 48 GB minimum planning target, 64 GB preferred |
| Hardware compatibility confirmed | Pending |
| Maintenance window | Pending |
| VM resize plan approved | Not approved; existing allocation retained for limited CRM pilot |

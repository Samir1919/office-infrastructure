# Proxmox Host Capacity Review

**Status:** Decision required before Phase 5 application deployment  
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
| Selected host memory target | Pending |
| Hardware compatibility confirmed | Pending |
| Maintenance window | Pending |
| VM resize plan approved | Pending |

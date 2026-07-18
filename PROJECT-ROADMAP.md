# Office Infrastructure Project Roadmap

> **Official project source of truth.** This document records approved architecture, permanent standards, current state, delivery order, and the next approved implementation step. If it conflicts with chat history, this document takes precedence. A human owner may approve a documented change.

## Document control

| Item | Value |
|---|---|
| Project | Office Infrastructure Project |
| Status | Active |
| Last consolidated | 2026-07-18 |
| Current phase | Constrained CRM and MongoDB pilot preparation |
| Maintainer | Project Owner |

## Objective and architecture principles

Build a reliable self-hosted office platform on Proxmox VE for CRM, ERP, company website, FreePBX, central databases, reverse proxy, monitoring, backup, and future disaster recovery.

- Proxmox performs virtualization only; each production service has its own VM.
- Use Docker Compose only where suitable; databases remain on `db01`.
- Keep backup storage on a separate future TrueNAS/backup machine.
- Prefer Infrastructure as Code, repeatable deployment, security by default, and documented changes.
- Do not change architecture without documenting comparison, impact, risks, and owner approval.

## Current infrastructure

### Proxmox host

| Item | Value |
|---|---|
| Hostname | `pve01` |
| Platform | Proxmox VE 9.2 |
| CPU | AMD Ryzen 7 5700G |
| Memory | 16 GB DDR4 |
| Storage | 1 TB NVMe, LVM-Thin |
| LAN / host IP | `192.168.10.0/24` / `192.168.10.95` |

### Virtual machines

| VM ID | Hostname | IP | Role | Base resources |
|---:|---|---|---|---|
| 101 | `crm01` | `192.168.10.101` | CRM | 2 vCPU / 2 GB / 32 GB |
| 102 | `db01` | `192.168.10.102` | Database | 2 vCPU / 2 GB / 32 GB |
| 103 | `pbx01` | `192.168.10.103` | FreePBX | 2 vCPU / 2 GB / 32 GB |
| 104 | `web01` | `192.168.10.104` | Website | 2 vCPU / 2 GB / 32 GB |
| 105 | `erp01` | `192.168.10.105` | ERP | 2 vCPU / 2 GB / 32 GB |
| 106 | `npm01` | `192.168.10.106` | Nginx Proxy Manager | 2 vCPU / 2 GB / 32 GB |
| 107 | `mon01` | `192.168.10.107` | Monitoring | 2 vCPU / 2 GB / 32 GB |
| 900 | `ubuntu24-template` | N/A | Golden template | 2 vCPU / 2 GB / 32 GB |

Production VMs are full clones of VM900, use Ubuntu Server 24.04 LTS, have static networking, QEMU Guest Agent, SSH access, current updates, and a `base-config` snapshot.

## Permanent standards

1. VM ID equals the final IP octet: VM101 uses `192.168.10.101`.
2. Default Linux baseline is Ubuntu Server 24.04 LTS from VM900.
3. New VM baseline is 2 vCPU, 2 GB RAM, 32 GB disk, full clone, and `base-config` snapshot. Resize only after service-specific review.
4. Ansible runs from the owner’s macOS workstation through passwordless SSH as `sysadmin`.
5. This roadmap is canonical; `docs/` contains supporting references and ADRs explain permanent decisions.
6. Git is change history; GitHub is off-site backup and should remain private except for intentional reviews.
7. Production workflow is documentation → review/approval → implementation → validation → snapshot where applicable → changelog.
8. Never commit plaintext secrets. Ansible Vault-encrypted secret files may be versioned only in the private repository; Vault passwords remain outside Git in each control node’s macOS Keychain or approved password manager.
9. Central databases on `db01` use per-application users, per-application firewall rules, and `<application>_<environment>` database names. See the database access policy before onboarding any database client.

## Delivery order

The approved automation layer improves implementation quality without changing the original service architecture.

| Phase | Deliverable | Status |
|---:|---|---|
| 1–3 | Hardware, Proxmox, template, and seven base VMs | Complete |
| 4.0 | Ansible control plane, SSH keys, and inventory | Complete |
| 4.1 | Common baseline role and validation | Complete |
| 4.2 | Docker Engine and Compose on Docker hosts | Complete |
| 5 | CRM, website, ERP, Nginx Proxy Manager | Pending |
| 6 | MongoDB, PostgreSQL, database security and backups | Pending |
| 5.1 | VPN-based Remote Administration, Wake-on-LAN strategy and secure remote access baseline | Pending |
| 7 | FreePBX | Pending |
| 8 | Backup server / TrueNAS and restore test | Pending |
| 9 | Monitoring | Pending |
| 10 | Production hardening and DR testing | Pending |

## Docker policy

Docker is planned only for `crm01`, `web01`, `erp01`, and `npm01`. Do not install Docker on `db01` or `pbx01`. Decide `mon01` containerization during monitoring design.




## Remote administration policy

- No production VM will be exposed directly to the Internet.
- Proxmox Web UI (8006) must never be publicly port-forwarded.
- SSH (22) must never be directly exposed to the Internet.
- Database ports (MongoDB, PostgreSQL) must never be publicly exposed.
- Remote administration must be performed through a VPN (preferred: Tailscale initially, WireGuard/OpenVPN or future firewall VPN later).
- Remote power-off is performed over VPN + SSH.
- Remote power-on is performed using Wake-on-LAN from an always-on LAN device (future firewall, NAS, backup server, Raspberry Pi or equivalent).
- Direct UDP WoL broadcast forwarding from the Internet is not part of the standard architecture.
- Public application traffic will enter only through `npm01`.
- Router port forwarding should eventually expose only:
  - TCP 80 → `npm01`
  - TCP 443 → `npm01`
- CRM, ERP, Website and future applications are published through Nginx Proxy Manager using reverse proxy and HTTPS.
- FreePBX public exposure will be documented separately during Phase 7 after security review.

## Resource and capacity gate

The current 2 GB / 32 GB allocation is a baseline, not final service sizing. Before application deployment, review service resources and host capacity. The original target profile—CRM 4 GB/40 GB, database 8 GB/100 GB+, PBX 4 GB/40 GB, website 2 GB/30 GB, ERP 4 GB/40 GB, NPM 2 GB/20 GB, monitoring 2 GB/20 GB—exceeds the present 16 GB host if applied together. No resource increase may occur without a documented capacity decision.

### Approved constrained CRM pilot

The owner has approved a limited pilot on the current 16 GB host so that the existing Node.js CRM can begin preparation before future hardware work. This is an exception for preparation and canary validation only; it does not approve the complete Phase 5 or Phase 6 production rollout.

- The pilot scope is limited to `db01` MongoDB prerequisite work and `crm01` CRM canary preparation.
- Both VMs retain their current baseline allocation of 2 vCPU / 2 GB / 32 GB; no VM resize is approved.
- `db01` will use MongoDB `8.3.4`, the approved current stable patch release. The new CRM production database is `crm_prod`; the confirmed Windows source is MongoDB `7.0` database `realestate_crm`. Its document-upload storage method must be confirmed before migration.
- `crm01` will use the latest production-supported Node.js 24.x LTS patch release; its package manager, start command, and required environment variables must be documented before application preparation.
- No public DNS, Nginx Proxy Manager publication, router forwarding, ERP, FreePBX, or additional application deployment is included in this pilot.
- Database hardening, backup design, production cutover, and the complete Phase 6 scope remain pending.
- The pilot must record host/VM CPU, RAM, swap, and MongoDB health before moving toward production cutover.

## Current automation state

- macOS control node: Homebrew Ansible 14.2.0 on Python 3.14.6.
- All seven VMs return `pong` to `ansible all -m ping` and use `/usr/bin/python3.12`.
- Inventory: `ansible/inventory/production.yml`; global variables: `ansible/group_vars/all/main.yml`; encrypted sudo credential: `ansible/group_vars/all/vault.yml`.
- The common role passed syntax validation, was applied and validated on all seven production VMs, and each VM has a `common-base` snapshot.
- The macOS Keychain provides the local Vault password; the encrypted Vault file is versioned only in the private repository.
- Docker Engine and Compose are installed and validated on `crm01`, `web01`, `erp01`, and `npm01`; each has a `docker-base` snapshot.
- MongoDB Community `8.3.4` is installed and validated on `db01`. Authorization is enabled; `crm_app` has `readWrite` access to `crm_prod` only; UFW allows TCP `27017` only from `crm01` and SSH only from the office server LAN. No data migration has been applied.
- The internal CRM canary is deployed on `crm01` from Git revision `ae9539ca575df9ffdafe047c49b20fff2473b858`, runs Node.js `v24.18.0`, returns healthy from `/healthz`, connects to `crm_prod`, and has passed authenticated internal login validation. It has no Nginx Proxy Manager host, public DNS, TLS certificate, or router forwarding. The Windows source data has not been imported.
- The empty CRM canary database was reset once before migration and bootstrapped with the Vault-managed `Admin User` account for `admin@asalagroupbd.com`. The known repository fallback password was not used.

## Next approved implementation step

1. Take the `crm-installed` Proxmox snapshot after the validated canary deployment.
2. Run internal CRM login and representative read/write testing against the empty canary database.
3. Run a test `realestate_crm` → `crm_prod` MongoDB migration and validate data counts and application behaviour.
4. Complete production cutover only after a separate owner-approved capacity and cutover decision.

## Supporting references

- [VM inventory](docs/VM-Inventory.md)
- [Network design](docs/Network-Design.md)
- [Capacity review](docs/Capacity-Review.md), [CRM pilot migration plan](docs/CRM-Migration-Plan.md), [database access policy](docs/Database-Access-Policy.md), [Storage](docs/Storage-Design.md), [security](docs/Security-Baseline.md), and [backup](docs/Backup-Strategy.md)
- [Monitoring](docs/Monitoring-Strategy.md), [deployment runbook](docs/Deployment-Runbook.md), and [disaster recovery](docs/Disaster-Recovery.md)
- [Architecture decisions](docs/ADR/) and [change history](docs/CHANGELOG.md)

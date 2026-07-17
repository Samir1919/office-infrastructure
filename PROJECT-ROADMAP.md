# Office Infrastructure Project Roadmap

> **Official project source of truth.** This document records approved architecture, permanent standards, current state, delivery order, and the next approved implementation step. If it conflicts with chat history, this document takes precedence. A human owner may approve a documented change.

## Document control

| Item | Value |
|---|---|
| Project | Office Infrastructure Project |
| Status | Active |
| Last consolidated | 2026-07-17 |
| Current phase | Automation foundation, before Docker |
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

## Delivery order

The approved automation layer improves implementation quality without changing the original service architecture.

| Phase | Deliverable | Status |
|---:|---|---|
| 1–3 | Hardware, Proxmox, template, and seven base VMs | Complete |
| 4.0 | Ansible control plane, SSH keys, and inventory | Complete |
| 4.1 | Common baseline role and validation | In progress |
| 4.2 | Docker Engine and Compose on Docker hosts | Pending |
| 5 | CRM, website, ERP, Nginx Proxy Manager | Pending |
| 6 | MongoDB, PostgreSQL, database security and backups | Pending |
| 7 | FreePBX | Pending |
| 8 | Backup server / TrueNAS and restore test | Pending |
| 9 | Monitoring | Pending |
| 10 | Production hardening and DR testing | Pending |

## Docker policy

Docker is planned only for `crm01`, `web01`, `erp01`, and `npm01`. Do not install Docker on `db01` or `pbx01`. Decide `mon01` containerization during monitoring design.

## Resource and capacity gate

The current 2 GB / 32 GB allocation is a baseline, not final service sizing. Before application deployment, review service resources and host capacity. The original target profile—CRM 4 GB/40 GB, database 8 GB/100 GB+, PBX 4 GB/40 GB, website 2 GB/30 GB, ERP 4 GB/40 GB, NPM 2 GB/20 GB, monitoring 2 GB/20 GB—exceeds the present 16 GB host if applied together. No resource increase may occur without a documented capacity decision.

## Current automation state

- macOS control node: Homebrew Ansible 14.2.0 on Python 3.14.6.
- All seven VMs return `pong` to `ansible all -m ping` and use `/usr/bin/python3.12`.
- Inventory: `ansible/inventory/production.yml`; global variables: `ansible/group_vars/all.yml`.
- The common role has been added locally and passed syntax validation.
- A `crm01` check-mode run stopped before any change because `sysadmin` requires a sudo password. SSH key access is working; privilege escalation is the remaining bootstrap requirement.

## Next approved implementation step

1. Establish secure non-interactive sudo for Ansible. Preferred: store the existing `sysadmin` sudo password in an encrypted Ansible Vault file; do not commit the Vault password or any plaintext secret.
2. Re-run `ansible-playbook playbooks/common.yml --check --limit crm01`.
3. After review, apply to `crm01` and validate package state, timezone, and QEMU Guest Agent.
4. Apply to the remaining VMs only after successful validation.
5. Create `common-base` snapshots and update the changelog.
6. Then create the Docker inventory group and Docker role.

## Supporting references

- [VM inventory](docs/VM-Inventory.md)
- [Network design](docs/Network-Design.md)
- [Storage](docs/Storage-Design.md), [security](docs/Security-Baseline.md), and [backup](docs/Backup-Strategy.md)
- [Monitoring](docs/Monitoring-Strategy.md), [deployment runbook](docs/Deployment-Runbook.md), and [disaster recovery](docs/Disaster-Recovery.md)
- [Architecture decisions](docs/ADR/) and [change history](docs/CHANGELOG.md)

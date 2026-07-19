# Office Infrastructure Project Roadmap

> **Official project source of truth.** This document records approved architecture, permanent standards, current state, delivery order, and the next approved implementation step. If it conflicts with chat history, this document takes precedence. A human owner may approve a documented change.

## Document control

| Item | Value |
|---|---|
| Project | Office Infrastructure Project |
| Status | Active |
| Last consolidated | 2026-07-19 |
| Current phase | Constrained CRM and MongoDB pilot validation |
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
- `db01` uses MongoDB `8.3.4`, the approved current stable patch release. The new CRM production database is `crm_prod`; the confirmed Windows source is MongoDB `7.0` database `realestate_crm`. Its document-upload storage method must be confirmed before production cutover.
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
- New-control-node guidance now documents that GitHub contains encrypted Vault files but not their password, requires recovery of the same existing password from the old Keychain, an approved secondary password-manager entry, or a future encrypted offline copy, and prohibits replacing/overwriting Vault files when recovery is unavailable.
- Docker Engine and Compose are installed and validated on `crm01`, `web01`, `erp01`, and `npm01`; each has a `docker-base` snapshot.
- Read-only `npm01` inspection found Docker active with no containers, images,
  custom networks, volumes, Compose/NPM files, or listeners on TCP `80`, `81`,
  or `443`. The VM had about 1.5 GiB available RAM, zero swap use, 20% root-disk
  use, and low load. UFW was inactive and only Docker-managed base nftables
  chains were present, so a Docker-aware LAN-only TCP `81` control is a blocker
  before NPM deployment. SQLite on `npm01`, the persistent layout, and
  non-deploying automation preparation are approved and validated. The
  administrator secret workflow, firewall implementation, service deployment,
  proxy host, DNS, TLS, and router changes remain unapproved.
- The NPM firewall architecture review documents why ordinary UFW does not
  control Docker-published ports, rejects editing Docker-owned chains or
  disabling Docker's iptables management, and recommends a layered UFW host
  baseline plus a narrowly scoped project chain reached from `DOCKER-USER`.
  The IPv4 firewall is now applied and validated: UFW is active with LAN-only
  SSH, and a persistent project-owned `NPM-FILTER` chain limits future IPv4 TCP
  `80`, `81`, and `443` to the office LAN. Fresh SSH and zero-change check mode
  passed. A separately approved Docker restart reconfirmed the active/enabled
  unit, unchanged UFW policy, and restored exact chain rules. The host has global IPv6 while the project
  Docker policy is IPv4-only. The owner approved explicit `192.168.10.106`
  bindings for NPM TCP `80`, `81`, and `443`; native IPv6 publication remains
  deferred.
- MongoDB Community `8.3.4` is installed and validated on `db01`. Authorization is enabled; `crm_app` has `readWrite` access to `crm_prod` only; UFW allows TCP `27017` only from `crm01` and SSH only from the office server LAN. A test migration from Windows `realestate_crm` to `crm_prod` imported 275 leads and 4 users; the Windows source remains unchanged.
- The internal CRM canary is deployed on `crm01` from Git revision `dca592b946e1aad1b297c05d51cab58e7cac97c9`, runs Node.js 24 LTS, returns healthy from `/healthz`, connects to `crm_prod`, and has no Nginx Proxy Manager host, public DNS, TLS certificate, or router forwarding. Permission taxonomy mapping remains applied to the migrated users.
- The approved encrypted MongoDB-backed 12-hour session store is active and validated. Machine checks confirmed the `crm_prod.sessions` collection, its TTL index, and unchanged counts of 275 leads and 4 users; after an application-container restart, the owner refreshed the same authenticated browser page and confirmed the login persisted. Future CRM database archives exclude the ephemeral `sessions` collection so recovery intentionally requires a fresh login.
- The owner-reported login Enter-key fix is merged and deployed from CRM revision `1a8301bca2b4b57bd40a4847b0f83aaa40c6b341`. CI, deployment health, exact-revision, session TTL, and protected record-count checks passed; the owner signed in by pressing Enter and confirmed browser acceptance. Rollback remains `e7a9ddbf8e8e3b12ba187906484e813150a3490f`.
- Login-only rate limiting with 5 failed account-and-IP attempts and 25 failed IP-wide attempts per 15 minutes, plus compatible Helmet security headers, is deployed and validated. A dummy-account live test returned five `401` responses followed by `429` with rate-limit metadata; approved headers were present while HSTS and CSP remained absent on internal HTTP. Public/NPM/DNS/router work remains separately gated.
- CRM pull request #5 passed test/build/security and visual-regression CI and merged as deployed revision `55331b096fa64b7fde8d505cc9dd209935b6b5b7`. Machine checks reconfirmed the exact revision, health, MongoDB session TTL, 275 leads, and 4 users. Rollback remains `1a8301bca2b4b57bd40a4847b0f83aaa40c6b341`.
- The 15–128 Unicode-character policy for new credentials, local common-password rejection, self/last-admin protection, denied-action auditing, trusted-proxy audit IP correction, and generic browser errors are deployed and validated. Existing users were not force-reset; HSTS/CSP/public edge changes remain outside this canary.
- CRM pull request #6 passed 68 tests, build/security and visual-regression CI, and merged as deployed revision `dca592b946e1aad1b297c05d51cab58e7cac97c9`. Machine checks reconfirmed health, MongoDB session TTL, 275 leads, and 4 users; a live dummy path reconfirmed `401` followed by audited `429` without container audit errors. Rollback remains `55331b096fa64b7fde8d505cc9dd209935b6b5b7`.
- The owner confirmed on 2026-07-19 that no new data was entered in the Windows CRM after the validated migration. The current `crm_prod` copy therefore contains the latest source data known to the owner; no additional delta migration, Windows write freeze, or `crm_restore_test` rehearsal is required while that remains true. The cutover runbook is retained only as a contingency if the Windows source receives new writes or a future remigration is requested.
- Read-only migrated-workload validation found no current pilot stop condition. Both VMs had about 1.4 GB available memory, zero active swap use, 22% root-disk use, and low CPU load. The CRM container was healthy with zero error/fatal/exception matches in its latest 200 log lines; MongoDB was active with 14 current connections and 205 MB resident memory.
- The CRM has no document-attachment subsystem, filesystem upload path, persistent Docker volume, or GridFS collections. CSV import is read in the browser and submitted as text; therefore no separate uploaded-document migration is applicable to the current revision.
- The first encrypted off-host `crm_prod` archive was restored into isolated `crm_restore_test`. All seven application collections matched `crm_prod` by name, document count, and index count, including 275 leads and 4 users. MongoDB and CRM health remained normal, host/VM swap use remained zero, and the protected remote restore workspace was removed. `crm_prod` was not altered.
- The owner-approved cleanup removed only `crm_restore_test`, reducing it from seven collections to zero. The off-host archive was retained with its original SHA-256; MongoDB remained active and CRM health remained normal.
- The `crm01` application recovery path is documented and its current inputs are validated: GitHub `main` and the deployed checkout match the pinned revision, the CRM playbook passes syntax validation, `.env.production` remains `0600 root:root`, and the CRM container is healthy. A full destructive VM rebuild was not performed on the constrained host.
- CRM access/publication architecture review is complete. Persistent sessions, login rate limiting, and compatible security headers are validated; CSP/HSTS staging, compromised-password screening, audit/incident operations, and NPM/DNS/TLS/edge facts still block unrestricted public exposure. Internal-only remains the safe default; VPN-only is the recommended near-term remote option. Public HTTPS requires staged validation and separate owner approvals.
- The least-privilege Proxmox inspection path is provisioned and validated: dedicated `infra-audit@pve!codex` API token, built-in `PVEAuditor` role, privilege separation, token secret in macOS Keychain, and owner-verified pinned TLS certificate. Effective permissions contain audit privileges only; insecure TLS bypass and root SSH automation are not approved.
- The post-migration `pve01` observation reported Proxmox VE `9.2.4`, low CPU load, 8.22 GiB of 13.54 GiB API-reported usable memory in use, zero swap use, and 8.90% root-filesystem use. `local-lvm` was active with 48.02 GiB used and 745.77 GiB available. This point-in-time result had five production VMs running while `pbx01` and `mon01` were stopped; it does not approve the full target profile on the current 16 GB host.
- Hardware inventory confirmed an MSI `B450M-A PRO MAX II (MS-7C52)` motherboard with two DDR4 slots, both occupied by matching 8 GB DDR4-3200 non-ECC unbuffered DIMMs. MSI supports up to 64 GB on this board, and AMD specifies DDR4-3200 for the Ryzen 7 5700G. The current AMI `A.20` BIOS satisfies MSI's published Ryzen 7 5700G and 64 GB prerequisites, so a firmware update is not required solely for capacity support. MSI's old Ryzen 5000G QVL confirms two-DIMM operation for several 32 GB DDR4-2666 modules but does not list a 32 GB DDR4-3200 part. Kingston `KVR32N22D8/32` is a current JEDEC DDR4-3200 1.2 V candidate that matches the published electrical specification, but exact-board vendor confirmation and owner purchase approval remain pending.
- On 2026-07-19 the owner deferred all BIOS, RAM, and other hardware-upgrade work. The project must continue on the current hardware without further upgrade research, purchase preparation, firmware work, or hardware implementation until the owner explicitly reopens the subject. The existing capacity limits remain in force; this deferral does not approve VM resizing or the full 26 GB target allocation.
- The empty CRM canary database was reset once before migration and bootstrapped with the Vault-managed `Admin User` account for `admin@asalagroupbd.com`. The known repository fallback password was not used.

## Next approved implementation step

1. Continue CRM preparation on the current 16 GB host and retain the existing 2 vCPU / 2 GB / 32 GB allocations.
2. Treat the validated `crm_prod` dataset as the current latest migrated copy; do not repeat the Windows migration or create `crm_restore_test` unless the owner reports new source data.
3. The first off-host `crm_prod` archive is complete on the FileVault-enabled macOS control node: 13,322 bytes, mode `0600`, with matching remote/local SHA-256 `6b8d943368e068046624a45125a924b1ce8f258ef83c68d00fd73bcf99d152a0`; the `db01` temporary workspace was removed.
4. The isolated restore test is complete: archive SHA-256 and all collection, document, and index manifests matched; `crm_prod` remained unchanged.
5. Collect the owner-controlled FQDN, DNS provider, public-IP/CGNAT, and router facts before designing staged internal NPM/TLS validation. CSP migration, compromised-password screening, MFA direction, HSTS, secure cookies, and any public exposure remain separately gated. Hardware work remains deferred.
6. Review and approve or reject the documented internal NPM design choices:
   SQLite for the constrained single instance and
   `/opt/nginx-proxy-manager` persistence are approved, as is preparation of a
   dedicated non-deploying Ansible role. Docker-aware LAN-only TCP `81` and the
   service apply remain later separate approvals.
7. The layered NPM IPv4 firewall and Docker-restart persistence are validated,
   and explicit `192.168.10.106` binding for TCP `80`, `81`, and `443` is
   approved. NPM service start remains a separate approval.

## Supporting references

- [VM inventory](docs/VM-Inventory.md)
- [Network design](docs/Network-Design.md)
- [Capacity review](docs/Capacity-Review.md), [Proxmox read-only API](docs/Proxmox-Read-Only-API.md), [CRM pilot migration plan](docs/CRM-Migration-Plan.md), [CRM cutover runbook](docs/CRM-Cutover-Runbook.md), [CRM publication plan](docs/CRM-Publication-Plan.md), [database access policy](docs/Database-Access-Policy.md), [Storage](docs/Storage-Design.md), [security](docs/Security-Baseline.md), and [backup](docs/Backup-Strategy.md)
- [Monitoring](docs/Monitoring-Strategy.md), [deployment runbook](docs/Deployment-Runbook.md), [CRM recovery runbook](docs/CRM-Recovery-Runbook.md), and [disaster recovery](docs/Disaster-Recovery.md)
- [Architecture decisions](docs/ADR/) and [change history](docs/CHANGELOG.md)

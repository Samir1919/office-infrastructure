# Change Log

This is the durable history of completed and validated work. Planned work belongs in [PROJECT-ROADMAP.md](../PROJECT-ROADMAP.md).

## 2026-07-19 — CRM internal login session fix

### Implemented

- Updated the CRM canary to revision `ae9539ca575df9ffdafe047c49b20fff2473b858`, which makes session-cookie security explicitly configurable.
- Set `SESSION_COOKIE_SECURE=false` only for the internal HTTP canary, while preserving secure-cookie behaviour as the production default for future HTTPS publication.

### Validated

- CRM `/healthz` returned `200`; the Vault-managed admin completed CSRF-protected login and reached the authenticated dashboard over the internal HTTP canary.

## 2026-07-19 — CRM canary admin bootstrap

### Validated

- Reset the empty `crm_prod` canary database before any Windows data migration.
- Created the initial `Admin User` account for `admin@asalagroupbd.com` using a Vault-managed password also stored in the owner’s macOS Keychain.
- Confirmed CRM health status and authenticated MongoDB connection after the bootstrap.

## 2026-07-18 — Constrained CRM pilot preparation

### Approved

- A non-public, resource-constrained preparation pilot for `db01` MongoDB and `crm01` Node.js CRM.
- Retaining the existing 2 vCPU / 2 GB / 32 GB VM baseline during the pilot; no resource resize is approved.

### Documented

- Source-fact requirements and safe MongoDB migration approach for moving the Windows CRM data.
- Capacity monitoring and cutover boundaries that keep full Phase 5 and Phase 6 deployment pending.
- MongoDB `8.3.4` as the CRM pilot target and `crm_prod` as the new production database name.
- Confirmed Windows source mapping: MongoDB 7.0 database `realestate_crm` to `db01` MongoDB 8.3.4 database `crm_prod`.
- Approved a permanent least-privilege database-access standard, including per-application users, firewall rules, naming, and backup artifacts.
- Prepared an internal-only CRM canary design pinned to the GitHub revision containing the Node.js 24 LTS Docker runtime update.

### Validated

- MongoDB Community `8.3.4` installed on `db01` from the official repository.
- `mongod` is enabled and active with authentication enabled; MongoDB listens only on localhost and `db01`'s internal LAN address.
- Vault-managed administrative and `crm_app` credentials created; `crm_app` has `readWrite` access to `crm_prod` only.
- `db01` UFW enabled with default-deny incoming traffic, SSH allowed from the office server LAN, and MongoDB TCP `27017` allowed only from `crm01`.
- Internal CRM canary deployed on `crm01` from Git revision `997f4b8cf0bc3902da9beae5a26988e1280ad7df`; the Node.js `v24.18.0` container is healthy, returns `/healthz` status `200`, and connects to `crm_prod`.
- No Windows CRM data migration, Nginx Proxy Manager publication, public DNS, TLS certificate, or router forwarding was performed.

## 2026-07-18 — Remote administration and secure external access policy

### Added

- Approved remote administration architecture.
- VPN-first management policy.
- Reverse proxy as the single public ingress.
- Wake-on-LAN strategy for remote power management.
- Documentation for secure external access.

### Updated

- Rescheduled VPN-based remote administration and Wake-on-LAN implementation to Phase 5.1, after Phase 5 Nginx Proxy Manager and Phase 6 database deployment.


## 2026-07-17 — Repository and automation foundation

### Added

- Git repository and GitHub off-site backup.
- `AGENTS.md` AI operating manual and change-control rules.
- Documentation and ADR directory structure.
- Ansible YAML production inventory, baseline variables, playbook skeletons, and role directories.
- macOS Ansible control node using Homebrew Ansible 14.2.0 and Python 3.14.6.
- Passwordless SSH access for `sysadmin` on all production VMs.

### Validated

- `ansible all -m ping` succeeded for all seven production VMs.
- Target hosts use `/usr/bin/python3.12`.
- The `common.yml` playbook passed syntax validation and inventory graph validation.
- Encrypted Ansible Vault-based sudo credentials were configured locally for Ansible use.
- Approved the private-repository policy for versioning the encrypted Vault file; the Vault password remains in the macOS Keychain and outside Git.
- The common baseline was applied and validated on canary host `crm01`: timezone `Asia/Dhaka`, QEMU Guest Agent active, and `qemu-guest-agent` version `1:8.2.2+ds-0ubuntu1.17`.
- Following successful canary validation, the common baseline was applied to the remaining six production VMs and `common-base` snapshots were created for all production VMs.
- Docker Engine and Compose were applied and validated on canary host `crm01`, then rolled out to `web01`, `erp01`, and `npm01`; `docker-base` snapshots were created for all four Docker hosts.

### Corrected

- Renamed the common role task file from `main.ymal` to `main.yml`.
- Stopped tracking the generated Ansible collection directory; dependencies are reproduced through `requirements.yml`.

### Prepared

- Added a Proxmox host-capacity review with decision options and a recommended 48 GB minimum planning target; owner approval remains required before any resource change.

### Next step

- Complete the documented Proxmox host-capacity review before Phase 5 application deployment.

## Before 2026-07-17 — Infrastructure foundation

- Proxmox VE installed and validated on `pve01`.
- Ubuntu Server 24.04 LTS golden template created as VM900.
- VMs 101–107 created as full clones with static IPs, SSH, internet connectivity, QEMU Guest Agent, updates, and `base-config` snapshots.

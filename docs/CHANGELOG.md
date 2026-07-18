# Change Log

This is the durable history of completed and validated work. Planned work belongs in [PROJECT-ROADMAP.md](../PROJECT-ROADMAP.md).

## 2026-07-19 — Bilingual new-control-node guide

### Updated

- Added a complete Bengali version beside the existing English new-control-node installation and Vault-recovery guide.
- Added language navigation inside the same guide; no competing installation file was created.
- Updated the root README link to identify the guide as English and Bengali.

## 2026-07-19 — Vault recovery installation guidance

### Added

- Added a prominent new-Mac recovery section explaining that GitHub contains encrypted Vault files but not the single decryption password.
- Documented recovery from the old Mac Keychain, an approved secondary Google Password Manager entry, or a future encrypted offline copy.
- Added safe Keychain recreation plus no-output checks for the whole-file Vault and inline `!vault` values.
- Added stop conditions prohibiting a new password, Vault overwrite, plaintext notes, chat/email storage, screenshots, or CSV export when recovery is unavailable.

## 2026-07-19 — CRM HTTPS publication architecture review

### Reviewed

- Compared internal-only, VPN-only, public NPM/HTTPS, and external tunnel access paths against the approved network architecture.
- Confirmed the pinned CRM revision sets one-hop proxy trust in production, supports secure cookies, and applies CSRF protection.
- Identified the default in-memory session store plus missing documented login rate limiting, security-header middleware, and MFA as public-exposure risks.

### Prepared

- Added application-hardening gates, session-store alternatives, NPM/DNS/TLS/router prerequisites, staged internal/public validation, rollback, and owner decisions.
- Recommended VPN-only for near-term remote access and MongoDB-backed sessions if the owner later approves public HTTPS implementation planning.
- No DNS, NPM service, proxy host, certificate, router, CRM runtime, database, VM resource, or hardware change was performed.

## 2026-07-19 — CRM application recovery runbook

### Prepared

- Added a rebuild sequence for VM101 using the approved VM identity, common baseline, Docker automation, pinned CRM revision, and Vault-rendered environment.
- Added an explicit prohibition on the historical `crm_reset_canary_database=true` option during recovery.
- Added recovery validation, failure handling, internal-only boundaries, and separation between rebuildable `crm01` state and authoritative `crm_prod` data.

### Validated

- Confirmed GitHub `main` and the root-owned deployed checkout resolve to `ae9539ca575df9ffdafe047c49b20fff2473b858`.
- Confirmed CRM playbook syntax, `.env.production` mode `0600` with root ownership, and a healthy running CRM container.
- No VM rebuild, application deployment, database change, public publication, VM resize, or hardware change was performed.

## 2026-07-19 — CRM restore-test cleanup prepared

### Approved

- Remove only the validated temporary `crm_restore_test` database while retaining `crm_prod` and the verified off-host archive.

### Prepared

- Added a cleanup playbook with exact host/database guards, a pre-delete existence check, and a required zero collection count after deletion.

### Implemented and validated

- Removed only `crm_restore_test`; its collection count changed from seven to zero.
- Retained `crm_prod` and the verified off-host archive; the archive SHA-256 remained `6b8d943368e068046624a45125a924b1ce8f258ef83c68d00fd73bcf99d152a0`.
- Confirmed `mongod` remained active and the CRM health endpoint returned `{"status":"ok"}` after cleanup.

## 2026-07-19 — CRM isolated restore test prepared

### Approved

- Restore the verified off-host `crm_prod` archive into isolated database `crm_restore_test` without altering `crm_prod`.
- Retain the test database after validation; cleanup remains separately approval-gated.

### Prepared

- Added a Vault-backed restore-test playbook with local/remote archive checksum validation and protected temporary files.
- Added a hard stop when `crm_restore_test` already contains collections and excluded `--drop` from the procedure.
- Added parity checks for sorted collection names, document counts, and index counts between `crm_prod` and the restored database.

### Implemented and validated

- Restored the verified archive into isolated `crm_restore_test` without using `--drop` or changing `crm_prod`.
- Matched all seven collection manifests exactly: `auditlogs` 7/4, `leadcounters` 1/1, `leads` 275/6, `permissions` 17/2, `roles` 3/2, `tasks` 0/1, and `users` 4/2, shown as documents/indexes.
- Revalidated archive SHA-256 `6b8d943368e068046624a45125a924b1ce8f258ef83c68d00fd73bcf99d152a0` after upload and removed the protected temporary workspace.
- Confirmed `mongod` active, `db01` with 1,429 MB available memory and zero swap use, CRM `/healthz` status `200`, and healthy audit-only host capacity evidence after restore.
- Retained `crm_restore_test` pending separate cleanup approval.

## 2026-07-19 — CRM off-host backup automation prepared

### Approved

- Proceed with backup protection for the current `crm_prod` dataset using the FileVault-enabled owner macOS control node as the interim off-host destination.

### Prepared

- Added a Vault-backed Ansible playbook that creates a compressed archive without putting the MongoDB password on the command line.
- Enforced an explicit destination outside Git, owner-only directory/archive permissions, remote/local size and SHA-256 validation, and cleanup of the remote temporary credential and archive workspace.
- Restore execution and archive deletion remain separately approval-gated.

### Implemented and validated

- Created `db01_crm_prod_20260719T023102.archive.gz` from `crm_prod` with MongoDB Database Tools `100.17.0` and transferred it to the FileVault-enabled control node.
- Validated a 13,322-byte archive with matching remote/local SHA-256 `6b8d943368e068046624a45125a924b1ce8f258ef83c68d00fd73bcf99d152a0`.
- Confirmed the local archive is owned by `samir` with mode `0600`, and the destination directory is owner-only.
- Confirmed failure-path and successful-run cleanup removed the protected temporary credential/archive workspace from `db01`.
- No database content, CRM service, VM allocation, public access, or hardware configuration was changed; restore recoverability remains untested.

## 2026-07-19 — Additional CRM remigration deferred

### Owner confirmation

- Confirmed that no new data was entered in the Windows CRM after the validated copy to `crm_prod`.
- Accepted that no delta migration, Windows write freeze, or `crm_restore_test` rehearsal is currently required.
- Retained the cutover runbook only as a contingency if Windows writes resume or the owner requests remigration.
- Kept backup protection for the current `crm_prod` dataset and any future public publication as separate approval-gated work.

## 2026-07-19 — CRM cutover and rollback runbook prepared

### Prepared

- Added explicit approval gates for restore rehearsal, production cutover, user release, and future public publication.
- Compared waiting for independent backup storage with a temporary encrypted off-host copy on the owner's macOS control node; same-host-only backup is prohibited.
- Validated that the macOS control node has FileVault enabled and 292 GiB available on its 460 GiB data volume; exact destination permissions, archive size, and owner approval remain pending.
- Documented preflight thresholds, checksum validation, a temporary `crm_restore_test` rehearsal, final write freeze, target rollback archive, owner-only validation, and data-divergence-safe rollback.
- Identified the repeatable permission-taxonomy mapping procedure and owner approval of the interim backup destination as rehearsal prerequisites.
- No database restore, source write freeze, production cutover, user release, public publication, VM resize, or hardware change was performed.

## 2026-07-19 — Hardware-upgrade work deferred

### Owner decision

- Deferred all BIOS, RAM, and other hardware-upgrade work until the owner explicitly reopens the subject.
- Directed the project to continue on the current 16 GB hardware without further upgrade research, purchase preparation, firmware work, or hardware implementation.
- Retained the existing VM allocations and capacity stop conditions; no VM resize, production cutover, or public CRM publication was approved by this decision.

### Updated

- Replaced the hardware-purchase workflow in the roadmap with current-hardware CRM cutover, backup, rollback, and monitoring preparation.
- Closed the previously stale Proxmox host-evidence item in the CRM migration plan using the validated audit-only API results.

## 2026-07-19 — Proxmox BIOS and memory qualification

### Validated

- Recorded the current `pve01` AMI BIOS as `A.20` and confirmed that it satisfies MSI's published Ryzen 7 5700G and 64 GB prerequisites.
- Identified stable MSI firmware `7C52vA5` as an optional separate maintenance decision; no BIOS update was approved or performed.
- Confirmed MSI's Ryzen 5000G QVL includes two-DIMM support for several 32 GB DDR4-2666 modules, while its old list does not provide an exact 32 GB DDR4-3200 match.
- Documented Kingston `KVR32N22D8/32` as a current JEDEC DDR4-3200 1.2 V candidate whose exact-board support still requires seller/manufacturer confirmation and a return option before purchase approval.
- No BIOS, hardware, VM resource, or production configuration change was performed.

## 2026-07-19 — Proxmox memory hardware inventory

### Validated

- Identified the `pve01` motherboard as MSI `B450M-A PRO MAX II (MS-7C52)`, revision 2.0.
- Confirmed both available DDR4 slots are occupied by matching 8 GB DDR4-3200 non-ECC unbuffered 1.2 V DIMMs, for 16 GB total.
- Verified MSI's official 64 GB board maximum and AMD's DDR4-3200 specification for the Ryzen 7 5700G.
- Documented a matched 2 × 32 GB DDR4-3200 kit as the recommended practical target; BIOS version, exact kit compatibility, owner purchase approval, and maintenance window remain pending.
- No hardware, BIOS, VM resource, or production configuration change was performed.

## 2026-07-19 — Proxmox read-only API access design

### Approved

- Dedicated `infra-audit@pve` user and privilege-separated `codex` API token with the built-in `PVEAuditor` role only.
- Token-secret storage in the owner control node's macOS Keychain and owner-verified TLS certificate pinning; insecure TLS bypass and root SSH automation remain prohibited.

### Implemented

- Added the provisioning, validation, rotation, and rollback runbook.
- Added certificate-fingerprint verification, Keychain token retrieval, and sanitized read-only health-query scripts.
- Owner-verified and pinned the `pve01.local` TLS certificate, created the privilege-separated audit identity, and stored the token secret in macOS Keychain.

### Validated

- Confirmed the API token exposes audit privileges only and no modify or administration privilege.
- Retrieved Proxmox VE `9.2.4`, node health, `local-lvm` capacity, and VM resource status over verified TLS.
- Recorded 8.22 GiB of 13.54 GiB API-reported usable host memory in use, zero swap use, low CPU load, and 8.90% root-filesystem use.
- Confirmed `local-lvm` was active with 48.02 GiB used and 745.77 GiB available out of 793.80 GiB total.
- No VM, storage, network, or application configuration was changed during API validation.

## 2026-07-19 — CRM test data migration validation

### Implemented

- Copied the Windows MongoDB `realestate_crm` data into `db01` database `crm_prod` as a test migration; the Windows source remained unchanged.
- Applied the CRM permission taxonomy mapping to the migrated users.

### Validated

- Confirmed 275 leads and 4 users in the migrated CRM data.
- The owner refreshed the browser and confirmed that the CRM operated normally with no visible problem.
- Recorded point-in-time migrated-workload evidence: both `crm01` and `db01` had about 1.4 GB available memory, zero active swap use, 22% root-disk use, and low CPU load.
- Confirmed the CRM container was healthy, `/healthz` returned `200`, container memory use was 46.28 MiB, and its latest 200 application log lines contained no `error`, `fatal`, or `exception` match.
- Confirmed `mongod` was active on MongoDB `8.3.4`, with 14 current connections and 205 MB resident memory; 275 leads and 4 users were reconfirmed.
- Confirmed the current CRM revision has no document-attachment backend, persistent upload volume, or GridFS collections. CSV import is browser-read text and requires no separate uploaded-file migration.
- Completed the previously pending `pve01` host/LVM-Thin evidence through the separately approved, certificate-verified, audit-only API path.
- No production cutover, public DNS, Nginx Proxy Manager publication, TLS certificate, or router forwarding was performed.

## 2026-07-19 — Application container timezone standard

### Implemented

- Added the project `Asia/Dhaka` timezone explicitly to the CRM application container environment.
- Documented the standard that every future Docker application service must receive the project timezone explicitly.

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

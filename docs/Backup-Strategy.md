# Backup Strategy

## Current state

No independent backup server is deployed. Proxmox snapshots, including `base-config`, are not backups.

## Target design

| Data | Method | Destination | Frequency |
|---|---|---|---|
| VM backups | Proxmox backup job | Future TrueNAS / backup storage | Nightly |
| MongoDB | `mongodump` | Future TrueNAS | Daily |
| PostgreSQL | `pg_dump` | Future TrueNAS | Daily |
| Application files and volumes | Service-aware backup | Future TrueNAS | Defined per service |

The backup phase is complete only after a successful documented restore test.

## CRM interim cutover protection

The owner has deferred new hardware work, so the future TrueNAS target is unavailable for the current CRM preparation. The preferred interim option is a manually controlled, encrypted off-host copy on the owner's macOS control node, provided disk encryption, access control, free space, checksum verification, and a restore rehearsal are validated first. This is not a permanent backup service and requires owner approval before use. A database archive kept only on `db01` or Proxmox local storage is prohibited as the sole backup.

The detailed approval, rehearsal, cutover, retention, and rollback workflow is in the [CRM Production Cutover Runbook](CRM-Cutover-Runbook.md).

## CRM current-database backup

On 2026-07-19 the owner approved proceeding with backup protection for the current `crm_prod` dataset on existing hardware. The approved interim destination is the FileVault-enabled macOS control node; it is an off-host manual protection layer, not the final scheduled backup architecture.

The Ansible playbook `ansible/playbooks/mongodb-backup.yml`:

- accepts an explicit absolute destination outside Git;
- creates a compressed MongoDB archive using a root-only temporary credential file rather than a password-bearing command line;
- fetches the archive to an owner-only directory on the encrypted control node;
- validates non-zero size and matching SHA-256 on `db01` and the control node; and
- removes the remote temporary archive and credential workspace after the transfer attempt.

The ephemeral `crm_prod.sessions` collection is excluded from new archives.
It contains encrypted login state rather than authoritative CRM records, has a
12-hour TTL, and must not be restored during application recovery. A restored
CRM starts with no active sessions, so all users must authenticate again. The
first verified archive predates the session-store deployment and is unchanged.

Run from `ansible/` with the Keychain-backed Vault password:

```bash
ANSIBLE_VAULT_PASSWORD_FILE=../scripts/ansible-vault-keychain.sh \
ansible-playbook playbooks/mongodb-backup.yml \
  --limit db01 \
  -e mongodb_backup_controller_root=/Users/samir/Backups/office-infrastructure/mongodb
```

The destination directory must remain mode `0700`, each archive mode `0600`, and backup artifacts must never be committed. A successful archive and checksum transfer proves backup creation, but not recoverability; a restore test remains required before the backup phase can be considered complete.

MongoDB recommends the `--config` file for sensitive `mongodump` values because a command-line password may be visible to system-status tools. The playbook follows that guidance with a temporary root-only file. See the [official `mongodump` documentation](https://www.mongodb.com/docs/database-tools/mongodump/).

### First verified archive — 2026-07-19

| Evidence | Result |
|---|---|
| Database | `crm_prod` |
| Tool | MongoDB Database Tools `mongodump 100.17.0` |
| Archive | `db01_crm_prod_20260719T023102.archive.gz` |
| Destination | `/Users/samir/Backups/office-infrastructure/mongodb/` on the FileVault-enabled control node |
| Size | 13,322 bytes |
| SHA-256 | `6b8d943368e068046624a45125a924b1ce8f258ef83c68d00fd73bcf99d152a0` |
| Permissions | Directory `0700`; archive `0600`, owned by `samir` |
| Transfer validation | Remote and off-host size and SHA-256 matched |
| Remote cleanup | Temporary credential and archive workspace removed; no matching workspace remained in `/var/tmp` |

The archive was created without modifying `crm_prod`. Its existence and checksum are validated; restore recoverability is not yet validated.

## CRM restore-test procedure

The owner approved an isolated restore test on 2026-07-19. `ansible/playbooks/mongodb-restore-test.yml` uploads an explicitly selected off-host archive to a protected temporary workspace on `db01`, confirms its SHA-256, refuses to continue if `crm_restore_test` already contains any collection, and restores only from `crm_prod.*` to `crm_restore_test.*`. It then compares the sorted collection names, document counts, and index counts between `crm_prod` and `crm_restore_test`.

The playbook does not use `--drop`, does not target `crm_prod`, removes the temporary credential/archive workspace, and deliberately retains `crm_restore_test` after validation. Deleting that test database requires separate owner approval.

```bash
ANSIBLE_VAULT_PASSWORD_FILE=../scripts/ansible-vault-keychain.sh \
ansible-playbook playbooks/mongodb-restore-test.yml \
  --limit db01 \
  -e mongodb_restore_controller_archive=/Users/samir/Backups/office-infrastructure/mongodb/db01_crm_prod_20260719T023102.archive.gz
```

The namespace-remapping design follows MongoDB's documented `--archive`, `--gzip`, `--nsInclude`, `--nsFrom`, `--nsTo`, and `--stopOnError` behaviour. See the [official `mongorestore` documentation](https://www.mongodb.com/docs/database-tools/mongorestore/).

### First restore-test evidence — 2026-07-19

The verified archive was restored successfully into `crm_restore_test`. The source and restored manifests matched exactly:

| Collection | Documents | Indexes |
|---|---:|---:|
| `auditlogs` | 7 | 4 |
| `leadcounters` | 1 | 1 |
| `leads` | 275 | 6 |
| `permissions` | 17 | 2 |
| `roles` | 3 | 2 |
| `tasks` | 0 | 1 |
| `users` | 4 | 2 |

Archive SHA-256 remained `6b8d943368e068046624a45125a924b1ce8f258ef83c68d00fd73bcf99d152a0` after upload. The protected remote workspace was removed. `mongod` remained active; `db01` reported 1,429 MB available memory and zero swap use; the CRM `/healthz` endpoint returned `200`. The audit-only Proxmox check reported 5.57 GiB of 13.54 GiB usable host memory used, zero swap use, low load, and 745.53 GiB available on `local-lvm`. Only `crm01` and `db01` were running during this point-in-time observation.

This proves that the first archive can be restored with collection, document, and index parity. `crm_restore_test` is retained pending separate cleanup approval; `crm_prod` was not changed.

## Restore-test cleanup

On 2026-07-19 the owner approved removing the validated temporary `crm_restore_test` database. The cleanup playbook `ansible/playbooks/mongodb-restore-test-cleanup.yml` has hard guards for `db01`, exact target `crm_restore_test`, and protected source `crm_prod`. It refuses cleanup if the test database is absent or empty, drops only the exact test database, and requires a zero collection count afterward. The verified off-host archive is not deleted.

Cleanup completed successfully: `crm_restore_test` had seven collections before deletion and zero afterward. `mongod` remained active, the CRM health endpoint returned `{"status":"ok"}`, and the retained archive still matched SHA-256 `6b8d943368e068046624a45125a924b1ce8f258ef83c68d00fd73bcf99d152a0`.

# CRM Production Cutover Runbook

**Status:** Prepared for review; rehearsal and production cutover are not approved
**Scope:** Internal CRM transition from the Windows MongoDB `realestate_crm` source to `crm01` and `db01` on the current 16 GB `pve01` host
**Out of scope:** Public DNS, Nginx Proxy Manager publication, Internet exposure, VM resizing, hardware work, and deletion of the Windows source

## Safety model

- The Windows CRM and its database remain the authoritative source until the owner accepts final validation.
- A final migration requires a confirmed maintenance window and a complete application write freeze.
- Never restore directly over `crm_prod` without first creating and verifying a rollback archive of its current state.
- A local Proxmox snapshot or an archive on the same NVMe is a rollback aid, not an independent backup.
- Database archives contain business and personal data. Keep them outside Git and only on encrypted storage with owner-controlled access.
- No command in this runbook authorizes production execution. Each execution or destructive step requires the approval gate below.

## Current design and temporary backup decision

The target design sends MongoDB backups to a future independent TrueNAS/backup system. That storage does not yet exist.

| Option | Benefit | Risk / impact | Decision |
|---|---|---|---|
| Wait for independent backup storage | Matches the target architecture and provides the strongest separation | Blocks production cutover on current hardware | Available; not selected |
| Temporary encrypted off-host copy on the owner's macOS control node | Permits a restore rehearsal and controlled internal cutover without new server hardware | Not a permanent backup service; depends on verified disk encryption, free space, checksum validation, and manual retention | Recommended interim option; owner approval pending |
| Keep backup only on `db01` or Proxmox local storage | Simple | Same-host failure can destroy runtime and backup together | Prohibited |

Before using the interim option, verify that FileVault or an equivalent encrypted destination is active, the owner account alone can read the backup directory, and available space is at least three times the final compressed archive size. Record the destination without recording secrets.

### Control-node storage validation — 2026-07-19

The owner macOS control node reports FileVault enabled. Its data volume has 292 GiB available of 460 GiB. Encryption and gross free-space prerequisites therefore pass; the final archive size, exact owner-only destination permissions, checksum workflow, and owner approval must still be validated before creating any CRM backup artifact.

## Approval gates

Separate owner approval is required for each gate:

1. **Rehearsal approval:** create encrypted off-host test artifacts and restore into a temporary database such as `crm_restore_test`; do not alter `crm_prod`.
2. **Cutover approval:** freeze Windows writes, replace the test-loaded contents of `crm_prod` using the final archive, apply the permission mapping, and validate with owner-only access.
3. **User-release approval:** allow normal users to write to the new CRM after the owner accepts validation.
4. **Publication approval:** any future Nginx Proxy Manager, DNS, TLS, or router change remains a different project step.

## Required preflight record

Record the following immediately before a rehearsal or approved cutover:

| Check | Go condition |
|---|---|
| Windows source | MongoDB 7.0 healthy; `realestate_crm` accessible; owner confirms who can freeze writes |
| Source baseline | Collection list, document counts, index list, 275-lead/4-user baseline updated for any newer production data |
| Permission mapping | Repeatable mapping procedure reviewed and ready; never rely on an undocumented manual edit |
| Target services | `mongod` active; CRM container healthy; `/healthz` returns `200` |
| Host pressure | No active swap pressure; low sustained CPU; no Proxmox alert |
| VM pressure | `crm01` and `db01` each have at least 512 MB available memory and no active swap use |
| Storage | `db01` root below 80% used and `local-lvm` has at least 100 GiB available |
| Off-host backup | Encrypted destination verified; free space adequate; owner access confirmed |
| Maintenance | Start time, owner, operators, expected outage, and abort time recorded |

Any failed check is a no-go. Do not compensate by resizing a VM or changing hardware.

## Rehearsal procedure

The rehearsal proves that the archive is readable without changing `crm_prod`.

1. Create a timestamped compressed `mongodump` archive of the Windows source while normal use continues; this is rehearsal data only.
2. Calculate SHA-256 on the source archive, copy it through the trusted office LAN to the encrypted off-host destination, and confirm the checksum after transfer.
3. Transfer a working copy to `db01` over SSH. Keep the verified off-host copy unchanged.
4. Restore with namespace remapping from `realestate_crm.*` to temporary `crm_restore_test.*`; never use `--drop` against `crm_prod` during rehearsal.
5. Compare collections, document counts, indexes, representative lead records, and all four migrated user records with the source baseline.
6. Record archive size, dump time, transfer time, restore time, checksum, and resource observations. Do not record credentials or business data values.
7. Drop `crm_restore_test` only after the owner reviews the evidence and separately approves cleanup.

Command shape, with secrets and paths supplied at execution time from approved secret storage:

```bash
mongodump --uri="mongodb://localhost:27017/realestate_crm" \
  --archive="<encrypted-or-controlled-path>/windows_realestate_crm_<timestamp>.archive.gz" \
  --gzip

shasum -a 256 "<archive>"

mongorestore \
  --uri="mongodb://<admin-user>:<secret>@localhost:27017/?authSource=admin" \
  --nsFrom="realestate_crm.*" --nsTo="crm_restore_test.*" \
  --archive="<archive>" --gzip
```

Do not put a URI containing a password in shell history. At execution time use an approved protected configuration/password-file mechanism and redact command evidence.

## Approved-cutover procedure

1. Confirm all preflight checks and obtain explicit cutover approval.
2. Block user access to the new CRM and stop all application writes on the Windows CRM. Record the write-freeze time.
3. Create the final Windows archive, calculate its SHA-256, copy it to the encrypted off-host destination, and verify the checksum.
4. Create a separate rollback archive of the current `db01` `crm_prod`; copy it off-host and verify its checksum.
5. Reconfirm both verified archives exist before changing `crm_prod`.
6. Restore the final source archive into `crm_prod` with namespace remapping and the approved replacement method. This is destructive to the test-loaded target data and must not begin without the recorded approval.
7. Apply the reviewed, repeatable permission-taxonomy mapping to the final migrated users.
8. Start or reload the CRM with the existing Vault-managed `crm_app` connection. Do not change VM resources.
9. With owner-only access, validate health, login, permissions, lead counts, representative reads, one controlled create/update test, logs, MongoDB health, host pressure, and VM pressure.
10. Keep both systems write-frozen until the owner accepts the evidence and grants user-release approval.
11. After user release, retain the Windows source unchanged and offline/read-only for the owner-approved retention period.

## Validation record

| Evidence | Pass condition |
|---|---|
| Archive integrity | SHA-256 matches at source, off-host destination, and restore host |
| Database structure | Expected collections and indexes present |
| Data | Source and target counts match the final baseline |
| Users and permissions | All users present; mapped roles behave as expected |
| Application | `/healthz` 200; authenticated login; representative lead read; controlled write succeeds |
| Logs | No new error, fatal, authentication, or database-connection failures |
| Capacity | No stop condition from the preflight thresholds or sustained degradation |
| Owner acceptance | Explicitly recorded before releasing users |

## Abort and rollback

Before user release, rollback is simple because both systems remain write-frozen:

1. Stop access to the new CRM.
2. Restore the verified pre-cutover `crm_prod` rollback archive if the canary state is needed.
3. Return users to the unchanged Windows CRM.
4. Record the failure evidence and keep all verified archives for investigation.

After users have written to the new CRM, immediately returning to Windows can lose or fork new data. In that case:

1. Freeze writes on the new CRM immediately.
2. Create and verify an emergency archive of its current state.
3. Do not reopen either system until the owner chooses a documented reconciliation path.
4. Treat reverse migration or manual reconciliation as a new approved change; never overwrite either side to force a quick rollback.

## Retention and cleanup

- Keep the Windows source unchanged until the owner approves retirement after a stable observation period.
- Retain the final source archive, pre-cutover target archive, and first post-cutover archive on encrypted off-host storage.
- Define the interim retention period during cutover approval; no archive is deleted automatically.
- Temporary databases and working copies require explicit cleanup approval after checksums and restore evidence are accepted.
- This interim process does not complete the project backup phase; independent backup storage and a scheduled restore-tested job remain pending.

## Prepared status

The procedure, gates, validation evidence, and rollback boundaries are documented. FileVault and 292 GiB of available control-node storage are validated. Execution remains blocked on owner selection of the interim backup option, validation of the exact destination permissions and final archive size, a repeatable permission-taxonomy mapping procedure, and separate rehearsal approval.

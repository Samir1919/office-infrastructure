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

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

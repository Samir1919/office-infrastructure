# ADR-006: Snapshot Policy

- **Status:** Accepted
- **Date:** 2026-07-17

Take Proxmox snapshots before material deployment or upgrade work. Approved names are `base-config`, `common-base`, `docker-base`, `crm-installed`, `db-installed`, `pre-upgrade`, and `pre-major-change`. Snapshots provide rollback only; they are not backups.

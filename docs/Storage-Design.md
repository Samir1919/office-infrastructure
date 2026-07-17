# Storage Design

## Current state

| Component | Design |
|---|---|
| Proxmox local storage | 1 TB NVMe SSD using LVM-Thin |
| VM disks | Initial 32 GB virtual disk per VM |
| Independent backup storage | Not yet deployed |

Local NVMe is runtime storage, not a backup. Snapshots are rollback points only. A future separate TrueNAS/backup machine will provide RAID-backed VM, database, and file backup storage.

# VM Inventory

| VM ID | Hostname | IP address | Role | Base resources | State |
|---:|---|---|---|---|---|
| 101 | `crm01` | `192.168.10.101` | CRM | 2 vCPU / 2 GB / 32 GB | Running |
| 102 | `db01` | `192.168.10.102` | Central database | 2 vCPU / 2 GB / 32 GB | Running |
| 103 | `pbx01` | `192.168.10.103` | FreePBX | 2 vCPU / 2 GB / 32 GB | Running |
| 104 | `web01` | `192.168.10.104` | Company website | 2 vCPU / 2 GB / 32 GB | Running |
| 105 | `erp01` | `192.168.10.105` | ERP | 2 vCPU / 2 GB / 32 GB | Running |
| 106 | `npm01` | `192.168.10.106` | Nginx Proxy Manager | 2 vCPU / 2 GB / 32 GB | Running |
| 107 | `mon01` | `192.168.10.107` | Monitoring | 2 vCPU / 2 GB / 32 GB | Running |
| 900 | `ubuntu24-template` | N/A | Ubuntu golden template | 2 vCPU / 2 GB / 32 GB | Template |

All production VMs are full clones of VM900 using Ubuntu Server 24.04 LTS, UEFI/OVMF, q35, VirtIO devices, QEMU Guest Agent, static IP configuration, and the `base-config` snapshot. The listed resources are baseline allocations, not final service capacity.

# Network Design

## Current network

| Item | Value |
|---|---|
| Server LAN | `192.168.10.0/24` |
| Proxmox host | `pve01` — `192.168.10.95` |
| VM addressing rule | VM ID equals final IP octet |
| Server addresses | `.101` through `.107` |

The current deployment uses one LAN. VLANs and firewall segmentation are future work, not current implementation.

## Future VLAN direction

| VLAN | Intended use | Status |
|---:|---|---|
| 10 | Servers | Future |
| 20 | Office PCs | Future |
| 30 | Guest Wi-Fi | Future |
| 40 | VoIP | Future |

## Reverse-proxy flow

Internet → future firewall/edge device → Nginx Proxy Manager on `npm01` → application VM. No DNS, TLS, public exposure, or firewall rule is currently recorded as deployed.

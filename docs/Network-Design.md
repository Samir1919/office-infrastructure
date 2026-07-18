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

## Approved external access model

### Public application traffic

```text
Internet
    │
Public IP
    │
Router
    │
TCP 80 / 443 only
    │
npm01 (Reverse Proxy)
    │
CRM / ERP / Website
```

### Administrative access

```text
Internet
    │
VPN
    │
Internal LAN
    │
Proxmox
All VMs
SSH
```

### Wake-on-LAN

```text
Internet
    │
VPN
    │
Always-on LAN device
    │
Wake-on-LAN
    │
pve01
```

- No VM receives individual router port forwarding.
- Reverse proxy is the single public entry point.
- Future firewall (OPNsense/pfSense) will replace direct router exposure without changing internal architecture.

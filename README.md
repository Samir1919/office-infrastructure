# Office Infrastructure Project

Enterprise Office Infrastructure built on Proxmox VE using Infrastructure as Code (IaC).

---

## Project Status

| Phase | Status |
|--------|--------|
| Infrastructure Foundation | ✅ Completed |
| Automation Foundation | ✅ Completed |
| Docker Deployment | ⏳ Pending |
| CRM Deployment | ⏳ Pending |
| Database Deployment | ⏳ Pending |
| Monitoring | ⏳ Pending |
| Backup | ⏳ Pending |
| Production Hardening | ⏳ Pending |

---

## Infrastructure

### Proxmox Host

| Item | Value |
|------|-------|
| Hostname | pve01 |
| CPU | AMD Ryzen 7 5700G |
| RAM | 16 GB |
| Storage | 1 TB NVMe |
| Network | 192.168.10.0/24 |

---

## Production Virtual Machines

| VM ID | Hostname | IP | Role |
|------:|----------|------------|----------|
|101|crm01|192.168.10.101|CRM|
|102|db01|192.168.10.102|Database|
|103|pbx01|192.168.10.103|FreePBX|
|104|web01|192.168.10.104|Website|
|105|erp01|192.168.10.105|ERP|
|106|npm01|192.168.10.106|Nginx Proxy Manager|
|107|mon01|192.168.10.107|Monitoring|

---

## Project Standards

- Ubuntu Server 24.04 LTS
- VM ID = Last IP Octet
- Full Clone Only
- Snapshot before major deployment
- Infrastructure as Code (Ansible)
- Git Version Control

---

## Repository Structure

# Disaster Recovery

Formal disaster recovery is pending because independent backup storage and restore testing are not yet implemented.

Recovery order: restore Proxmox capability → backup storage access → `db01` and database integrity → application VMs and reverse proxy → PBX and monitoring → DNS/TLS/application validation.

CRM application recovery follows the [CRM Application Recovery Runbook](CRM-Recovery-Runbook.md). Database recovery remains a separate earlier step because `crm01` is rebuildable application state while `crm_prod` is authoritative business data.

Future deliverables: RPO/RTO targets, host/VM/database restore runbooks, regular restore testing, and recorded results.

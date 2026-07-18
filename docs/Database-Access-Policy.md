# Database Access Policy

**Status:** Approved permanent standard  
**Scope:** `db01`, current CRM pilot, and all future office application databases

## Purpose

`db01` is the central database host. Database access follows a least-privilege, per-application model: a service may reach only its own database service and use only its own database account. The standard remains the same when future application VMs are deployed; only that application's approved rule and account are added.

## Permanent access standard

1. Database ports are never exposed to the Internet or router port-forwarded.
2. Every database service has authentication enabled.
3. Every application receives a separate database user; shared application credentials are not allowed.
4. Every application user receives permissions only for its own production database.
5. A host firewall uses default-deny inbound policy and allows a database port only from approved application VM IPs.
6. Database names use `<application>_<environment>`; examples are `crm_prod`, `crm_dev`, and `crm_staging`.
7. Database backup artifact names include both database host and database name; for example `db01_crm_prod_YYYY-MM-DD.archive.gz`.
8. A future firewall/VLAN design may strengthen segmentation, but it must preserve this per-application access model.

## Approved CRM rule

| Item | Approved value |
|---|---|
| Database host | `db01` (`192.168.10.102`) |
| Application host | `crm01` (`192.168.10.101`) |
| Database port | TCP `27017` |
| Production database | `crm_prod` |
| Application user | `crm_app` |
| Network permission | Allow only `crm01` → `db01:27017` |
| Database permission | `readWrite` on `crm_prod` only |
| Administrative user | Separate Vault-managed account; never used by the CRM application |

## Future service onboarding

When an application needs a database, do not broaden an existing rule. Add an explicit, reviewed entry following this pattern:

| Application host | Database | Application user | Firewall permission |
|---|---|---|---|
| `erp01` | `erp_prod` | `erp_app` | `erp01` → `db01:27017` only |
| Future application VM | `<app>_prod` | `<app>_app` | That VM → its required database port only |

The service deployment change must include documentation, Vault-managed credentials, an idempotent Ansible configuration, validation, and a snapshot where applicable.

## Firewall baseline on `db01`

The approved enforcement baseline is:

- Default incoming traffic: deny.
- SSH TCP `22`: allow only from the office server LAN `192.168.10.0/24`.
- MongoDB TCP `27017`: allow only from explicitly approved application VM IPs.
- Outgoing traffic: allow unless a later approved policy changes it.

The `db01` firewall baseline is active. SSH TCP `22` is allowed from `192.168.10.0/24`, and MongoDB TCP `27017` is allowed only from `crm01` (`192.168.10.101`). MongoDB listens on localhost and `db01`'s server-LAN address; no public database exposure exists.

## Credential handling

- Store MongoDB administrative and application passwords only in encrypted Ansible Vault or an approved secret manager.
- Never put passwords in Git, Compose files, `.env` files that are committed, screenshots, or chat output.
- Rotate an affected application's user credential independently if that application or its VM is compromised.

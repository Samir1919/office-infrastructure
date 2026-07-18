# CRM Application Recovery Runbook

**Status:** Recovery procedure prepared and current inputs validated; destructive rebuild rehearsal not performed
**Scope:** Rebuild `crm01` application service while preserving `db01` `crm_prod`
**Out of scope:** Database restore, public publication, VM resize, hardware changes, and deletion of the failed VM

## Recovery model

The CRM's business data lives in `db01` database `crm_prod`, whose off-host backup and restore test are validated. `crm01` contains rebuildable application state:

- source from private Git repository `Samir1919/realestate-crm`;
- pinned revision `ae9539ca575df9ffdafe047c49b20fff2473b858`;
- Docker Engine and Compose from the approved automation;
- root-owned mode-`0600` `.env.production` rendered from Ansible Vault; and
- no uploaded-document directory, persistent application volume, or GridFS data.

Therefore a `crm01` VM backup would reduce recovery time but is not the sole copy of business data. Proxmox snapshots remain rollback points, not backups.

## Current validated recovery inputs — 2026-07-19

| Input | Validation |
|---|---|
| CRM source | GitHub repository reachable; `main` resolves to the pinned revision |
| Deployed revision | `/opt/realestate-crm` resolves to `ae9539ca575df9ffdafe047c49b20fff2473b858` as root |
| Deployment automation | `ansible/playbooks/crm.yml` syntax validation passed |
| Secret rendering | `.env.production` exists as `0600 root:root`; secret contents were not read |
| Runtime | A matching healthy CRM container is running |
| Database | `crm_prod` remains on `db01`; backup and restore parity are validated separately |

## Recovery prerequisites

1. Owner confirms `crm01` is actually unrecoverable or authorizes rebuild; do not destroy a potentially recoverable VM.
2. `db01` and `crm_prod` are healthy. If not, follow database recovery first.
3. VM101 identity remains reserved for hostname `crm01` and IP `192.168.10.101`.
4. Ubuntu Server 24.04 LTS template VM900, control-node SSH, Ansible Vault, Keychain Vault password, and private CRM Git access are available.
5. The existing `crm_prod` backup archive remains off-host and unchanged.

## Rebuild sequence

### 1. Recreate the VM baseline

After separate owner approval, recreate VM101 as a full clone of VM900 using the documented baseline: 2 vCPU, 2 GB RAM, 32 GB disk, hostname `crm01`, static IP `192.168.10.101`, QEMU Guest Agent, and `sysadmin` SSH access. Do not change the VM name, ID, IP, or resources during recovery.

Validate SSH host identity before accepting a changed host key. Remove an old known-host entry only after the owner confirms VM101 was legitimately recreated.

### 2. Reapply infrastructure automation

From `ansible/`, use the Keychain-backed Vault password and apply in this order:

```bash
ANSIBLE_VAULT_PASSWORD_FILE=../scripts/ansible-vault-keychain.sh \
ansible-playbook playbooks/common.yml --limit crm01

ANSIBLE_VAULT_PASSWORD_FILE=../scripts/ansible-vault-keychain.sh \
ansible-playbook playbooks/docker.yml --limit crm01

ANSIBLE_VAULT_PASSWORD_FILE=../scripts/ansible-vault-keychain.sh \
ansible-playbook playbooks/crm.yml --limit crm01
```

Never pass `-e crm_reset_canary_database=true` during recovery. That one-time option drops `crm_prod` and is permanently prohibited after migration.

### 3. Validate the recovered application

Require all checks before user access:

| Check | Pass condition |
|---|---|
| Host | Ubuntu 24.04, hostname/IP correct, QEMU Guest Agent active |
| Docker | Engine active; Compose available |
| Source | Exact pinned Git revision present |
| Secrets | `.env.production` is `0600 root:root`; contents never printed |
| Container | Running and Docker health status `healthy` |
| Application | `GET /healthz` returns `200` |
| Database | Logs confirm MongoDB connection to `crm_prod` |
| Functional | Owner login, permission behaviour, 275-lead/4-user baseline or then-current counts |
| Capacity | No swap pressure or documented host/VM stop condition |

Keep the CRM internal-only. Recovery does not approve DNS, Nginx Proxy Manager, TLS, or router changes.

### 4. Recovery completion

After validation, record exact Git revision, container runtime, health results, database counts, resource evidence, operator, and completion time. Create only the separately approved recovery snapshot name; do not treat the snapshot as an off-host backup.

## Failure and rollback

- If common or Docker automation fails, stop before deploying CRM and retain logs.
- If CRM deployment fails, keep `db01` unchanged, stop the new application container, and fix automation rather than editing production secrets manually.
- If database connection or permission validation fails, do not reset, drop, or restore `crm_prod`; investigate credentials, firewall, and application configuration.
- If the original `crm01` still exists, never run it concurrently with a replacement using the same IP.
- Any database recovery uses the separately validated MongoDB backup/restore workflow and requires owner approval.

## Remaining limitation

The procedure is validated from current source, automation, secret metadata, container health, and database recovery evidence, but a full destructive `crm01` rebuild has not been rehearsed. No spare VM is created on the constrained 16 GB host for this test. A proper off-host VM backup remains desirable before public publication, but hardware and backup-server work stay deferred by owner instruction.

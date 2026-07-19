# Deployment Runbook

## Standard change flow

1. Confirm the task matches [PROJECT-ROADMAP.md](../PROJECT-ROADMAP.md).
2. Update relevant documentation and ADRs for permanent decisions.
3. Commit reviewed configuration.
4. Run syntax checks and dry runs.
5. Apply first to an approved canary host when multiple VMs are affected.
6. Validate host and service state.
7. Apply to the remaining approved scope.
8. Take a material-change snapshot where appropriate and update the changelog.

## Current Ansible checks

Run from `ansible/`:

```bash
ansible-inventory --graph
ansible all -m ping
ansible-playbook playbooks/common.yml --syntax-check
ansible-playbook playbooks/common.yml --check --limit crm01
```

The present check-mode run requires an Ansible Vault-supplied sudo credential for `sysadmin`. Do not store that password in inventory, a playbook, shell history, or an unencrypted repository file.

## macOS Keychain Vault access

The local Ansible configuration uses the versioned, password-free helper `scripts/ansible-vault-keychain.sh`. It retrieves the Vault password from the macOS Keychain. The encrypted `ansible/group_vars/all/vault.yml` file is versioned only in this private repository; never commit a plaintext equivalent or the Vault password.

For a replacement Mac, follow the [Vault recovery section of the New Control Node Setup](New-Control-Node-Setup.md#vault-recovery--read-before-setting-up-a-new-mac). GitHub supplies encrypted files only; recover the same existing Vault password from an approved source and recreate the local Keychain item before running Ansible.

Add or update the Keychain item once. Keep `-w` as the final option so macOS prompts securely:

```bash
security add-generic-password -a "$USER" -s "office-infrastructure-ansible-vault" -U -w
```

Afterward, run Ansible commands without `--ask-vault-pass`.

## Docker Engine phase

Docker automation is restricted to the `docker` inventory group: `crm01`, `web01`, `erp01`, and `npm01`. Do not run the Docker playbook against `db01`, `pbx01`, or `mon01`.

Run the following from `ansible/` before production application:

```bash
ansible-playbook playbooks/docker.yml --syntax-check
ansible-playbook playbooks/docker.yml --check --limit crm01
```

On a first run, check-mode verifies the Docker package index is reachable but intentionally skips the package-install, Docker-group membership, and Docker-service tasks because the new repository is not yet present in the host’s active APT cache. The production canary apply performs the package installation only after owner approval.

After owner review and approval, apply first to `crm01`:

```bash
ansible-playbook playbooks/docker.yml --limit crm01
```

Validate Docker Engine and the Compose plugin before applying to the remaining approved Docker hosts.

## MongoDB CRM pilot

MongoDB Community `8.3.4` is automated only for `db01`. It creates a Vault-managed administrative user and a least-privilege `crm_app` user for `crm_prod`; UFW permits TCP `27017` only from `crm01` and allows SSH only from `192.168.10.0/24`. No database port is public.

Run from `ansible/`:

```bash
ansible-playbook playbooks/mongodb.yml --syntax-check
ansible-playbook playbooks/mongodb.yml --check --limit db01
```

After owner review of the check, apply to `db01`:

```bash
ansible-playbook playbooks/mongodb.yml --limit db01
```

Validate the running version and listener after the apply:

```bash
ansible db01 -m command -a 'mongod --version'
ansible db01 -m command -a 'systemctl is-active mongod'
ansible db01 -m command -a 'ss -ltnp sport = :27017'
```

Take the approved `db-installed` Proxmox snapshot after successful validation. The Windows source database `realestate_crm` remains untouched; importing it to `crm_prod` is a later, separately approved step.

## CRM internal canary

The CRM canary is restricted to `crm01`. It checks out the owner-approved GitHub commit, builds the Node.js 24 LTS Docker image, creates a mode-`0600` `.env.production` file from Vault values, and validates `/healthz` plus the MongoDB connection. It is internal-only and does not create a public Nginx Proxy Manager host.

The current canary target is revision
`1a8301bca2b4b57bd40a4847b0f83aaa40c6b341`. It retains the encrypted 12-hour
session store in `crm_prod.sessions` and adds reliable Enter-key submission to
the login form. This deployment does not reset or remigrate `crm_prod`; never
pass `crm_reset_canary_database=true`. Rollback is the previously validated
session-store revision `e7a9ddbf8e8e3b12ba187906484e813150a3490f`
followed by the same playbook.

The canary is currently accessed by internal HTTP, so it explicitly sets `SESSION_COOKIE_SECURE=false`; otherwise a browser cannot retain the login session cookie over HTTP. This override is canary-only. The CRM source defaults to secure cookies in production, and a future Nginx Proxy Manager HTTPS deployment must remove the override or set `SESSION_COOKIE_SECURE=true` before publication.

All application containers must explicitly receive the project `timezone` value (`Asia/Dhaka` currently) through their Compose environment. Docker containers otherwise default to UTC even when their VM uses the correct local timezone. The CRM canary is the first deployed application to use this standard; future Website, ERP, and Nginx Proxy Manager deployments must apply it in their own service templates.

Run from `ansible/`:

```bash
ansible-playbook playbooks/crm.yml --syntax-check
ansible-playbook playbooks/crm.yml --check --limit crm01
ansible-playbook playbooks/crm.yml --limit crm01
```

After the CRM canary deployment:

1. Confirm `/healthz`, the pinned Git revision, container health, and clean logs.
2. Sign in once through the internal HTTP canary and confirm a document exists
   in `crm_prod.sessions` with an `expires` TTL index; never print its encrypted
   payload or cookie ID.
3. Restart only the CRM application container, wait for health, then refresh the
   same browser page. The authenticated session must remain valid.
4. Confirm the 275 leads and 4 users remain unchanged, MongoDB is active, and
   both VMs have zero active swap use.
5. Roll back immediately for login/CSRF failure, missing TTL index, session loss,
   application errors, database-count drift, or resource pressure.
6. On the internal login page, enter credentials and press Enter from a
   credential field. The form must submit without requiring a mouse click.

For the approved rate-limit and security-header canary, validate all of the
following before retaining the revision:

1. Normal login and CSRF behaviour remain functional.
2. Five failed attempts for one account-and-IP key return `401`; the next
   attempt returns generic `429` with `Retry-After` and rate-limit headers.
3. Successful login attempts are excluded from the failure quota.
4. Responses include the approved Helmet headers but no
   `Strict-Transport-Security` header on the internal HTTP canary.
5. The application remains healthy, the exact revision is pinned, session TTL
   remains present, and the 275 leads / 4 users gates remain unchanged.
6. Roll back to `1a8301bca2b4b57bd40a4847b0f83aaa40c6b341` for broken login,
   missing headers, unexpected HSTS/CSP enforcement, limiter bypass, false
   lockout, application errors, or protected-count drift.

Run the non-restart metadata validation immediately after deployment:

```bash
ansible-playbook playbooks/crm-session-validate.yml --limit crm01
```

After the owner signs in once, run the restart gate. This command restarts only
the CRM application container; it does not restart MongoDB or modify CRM data:

```bash
ansible-playbook playbooks/crm-session-validate.yml --limit crm01 \
  -e crm_session_require_document=true \
  -e crm_session_restart=true
```

The owner must then refresh the same authenticated browser page and confirm it
remains signed in. Database evidence alone does not replace this browser check.

For the one-time admin bootstrap on the empty canary database only, run:

```bash
ansible-playbook playbooks/crm.yml --limit crm01 -e crm_reset_canary_database=true
```

Do not run the reset after importing Windows test or production data.

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

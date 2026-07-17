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

On a first run, check-mode verifies the Docker package index is reachable but intentionally skips the package-install task because the new repository is not yet present in the host’s active APT cache. The production canary apply performs the package installation only after owner approval.

After owner review and approval, apply first to `crm01`:

```bash
ansible-playbook playbooks/docker.yml --limit crm01
```

Validate Docker Engine and the Compose plugin before applying to the remaining approved Docker hosts.

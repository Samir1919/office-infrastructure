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

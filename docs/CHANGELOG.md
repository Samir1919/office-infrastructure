# Change Log

This is the durable history of completed and validated work. Planned work belongs in [PROJECT-ROADMAP.md](../PROJECT-ROADMAP.md).

## 2026-07-17 — Repository and automation foundation

### Added

- Git repository and GitHub off-site backup.
- `AGENTS.md` AI operating manual and change-control rules.
- Documentation and ADR directory structure.
- Ansible YAML production inventory, baseline variables, playbook skeletons, and role directories.
- macOS Ansible control node using Homebrew Ansible 14.2.0 and Python 3.14.6.
- Passwordless SSH access for `sysadmin` on all production VMs.

### Validated

- `ansible all -m ping` succeeded for all seven production VMs.
- Target hosts use `/usr/bin/python3.12`.
- The `common.yml` playbook passed syntax validation and inventory graph validation.

### Corrected

- Renamed the common role task file from `main.ymal` to `main.yml`.
- Stopped tracking the generated Ansible collection directory; dependencies are reproduced through `requirements.yml`.

### Current blocker

- `crm01` check mode reached privilege escalation but stopped before change because `sysadmin` needs a sudo password. Configure encrypted Ansible Vault-based sudo credentials before applying the common role.

## Before 2026-07-17 — Infrastructure foundation

- Proxmox VE installed and validated on `pve01`.
- Ubuntu Server 24.04 LTS golden template created as VM900.
- VMs 101–107 created as full clones with static IPs, SSH, internet connectivity, QEMU Guest Agent, updates, and `base-config` snapshots.

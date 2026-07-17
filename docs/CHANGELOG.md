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
- Encrypted Ansible Vault-based sudo credentials were configured locally for Ansible use.
- Approved the private-repository policy for versioning the encrypted Vault file; the Vault password remains in the macOS Keychain and outside Git.
- The common baseline was applied and validated on canary host `crm01`: timezone `Asia/Dhaka`, QEMU Guest Agent active, and `qemu-guest-agent` version `1:8.2.2+ds-0ubuntu1.17`.
- Following successful canary validation, the common baseline was applied to the remaining six production VMs and `common-base` snapshots were created for all production VMs.
- Docker Engine and Compose were applied and validated on canary host `crm01`, then rolled out to `web01`, `erp01`, and `npm01`; `docker-base` snapshots were created for all four Docker hosts.

### Corrected

- Renamed the common role task file from `main.ymal` to `main.yml`.
- Stopped tracking the generated Ansible collection directory; dependencies are reproduced through `requirements.yml`.

### Next step

- Complete the documented Proxmox host-capacity review before Phase 5 application deployment.

## Before 2026-07-17 — Infrastructure foundation

- Proxmox VE installed and validated on `pve01`.
- Ubuntu Server 24.04 LTS golden template created as VM900.
- VMs 101–107 created as full clones with static IPs, SSH, internet connectivity, QEMU Guest Agent, updates, and `base-config` snapshots.

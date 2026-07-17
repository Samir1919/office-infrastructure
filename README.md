# Office Infrastructure Project

A version-controlled, self-hosted office infrastructure built on Proxmox VE and managed with Ansible.

## Start here

- **[Project roadmap and current state](PROJECT-ROADMAP.md)** — canonical project reference.
- **[AI and change-control rules](AGENTS.md)** — rules for AI-assisted work.
- **[Technical documentation](docs/)** — VM, network, security, backup, monitoring, and runbooks.
- **[Ansible automation](ansible/)** — inventory, roles, and playbooks.
- **[New control-node setup](docs/New-Control-Node-Setup.md)** — move project automation safely to a new Mac or PC.

## Current status

Infrastructure foundation and Ansible control-plane connectivity are complete. The next implementation item is the common baseline role; Docker and applications have not been deployed.

## Security note

This repository contains internal infrastructure metadata. Keep the GitHub repository private in normal operation. Never commit passwords, private keys, API tokens, TLS private keys, Vault passwords, or application `.env` files.

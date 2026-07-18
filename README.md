# Office Infrastructure Project

A version-controlled, self-hosted office infrastructure built on Proxmox VE and managed with Ansible.

## Start here

- **[Project roadmap and current state](PROJECT-ROADMAP.md)** — canonical project reference.
- **[AI and change-control rules](AGENTS.md)** — rules for AI-assisted work.
- **[Technical documentation](docs/)** — VM, network, security, backup, monitoring, and runbooks.
- **[Ansible automation](ansible/)** — inventory, roles, and playbooks.
- **[New control-node setup — English + বাংলা](docs/New-Control-Node-Setup.md)** — move project automation safely to a new Mac or PC with bilingual Vault-recovery guidance.

## Current status

Infrastructure foundation, Ansible control-plane, common baseline, and Docker automation are complete. A documented host-capacity decision is required before application deployment.

## Security note

This repository contains internal infrastructure metadata. Keep the GitHub repository private in normal operation. Never commit passwords, private keys, API tokens, TLS private keys, Vault passwords, or application `.env` files.

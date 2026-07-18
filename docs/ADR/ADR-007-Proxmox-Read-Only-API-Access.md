# ADR-007: Proxmox Read-Only API Access

- **Status:** Accepted
- **Date:** 2026-07-19

Use a dedicated Proxmox VE API user `infra-audit@pve` and privilege-separated token `codex` for automated host-capacity and health inspection. Assign the built-in `PVEAuditor` role to both the backing user and token at `/`. Store the token secret only in the owner control node's macOS Keychain. Pin the owner-verified `pve01` TLS certificate locally; never disable certificate verification.

This access is read-only and does not replace owner administration through the Proxmox console or Web UI. Do not grant the audit identity VM administration, storage administration, system modification, or user-management privileges.

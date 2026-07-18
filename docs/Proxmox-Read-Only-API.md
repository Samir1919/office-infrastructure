# Proxmox Read-Only API Access

**Status:** Owner-approved; provisioning and validation pending
**Scope:** `pve01` read-only capacity and health evidence from the owner’s macOS control node

## Approved design

Use Proxmox VE's built-in `PVEAuditor` role with a dedicated `infra-audit@pve` user and privilege-separated `codex` API token. The token can read host, storage, VM, and health information but must not receive any configuration or administration role.

The token secret remains outside Git in the macOS Keychain. HTTPS certificate verification remains enabled. The control node pins the owner-verified certificate presented by `pve01`; `curl -k`, `--insecure`, automatic certificate acceptance, and unverified SSH host keys are prohibited.

This follows the Proxmox VE Administration Guide's limited monitoring-token pattern: a token's permissions are a subset of its backing user's permissions, and privilege separation permits a narrower token ACL.

## Provisioning workflow

### 1. Verify the presented TLS certificate

On the physical/local `pve01` console, run:

```bash
openssl x509 -in /etc/pve/local/pve-ssl.pem \
  -noout -fingerprint -sha256 -subject -issuer -dates
```

Compare its SHA-256 fingerprint with the fingerprint shown by the control-node installer. The certificate currently presented to the control node reports subject `CN=pve01.local` and is valid from 2026-07-15 through 2028-07-14. Do not trust it until the console fingerprint matches.

After the match, install the pinned public certificate on the Mac:

```bash
scripts/install-proxmox-presented-cert.sh '<console SHA-256 fingerprint>'
```

The script stores the public certificate at `~/.config/office-infrastructure/pve01-presented-cert.pem`. It exits without installing anything if the fingerprint differs.

### 2. Create the read-only identity

Run the following commands in the local `pve01` shell as the Proxmox administrator:

```bash
pveum user add infra-audit@pve \
  -comment 'Read-only infrastructure health validation'

pveum acl modify / \
  -user infra-audit@pve \
  -role PVEAuditor

pveum user token add infra-audit@pve codex -privsep 1

pveum acl modify / \
  -token 'infra-audit@pve!codex' \
  -role PVEAuditor

pveum user permissions infra-audit@pve
pveum user token permissions infra-audit@pve codex
```

The token creation command displays its secret once. Do not paste it into chat, a shell-history command, a document, or Git.

### 3. Store the token secret in macOS Keychain

On the owner’s Mac, run this command exactly; `security` will prompt for the token secret without placing it in the command line:

```bash
/usr/bin/security add-generic-password \
  -a 'infra-audit@pve!codex' \
  -s 'office-infrastructure-proxmox-api-token' \
  -U -w
```

Paste the secret only into the Keychain prompt.

### 4. Validate read-only access

From the repository root on the Mac, run:

```bash
scripts/proxmox-api-health.sh
```

The command retrieves and prints only sanitized version, node, storage, and VM health data. It never prints the API token.

## Validation requirements

- TLS verification succeeds using the owner-verified pinned certificate.
- `/nodes/pve01/status` returns node CPU, memory, swap, root filesystem, and uptime data.
- `/nodes/pve01/storage/local-lvm/status` returns LVM-Thin total, used, and available capacity.
- `/cluster/resources?type=vm` returns read-only VM status and resource data.
- `pveum user token permissions infra-audit@pve codex` shows audit permission only.
- Any write request remains unauthorized and is not used as a validation test.

## Rotation and rollback

Rotate the token if it is exposed, when control-node ownership changes, or during the future credential-rotation phase. Re-verify and repin the certificate when Proxmox replaces it.

To revoke the access from the local `pve01` console:

```bash
pveum user token remove infra-audit@pve codex
pveum user delete infra-audit@pve
```

Then remove the local Keychain entry:

```bash
/usr/bin/security delete-generic-password \
  -a 'infra-audit@pve!codex' \
  -s 'office-infrastructure-proxmox-api-token'
```

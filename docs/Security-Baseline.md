# Security Baseline

## Implemented

- SSH key authentication for `sysadmin` on all production VMs.
- Ansible host-key checking enabled.
- Updated Proxmox host and VM baseline.
- QEMU Guest Agent in the base VM standard.
- Git ignore rules for common secret-bearing files and private-key patterns.
- Encrypted Ansible Vault files may be versioned only in the private repository; Vault passwords remain in the control node’s macOS Keychain.
- Approved database access policy: per-application database users, per-application firewall rules, and no public database exposure. See [Database Access Policy](Database-Access-Policy.md).
- `db01` UFW is active with default-deny incoming traffic; SSH is restricted to `192.168.10.0/24` and MongoDB TCP `27017` is restricted to `crm01` (`192.168.10.101`).
- Proxmox automated inspection uses the privilege-separated `infra-audit@pve!codex` API token with the built-in `PVEAuditor` role only. Its effective permissions are audit-only, its secret remains in macOS Keychain, and HTTPS uses an owner-verified pinned `pve01.local` certificate. Insecure TLS bypass and automated root SSH access are prohibited.

## Required before production exposure

- SSH hardening review, including password-authentication policy.
- Ansible Vault for encrypted repository secrets.
- Automatic-update policy and maintenance window.
- TLS certificate management, backup verification, and DR testing.
- CRM public login hardening: session persistence, rate limiting, and compatible headers are validated; proxy/cookie validation, CSP/HSTS staging, compromised-password screening, routine audit review, and incident-response evidence remain required.

### CRM authentication baseline

- New CRM passwords use a length-first policy of 15–128 Unicode code points;
  password managers, paste, spaces, and browser autofill are allowed.
- Do not impose composition rules or periodic password changes. Force a change
  when compromise is known or reasonably suspected.
- Protect the current admin session from self-demotion/self-deletion and ensure
  at least one admin always remains.
- Never render raw exception or database messages to users. Retain diagnostic
  detail only in protected logs and audit records.
- Audit client IPs must come from the application's approved one-proxy trust
  chain, not directly from untrusted forwarding headers.
- CSP enforcement requires the documented inline-code migration and route-level
  regression validation; HSTS requires stable trusted HTTPS.

Never record passwords, private keys, API tokens, or application `.env` files in Git.

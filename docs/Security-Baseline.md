# Security Baseline

## Implemented

- SSH key authentication for `sysadmin` on all production VMs.
- Ansible host-key checking enabled.
- Updated Proxmox host and VM baseline.
- QEMU Guest Agent in the base VM standard.
- Git ignore rules for common secret-bearing files and private-key patterns.
- Encrypted Ansible Vault files may be versioned only in the private repository; Vault passwords remain in the control node’s macOS Keychain.
- Approved database access policy: per-application database users, per-application firewall rules, and no public database exposure. See [Database Access Policy](Database-Access-Policy.md).

## Required before production exposure

- Apply the approved `db01` firewall baseline and CRM-specific MongoDB allow rule.
- SSH hardening review, including password-authentication policy.
- Ansible Vault for encrypted repository secrets.
- Automatic-update policy and maintenance window.
- TLS certificate management, backup verification, and DR testing.

Never record passwords, private keys, API tokens, or application `.env` files in Git.

# New Ansible Control Node Setup

Use this runbook when moving the Office Infrastructure Project to a new Mac or PC. It prepares a new machine to manage the existing Proxmox VMs without copying another machine's private SSH key or any plaintext secret.

## Supported control-node platform

The approved control node is macOS, as defined in [PROJECT-ROADMAP.md](../PROJECT-ROADMAP.md). This runbook fully supports macOS.

For a Windows PC, use WSL2 with a supported Linux distribution for Ansible. The repository's Keychain helper is macOS-specific, so use `--ask-vault-pass` until an owner-approved Windows Credential Manager helper is documented. Do not weaken Vault protection just to remove a prompt.

## What is stored where

| Item | Location | Rule |
|---|---|---|
| Project automation and encrypted `vault.yml` | Private GitHub repository | Safe to clone; `vault.yml` must retain its `$ANSIBLE_VAULT` encryption header. |
| Vault password | macOS Keychain or approved password manager | Never commit, email, paste in chat, or place in a repository file. |
| SSH private key | Each control node only | Create a unique key for every control node; never copy an old machine's private key. |
| SSH public key | Each managed VM's `sysadmin` account | Add the new control node's public key, then remove a retired node's public key after validation. |

## Before starting

1. Keep the current working control node available until the new one passes all validation checks.
2. Confirm the GitHub repository remains private and that the new administrator has authorized access.
3. Obtain the Vault password through the approved password manager or another secure owner-approved method. Do not send it with the repository or the encrypted Vault file.
4. Obtain approval before changing VM access, applying playbooks, or removing the old control node's key.

## Vault recovery — read before setting up a new Mac

Cloning or pulling the private GitHub repository provides the whole-file-encrypted `vault.yml` and the inline `!vault` values in `mongodb-secrets.yml`, but it does **not** provide their decryption password. The project currently uses the same single Vault password for both encryption formats loaded by the infrastructure playbooks. A new control node must recover that existing password; it must not invent a replacement.

Approved recovery order:

1. Retrieve the existing Vault password from the old trusted Mac's Keychain while that Mac remains available.
2. If the old Mac is unavailable, retrieve the same password from the owner's approved secondary password-manager entry. The recommended Google Password Manager label is website `https://office-infrastructure.invalid` with username `ansible-vault-recovery`; verify that it was saved to the Google Account rather than device-only storage.
3. If configured later, use the approved encrypted offline recovery copy.
4. If none of these sources is available, stop. Do not re-encrypt, overwrite, edit, or replace the existing Vault files, because doing so can permanently separate automation from its managed credentials.

The current macOS command stores the working item in the local login Keychain. Signing in with an Apple Account alone does not guarantee that this command-created item will appear on a new Mac. Google Password Manager is a secondary encrypted recovery copy, not a different password and not the primary runtime integration.

Never put the Vault password in GitHub, a repository file, `.env`, shell command argument, email, chat, unencrypted note, screenshot, or CSV export. Google/Chrome password CSV exports are plaintext and are prohibited for this recovery workflow.

### Recreate the Keychain item on the new Mac

After securely recovering the existing password, run this command and type the password only into the protected macOS prompt:

```bash
cd ansible
security add-generic-password -a "$USER" -s "office-infrastructure-ansible-vault" -U -w
```

Confirm that the item exists without printing its secret:

```bash
security find-generic-password -s "office-infrastructure-ansible-vault" >/dev/null
```

Then verify that the same recovered password decrypts the whole-file Vault and loads the inline Vault values through inventory. Successful commands produce no secret output because it is discarded:

```bash
ANSIBLE_VAULT_PASSWORD_FILE=../scripts/ansible-vault-keychain.sh \
ansible-vault view group_vars/all/vault.yml >/dev/null

ANSIBLE_VAULT_PASSWORD_FILE=../scripts/ansible-vault-keychain.sh \
ansible-inventory --host db01 >/dev/null
```

Only after both checks succeed should the new control node run inventory, ping, check-mode, or production workflows.

## macOS setup

### 1. Install prerequisites and clone the repository

Install Apple Command Line Tools and Homebrew if they are not already present. Then install Ansible and clone the private repository:

```bash
brew install ansible
git clone git@github.com:Samir1919/office-infrastructure.git
cd office-infrastructure
git status
```

The working tree should be clean. Run Ansible commands from `ansible/`, because its `ansible.cfg` defines the inventory, roles, and Vault helper path.

### 2. Create a new dedicated SSH key

Create a unique key for this control node. Replace the label with a meaningful device name:

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/office-infrastructure-control -C "office-infrastructure-new-control-node"
ssh-add --apple-use-keychain ~/.ssh/office-infrastructure-control
```

Protect the private key with a passphrase. The private key stays on this machine; only the `.pub` file is shared with the VMs.

### 3. Authorize the new public key on every VM

Use the current trusted control node or an approved console session to add the contents of `~/.ssh/office-infrastructure-control.pub` to `sysadmin`'s `~/.ssh/authorized_keys` on all seven production VMs. Preserve the existing working key until the new node is validated.

Verify the VM host-key fingerprints against the trusted current control node or Proxmox console before accepting them. Do not disable Ansible host-key checking and do not bypass a changed host-key warning.

### 4. Add the Vault password to macOS Keychain

Recover the existing password through the preceding Vault recovery procedure. From the cloned repository's `ansible/` directory, run the following once. Keep `-w` as the final option so macOS asks for the password securely:

```bash
cd ansible
security add-generic-password -a "$USER" -s "office-infrastructure-ansible-vault" -U -w
```

The versioned helper at `scripts/ansible-vault-keychain.sh` reads this Keychain item automatically. The Vault password is not written to Git or to an unencrypted project file.

### 5. Validate the new control node

Run these non-destructive checks from `ansible/`:

```bash
ansible-inventory --graph
ansible all -m ping
ansible-playbook playbooks/common.yml --syntax-check
ansible-playbook playbooks/common.yml --check --limit crm01
```

Expected result: all seven VMs respond to `ping`, syntax validation succeeds, and the canary check completes without an SSH or Vault-password prompt.

## Using the new control node safely

Before any production change, follow the project workflow:

1. Confirm the action is approved in [PROJECT-ROADMAP.md](../PROJECT-ROADMAP.md).
2. Update documentation before a permanent design or security-policy change.
3. Run syntax checks and a canary `--check` run.
4. Obtain owner approval for the production apply.
5. Apply to the canary, validate it, then roll out to the approved remaining scope.
6. Create required snapshots and update [CHANGELOG.md](CHANGELOG.md).
7. Commit reviewed changes and push only to the private repository.

## Retiring the old control node

After the new node has completed all validation checks:

1. Remove the old control node's public key from each VM's `sysadmin` `authorized_keys` file.
2. Delete the `office-infrastructure-ansible-vault` Keychain item from the old Mac.
3. Securely erase or retire the old device according to company policy.
4. Record the completed control-node transition in [CHANGELOG.md](CHANGELOG.md).

Do not remove the old access path before the new one is fully validated.

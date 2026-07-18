# New Ansible Control Node Setup

**Language:** [English](#english-guide) | [বাংলা](#বাংলা-নির্দেশিকা)

## English guide

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

---

## বাংলা নির্দেশিকা

Office Infrastructure Project নতুন Mac বা PC-তে নেওয়ার সময় এই নির্দেশিকা ব্যবহার করুন। এর মাধ্যমে পুরোনো computer-এর private SSH key বা কোনো plaintext secret copy না করে নতুন computer থেকে বর্তমান Proxmox VMগুলো নিরাপদে পরিচালনা করা যাবে।

### সমর্থিত control-node platform

[PROJECT-ROADMAP.md](../PROJECT-ROADMAP.md) অনুযায়ী অনুমোদিত control node হলো macOS। এই নির্দেশিকায় macOS-এর সম্পূর্ণ setup দেওয়া আছে।

Windows PC হলে supported Linux distribution-সহ WSL2 ব্যবহার করুন। Repository-এর Keychain helper শুধু macOS-এর জন্য। Owner-approved Windows Credential Manager helper তৈরি না হওয়া পর্যন্ত `--ask-vault-pass` ব্যবহার করুন। Prompt এড়ানোর জন্য Vault security দুর্বল করবেন না।

### কোন জিনিস কোথায় থাকে

| বিষয় | অবস্থান | নিয়ম |
|---|---|---|
| Project automation, encrypted `vault.yml` এবং inline `!vault` values | Private GitHub repository | Clone করা নিরাপদ; Vault encryption header অক্ষত রাখতে হবে। |
| Vault password | macOS Keychain বা approved password manager | Git, email, chat বা repository file-এ রাখা যাবে না। |
| SSH private key | প্রতিটি control node-এ আলাদা | নতুন control node-এর জন্য নতুন key তৈরি করতে হবে; পুরোনো private key copy করা যাবে না। |
| SSH public key | প্রতিটি managed VM-এর `sysadmin` account | নতুন key validation-এর পরে retired control node-এর public key সরাতে হবে। |

### শুরু করার আগে

1. নতুন control node-এর সব validation শেষ না হওয়া পর্যন্ত বর্তমান working control node চালু রাখুন।
2. GitHub repository private আছে এবং নতুন administrator-এর অনুমোদিত access আছে নিশ্চিত করুন।
3. Approved password manager বা owner-approved secure source থেকে বর্তমান Vault password সংগ্রহ করুন। Repository বা encrypted Vault file-এর সঙ্গে password পাঠাবেন না।
4. VM access পরিবর্তন, playbook apply বা পুরোনো control node-এর key সরানোর আগে approval নিন।

### Vault recovery — নতুন Mac setup-এর আগে পড়ুন

Private GitHub repository clone বা pull করলে whole-file-encrypted `vault.yml` এবং `mongodb-secrets.yml`-এর inline `!vault` values পাওয়া যাবে, কিন্তু এগুলোর decryption password পাওয়া যাবে না। বর্তমানে দুই ধরনের encryption-এর জন্য একই একটি Vault password ব্যবহৃত হয়। নতুন control node-এ অবশ্যই সেই existing password recover করতে হবে; নতুন password বানানো যাবে না।

অনুমোদিত recovery order:

1. পুরোনো trusted Mac চালু থাকলে তার Keychain থেকে existing Vault password নিন।
2. পুরোনো Mac পাওয়া না গেলে owner-এর approved secondary password-manager entry থেকে একই password নিন। Google Password Manager-এর recommended label: website `https://office-infrastructure.invalid`, username `ansible-vault-recovery`। Entryটি Google Account-এ save হয়েছে, শুধু device-এ নয়—এটি নিশ্চিত করুন।
3. ভবিষ্যতে encrypted offline recovery copy তৈরি হলে সেটি ব্যবহার করা যাবে।
4. কোনো recovery source পাওয়া না গেলে থামুন। Existing Vault file re-encrypt, overwrite, edit বা replace করবেন না। এতে automation ও managed credentials স্থায়ীভাবে বিচ্ছিন্ন হয়ে যেতে পারে।

বর্তমান macOS command working passwordটি local login Keychain-এ রাখে। শুধু Apple Account-এ sign in করলে command-created item নতুন Mac-এ আসবে—এমন নিশ্চয়তা নেই। Google Password Manager হলো একই password-এর secondary encrypted recovery copy; এটি আলাদা password বা primary runtime integration নয়।

Vault password কখনো GitHub, repository file, `.env`, shell command argument, email, chat, unencrypted note, screenshot বা CSV export-এ রাখবেন না। Google/Chrome password CSV export plaintext হয় এবং এই recovery workflow-তে নিষিদ্ধ।

#### নতুন Mac-এ Keychain item পুনরায় তৈরি

Existing password নিরাপদে recover করার পরে cloned repository-এর `ansible/` directory থেকে নিচের command চালান। Password শুধু macOS-এর protected prompt-এ লিখবেন:

```bash
cd ansible
security add-generic-password -a "$USER" -s "office-infrastructure-ansible-vault" -U -w
```

Secret print না করে Keychain item আছে কি না যাচাই করুন:

```bash
security find-generic-password -s "office-infrastructure-ansible-vault" >/dev/null
```

একই recovered password whole-file Vault decrypt এবং inline Vault values load করতে পারে কি না no-outputভাবে যাচাই করুন:

```bash
ANSIBLE_VAULT_PASSWORD_FILE=../scripts/ansible-vault-keychain.sh \
ansible-vault view group_vars/all/vault.yml >/dev/null

ANSIBLE_VAULT_PASSWORD_FILE=../scripts/ansible-vault-keychain.sh \
ansible-inventory --host db01 >/dev/null
```

দুইটি check সফল হওয়ার আগে inventory, ping, check-mode বা production workflow চালাবেন না।

### macOS setup

#### ১. প্রয়োজনীয় software install এবং repository clone

Apple Command Line Tools ও Homebrew না থাকলে install করুন। তারপর Ansible install করে private repository clone করুন:

```bash
brew install ansible
git clone git@github.com:Samir1919/office-infrastructure.git
cd office-infrastructure
git status
```

Working tree clean থাকা উচিত। Ansible command `ansible/` directory থেকে চালান, কারণ এর `ansible.cfg` inventory, role এবং Vault helper path নির্ধারণ করে।

#### ২. নতুন dedicated SSH key তৈরি

নতুন control node-এর জন্য unique key তৈরি করুন। Comment-এ meaningful device name ব্যবহার করতে পারেন:

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/office-infrastructure-control -C "office-infrastructure-new-control-node"
ssh-add --apple-use-keychain ~/.ssh/office-infrastructure-control
```

Private key-তে passphrase দিন। Private key শুধু এই computer-এ থাকবে; VMগুলোতে শুধু `.pub` file-এর content যোগ হবে।

#### ৩. সব VM-এ নতুন public key authorize

বর্তমান trusted control node বা approved console session ব্যবহার করে `~/.ssh/office-infrastructure-control.pub`-এর content সব সাতটি production VM-এর `sysadmin` user-এর `~/.ssh/authorized_keys` file-এ যোগ করুন। নতুন access validate হওয়ার আগে পুরোনো working key সরাবেন না।

নতুন host key accept করার আগে trusted current control node বা Proxmox console-এর সঙ্গে VM host-key fingerprint মিলিয়ে দেখুন। Ansible host-key checking বন্ধ করবেন না এবং changed host-key warning bypass করবেন না।

#### ৪. Vault password macOS Keychain-এ যোগ

আগের Vault recovery procedure অনুসরণ করে existing password recover করুন। Cloned repository-এর `ansible/` directory থেকে commandটি একবার চালান। `-w` শেষে রাখুন, যাতে macOS secure password prompt দেখায়:

```bash
cd ansible
security add-generic-password -a "$USER" -s "office-infrastructure-ansible-vault" -U -w
```

Versioned `scripts/ansible-vault-keychain.sh` helper প্রয়োজনের সময় এই Keychain item পড়বে। Vault password Git বা unencrypted project file-এ লেখা হবে না।

#### ৫. নতুন control node validate

`ansible/` directory থেকে নিচের non-destructive checks চালান:

```bash
ansible-inventory --graph
ansible all -m ping
ansible-playbook playbooks/common.yml --syntax-check
ansible-playbook playbooks/common.yml --check --limit crm01
```

Expected result: সব সাতটি VM `ping`-এ response দেবে, syntax validation সফল হবে এবং canary check কোনো SSH বা Vault-password prompt ছাড়া শেষ হবে।

### নতুন control node নিরাপদভাবে ব্যবহার

Production change-এর আগে project workflow অনুসরণ করুন:

1. কাজটি [PROJECT-ROADMAP.md](../PROJECT-ROADMAP.md)-এ approved কি না দেখুন।
2. Permanent design বা security-policy change-এর আগে documentation update করুন।
3. Syntax check এবং canary `--check` চালান।
4. Production apply-এর আগে owner approval নিন।
5. প্রথমে canary-তে apply ও validate করে তারপর approved scope-এ rollout করুন।
6. প্রয়োজনীয় snapshot তৈরি করে [CHANGELOG.md](CHANGELOG.md) update করুন।
7. Reviewed changes commit করুন এবং শুধু private repository-তে push করুন।

### পুরোনো control node retire

নতুন control node-এর সব validation সফল হওয়ার পরে:

1. প্রতিটি VM-এর `sysadmin` `authorized_keys` থেকে পুরোনো control node-এর public key সরান।
2. পুরোনো Mac থেকে `office-infrastructure-ansible-vault` Keychain item delete করুন।
3. Company policy অনুযায়ী পুরোনো device securely erase বা retire করুন।
4. Completed transition [CHANGELOG.md](CHANGELOG.md)-এ record করুন।

নতুন access সম্পূর্ণ validate হওয়ার আগে পুরোনো access path সরাবেন না।

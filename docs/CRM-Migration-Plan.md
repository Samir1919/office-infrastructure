# CRM Pilot Migration Plan

**Status:** Approved for constrained canary validation only
**Scope:** Existing Node.js CRM on a local Windows PC, `crm01`, and `db01`
**Out of scope:** Public access, Nginx Proxy Manager publication, calling integration, full database hardening/backups, and production cutover

## Purpose

Move the existing CRM application source from its GitHub repository to `crm01` and copy its MongoDB data from the Windows PC into a new database on `db01`. The work begins as a non-public canary on the present 16 GB Proxmox host. The CRM calling feature is not yet implemented and remains outside this migration; a future FreePBX integration belongs to Phase 7.

## Pilot boundaries

- `crm01` and `db01` remain at 2 vCPU / 2 GB / 32 GB. No resize is authorized.
- `db01` remains a dedicated database VM. Docker must not be installed on it.
- The CRM remains internal-only. Do not create public DNS, NPM proxy hosts, TLS certificates, or router port forwarding.
- Use a test import before any final data transfer. A production cutover requires separate owner approval.
- Keep secrets out of Git. Store database credentials in Ansible Vault or an approved local secret store.

## Approved software baseline

Use the latest production-supported patch release available at implementation time within these approved release lines:

| Component | Approved release line | Selection rationale |
|---|---|---|
| Operating system | Ubuntu Server 24.04 LTS | Existing approved VM baseline |
| MongoDB on `db01` | MongoDB 8.3.4 | Approved current stable patch release |
| Node.js on `crm01` | Node.js 24.x LTS | Latest LTS line; suitable for production deployment |
| Docker Engine on `crm01` | Docker official stable APT channel | Already installed and managed through the official repository |
| Docker Compose | Docker Compose plugin from the official stable APT channel | Installed with Docker Engine and updated through the same channel |

Do not use preview, `Current`, beta, release-candidate, or end-of-life releases. In particular, Node.js 26.x is a Current release rather than LTS, so it is not the CRM deployment target. Record the exact installed package versions in the implementation validation evidence.

## Approved target database

The new CRM production database on `db01` is **`crm_prod`**. This follows the project standard `<application>_<environment>`: future non-production environments use names such as `crm_dev` and `crm_staging`. Do not reuse the existing Windows database name. The source database remains unchanged until the separately approved final cutover.

The database name identifies the application and environment, not the hosting VM. This prevents a database rename when services move between hosts. Put the database host in the backup artifact name instead, for example `db01_crm_prod_YYYY-MM-DD.archive.gz`.

### Confirmed source-to-target mapping

| Item | Confirmed value |
|---|---|
| Source host | Local Windows CRM PC |
| Source MongoDB | MongoDB 7.0 |
| Source database | `realestate_crm` |
| Target host | `db01` |
| Target MongoDB | MongoDB 8.3.4 |
| Target database | `crm_prod` |
| CRM Node.js runtime | Node.js 24.18.0 |

## Facts required before implementation

Record and review these facts from the Windows source system before selecting MongoDB packages or writing the deployment role:

| Required fact | Why it is needed |
|---|---|
| MongoDB server version | Needed to validate dump/restore compatibility with the approved `db01` MongoDB 8.3.4 target. |
| Current database name | Needed only to map its collections safely into the approved target database `crm_prod`. |
| Approximate database size and collection count | Needed to assess disk/RAM impact and validate the import. |
| GridFS or Windows filesystem uploads | `mongodump` preserves GridFS; filesystem uploads require a separate, verified copy. |
| Node.js major version | Needed to choose the matching runtime on `crm01`. |
| Package manager and lockfile | Needed for reproducible dependency installation (`npm`, `yarn`, or `pnpm`). |
| Application start/build command and required environment variables | Needed for a working Compose service without guessing. |

Do not reuse, rename, or delete the Windows source database during the pilot.

## Proposed migration method

Use MongoDB-native tools, not manual document export, so indexes and GridFS data can be preserved.

1. Take a read-only test dump from the Windows source database and retain it outside the repository.
2. Restore the test archive to the owner-approved new database on `db01`.
3. Compare collection/document counts, indexes, application login, and representative record access.
4. Only after separate cutover approval: freeze CRM writes, create a final dump, restore it, validate again, then redirect the internal CRM configuration to `db01`.

Example commands, with placeholders only:

```bash
mongodump --uri="mongodb://localhost:27017/realestate_crm" \
  --archive=crm-test.archive --gzip

mongorestore \
  --uri="mongodb://<user>:<password>@db01:27017/crm_prod?authSource=admin" \
  --nsFrom="realestate_crm.*" --nsTo="crm_prod.*" \
  --archive=crm-test.archive --gzip
```

If the CRM stores uploaded files on the Windows filesystem rather than GridFS, inventory the source directory, copy it through a controlled transfer, preserve ownership/permissions as appropriate, and validate file access separately. Do not assume database-only migration covers those files.

## Application preparation on `crm01`

1. Pull the owner-approved GitHub revision `ae9539ca575df9ffdafe047c49b20fff2473b858`, which contains the Node.js 24 LTS Docker runtime update and configurable session-cookie security.
2. Build the existing Docker Compose application image on `crm01`; the repository uses `npm` and production command `node app.js`.
3. Create a non-committed `.env.production` file with the Vault-managed `crm_app` URI for `crm_prod` and a Vault-managed session secret.
4. Run the CRM only on the internal network and test `/healthz`, MongoDB connection logs, login, data reads/writes, and application logs.
5. Monitor `pve01`, `crm01`, and `db01` memory, swap, CPU, disk use, and MongoDB logs throughout the canary.

The CRM Docker Compose service publishes TCP `3000` for the internal canary only. It receives no public DNS, Nginx Proxy Manager host, TLS certificate, or router port forwarding.

Because this canary is accessed over internal HTTP, its generated environment file sets `SESSION_COOKIE_SECURE=false` so browsers can retain the authenticated session cookie. This is not a public-deployment setting: before Nginx Proxy Manager HTTPS publication, remove the override or set `SESSION_COOKIE_SECURE=true`.

The initial admin identity follows the CRM repository configuration: `Admin User` / `admin@asalagroupbd.com`. Its password is a unique Vault-managed value stored locally in the owner’s macOS Keychain; the repository's exposed example password is never used on `crm01`.

Before Windows data migration only, the canary may reset its empty `crm_prod` database to bootstrap this admin identity. This reset is prohibited after test or production data has been imported.

### Canary validation record

| Check | Validated result |
|---|---|
| Git revision | `ae9539ca575df9ffdafe047c49b20fff2473b858` |
| Container Node.js runtime | `v24.18.0` |
| Container health | `GET /healthz` returned `200` with `{"status":"ok"}` |
| Database connection | CRM log confirmed MongoDB connection to `crm_prod` |
| Container state | Docker health status `healthy` |
| Initial admin | `Admin User` / `admin@asalagroupbd.com`, created with a Vault-managed password |
| Internal login | Validated: CSRF-protected login redirected to the authenticated dashboard over internal HTTP |
| Test source data import | Completed: Windows `realestate_crm` copied to `crm_prod`; 275 leads and 4 users validated; Windows source remains unchanged |
| Permission taxonomy | Mapping applied to migrated users |
| Owner browser validation | CRM operated normally after refresh; no visible problem reported |
| CRM VM resources | 2 vCPU; 1,413 MB available of 1,900 MB; 0 MB swap used; root filesystem 22% used; load `0.00 0.00 0.00` |
| CRM container resources | `0.14%` CPU and `46.28 MiB` memory during the observation |
| CRM recent logs | Zero `error`, `fatal`, or `exception` matches in the latest 200 application log lines |
| Database VM resources | 2 vCPU; 1,414 MB available of 1,900 MB; 0 MB swap used; root filesystem 22% used; low load during both samples |
| MongoDB health | Service active; MongoDB `8.3.4`; 14 current connections; 205 MB resident memory; 275 leads and 4 users reconfirmed |
| Upload storage | No attachment/upload backend, persistent Docker volume, or GridFS collections; CSV import is submitted as browser-read text, so no separate document copy applies |
| Proxmox host evidence | Completed through the certificate-verified, audit-only API path: low CPU load, 8.22 GiB of 13.54 GiB usable memory used, zero swap use, 8.90% root-filesystem use, and 745.77 GiB available on `local-lvm` |

## Stop and rollback conditions

Stop the pilot if the host enters swap pressure, VM memory is persistently exhausted, LVM-Thin capacity is unsafe, MongoDB health is degraded, or CRM response time is unacceptable. Keep the Windows CRM unchanged until the final cutover validation succeeds. Restoring the CRM configuration to the Windows database and retaining the source data are the immediate rollback path.

## Next implementation decision

MongoDB 8.3.4 is installed and validated on `db01`. The Vault-managed `crm_app` user has `readWrite` access to `crm_prod` only, and authenticated TCP `27017` access is restricted by UFW to `crm01` only. The Node.js 24 internal canary is validated on `crm01`. A test copy from Windows `realestate_crm` to `crm_prod` imported 275 leads and 4 users; permission taxonomy mapping was applied and owner browser validation found no visible application problem. VM, container, MongoDB, upload-storage, and Proxmox host/LVM-Thin validation found no current pilot stop condition. The owner has deferred all hardware-upgrade work and instructed the project to continue on the current hardware. The next documentation-first task is to prepare and validate the production-cutover, backup, and rollback runbook. The Windows source remains unchanged, and production cutover or public publication still requires separate owner approval.

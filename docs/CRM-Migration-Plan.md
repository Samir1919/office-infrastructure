# CRM Pilot Migration Plan

**Status:** Approved for planning and canary preparation only
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
| MongoDB on `db01` | MongoDB 8.2.11 | Approved current stable patch release |
| Node.js on `crm01` | Node.js 24.x LTS | Latest LTS line; suitable for production deployment |
| Docker Engine on `crm01` | Docker official stable APT channel | Already installed and managed through the official repository |
| Docker Compose | Docker Compose plugin from the official stable APT channel | Installed with Docker Engine and updated through the same channel |

Do not use preview, `Current`, beta, release-candidate, or end-of-life releases. In particular, Node.js 26.x is a Current release rather than LTS, so it is not the CRM deployment target. Record the exact installed package versions in the implementation validation evidence.

## Approved target database

The new CRM database on `db01` is **`office_crm`**. This is a new, project-owned database name selected for the Office Infrastructure Project; do not reuse the existing Windows database name. The source database remains unchanged until the separately approved final cutover.

## Facts required before implementation

Record and review these facts from the Windows source system before selecting MongoDB packages or writing the deployment role:

| Required fact | Why it is needed |
|---|---|
| MongoDB server version | Needed to validate dump/restore compatibility with the approved `db01` MongoDB 8.2.11 target. |
| Current database name | Needed only to map its collections safely into the approved target database `office_crm`. |
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
mongodump --uri="mongodb://localhost:27017/<source_database>" \
  --archive=crm-test.archive --gzip

mongorestore \
  --uri="mongodb://<user>:<password>@db01:27017/office_crm?authSource=admin" \
  --nsFrom="<source_database>.*" --nsTo="office_crm.*" \
  --archive=crm-test.archive --gzip
```

If the CRM stores uploaded files on the Windows filesystem rather than GridFS, inventory the source directory, copy it through a controlled transfer, preserve ownership/permissions as appropriate, and validate file access separately. Do not assume database-only migration covers those files.

## Application preparation on `crm01`

1. Pull a fixed Git commit or release tag from the private CRM repository.
2. Build the Node.js service with the source-approved runtime and package manager.
3. Create a non-committed environment file that points to the new `db01` MongoDB URI.
4. Run the CRM only on the internal network and test health, login, data reads/writes, and the application logs.
5. Monitor `pve01`, `crm01`, and `db01` memory, swap, CPU, disk use, and MongoDB logs throughout the canary.

## Stop and rollback conditions

Stop the pilot if the host enters swap pressure, VM memory is persistently exhausted, LVM-Thin capacity is unsafe, MongoDB health is degraded, or CRM response time is unacceptable. Keep the Windows CRM unchanged until the final cutover validation succeeds. Restoring the CRM configuration to the Windows database and retaining the source data are the immediate rollback path.

## Next implementation decision

After the required source facts are recorded, prepare the MongoDB 8.2.11 role for `db01` and validate it in Ansible check mode. No installation, data migration, or public publication occurs until that design is reviewed and approved.

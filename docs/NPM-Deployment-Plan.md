# Nginx Proxy Manager Internal Deployment Plan

**Status:** Internal NPM service and administrator setup validated; no proxy host or public exposure approved
**Host:** `npm01` (`192.168.10.106`)
**Initial scope:** Internal NPM service and LAN/VPN-only administration; no CRM proxy host, DNS, certificate, router forwarding, or Internet exposure

## Purpose and boundary

The approved traffic architecture remains:

```text
User -> npm01 -> crm01:3000
```

The first deployment stage must not publish the CRM. It prepares only the NPM
service after a separate owner approval. TCP `81` is an administration port and
must remain reachable only from the office LAN or an approved VPN. SSH,
databases, Proxmox, and NPM administration must never be publicly forwarded.

## Read-only baseline — 2026-07-19

- Ubuntu Server `24.04.4 LTS`; Docker Engine `29.6.2` and Compose `v5.3.1` are active.
- No containers, images, custom Docker networks, Docker volumes, Compose files,
  or NPM files are present.
- TCP `80`, `81`, and `443` are unused; SSH listens on TCP `22`.
- UFW is inactive. nftables contains only Docker-managed base chains and no
  custom inbound access policy.
- The VM has 1.9 GiB RAM with about 1.5 GiB available, 2 GiB unused swap, 24 GiB
  free disk space, and low load. No VM resize is approved.

The inactive host firewall is a deployment blocker until the access-control
design below is approved and validated. Docker-published ports must not be
assumed to obey a future UFW policy without an explicit Docker-aware test.

## Upstream baseline and image policy

The official NPM setup guide and latest official GitHub release identify
`jc21/nginx-proxy-manager:2.15.1` / NPM `v2.15.1` as the current release on
2026-07-19. The eventual Compose file should pin the exact version tag and the
validated multi-architecture manifest digest. Do not use mutable `latest` or
major-only `2` in production.

The approved preparation resolved the `linux/amd64` manifest digest as
`sha256:99a885f56ca2203a2eb352a5f9e2cd5c1e25786508debd725ad48ebe955d114f`.
The Compose template pins both version `2.15.1` and this platform manifest.

## Database alternatives

| Option | Benefits | Risks and impact | Assessment |
|---|---|---|---|
| SQLite in `/data` | Officially supported; one container; lowest RAM and operational overhead; simple backup boundary | Single-instance only; backup must capture the database consistently; no external database failover | Recommended for this constrained single-instance deployment, pending owner approval |
| MariaDB container on `npm01` | Familiar multi-process database separation; official NPM example | Adds a second container, credentials, health ordering, backup scope, memory use, and patching | Not recommended on the current constrained host |
| PostgreSQL/MariaDB on `db01` | Central database policy alignment and independent lifecycle | Adds a new application database/user/firewall rule and expands Phase 6 scope | Defer; requires a separate architecture and database-security approval |

The owner approved SQLite for the initial single-instance deployment on
2026-07-19. This does not approve service deployment or public exposure.

## Proposed persistent layout

Ansible will own a root-controlled application directory
under `/opt/nginx-proxy-manager` containing only the rendered Compose file and
the following persistent directories:

```text
/opt/nginx-proxy-manager/data
/opt/nginx-proxy-manager/letsencrypt
```

`/data` contains the SQLite database, generated JWT keys, Nginx configuration,
and other NPM state. `/etc/letsencrypt` contains certificate state when a later
certificate stage is separately approved. Both paths must be included in the
NPM backup and restore procedure before any public stage.

Do not store administrator passwords or other secrets in the Compose file or
Git. The initial administrator identity and credential-change procedure must be
approved and stored through Ansible Vault or the owner's approved password
manager before first start.

## Proposed ports and access controls

| Host binding | Purpose | Initial scope |
|---|---|---|
| TCP `80` -> container `80` | HTTP proxy entry | May listen on `npm01` during internal service validation; no router forwarding or public DNS |
| TCP `443` -> container `443` | HTTPS proxy entry | May listen on `npm01` during internal service validation; no certificate or router forwarding in the first service step |
| `192.168.10.106:81` -> container `81` | NPM administration | Office LAN only initially; later VPN access requires separate VPN approval |

Binding TCP `81` to the LAN address prevents an all-interface Docker publish,
but it does not replace host and router policy. Before deployment, document and
approve one Docker-aware access-control method, validate TCP `81` from an allowed
LAN client, and confirm it is absent from every unapproved interface/path.

The project must never forward TCP `81` at the router. The future public stage,
if approved, may forward only TCP `80` and `443` to `npm01`.

## Docker-aware firewall design

### Why ordinary UFW rules are insufficient

Docker's official firewall documentation states that published-container traffic
is diverted in the NAT path before the UFW `INPUT` and `OUTPUT` chains. A UFW
default-deny policy therefore protects host services but must not be treated as
the control for Docker-published TCP `80`, `81`, or `443`.

The inspected Docker Engine uses Docker's iptables backend through the host's
iptables-nft compatibility layer and has an empty `DOCKER-USER` chain. Docker
documents this chain as the supported place for user rules processed before
Docker's forwarding/accept rules. Do not edit Docker-managed `DOCKER`,
`DOCKER-FORWARD`, NAT, or bridge chains and do not disable Docker's automatic
iptables management.

Official references:

- [Docker packet filtering and UFW](https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-and-ufw)
- [Docker with iptables and DOCKER-USER](https://docs.docker.com/engine/network/firewall-iptables/)
- [Docker port publishing](https://docs.docker.com/engine/network/port-publishing/)
- [Ubuntu firewall guidance](https://documentation.ubuntu.com/server/how-to/security/firewalls/)

### Alternatives

| Option | Benefits | Risks and limitations | Assessment |
|---|---|---|---|
| Bind TCP `81` only to `192.168.10.106`; rely on router for the rest | Smallest change; Compose already prepared this way | Any routed source that reaches the LAN IP can attempt access; no host-enforced source restriction | Retain as one layer, not the only control |
| Enable UFW with default-deny and ordinary allow rules | Protects host services such as SSH; familiar and already used on `db01` | Docker officially documents that published traffic can bypass ordinary UFW `INPUT`/`OUTPUT` policy | Required for host baseline, insufficient alone for NPM ports |
| Add rules directly to Docker-managed chains | Can filter container traffic | Docker owns and may recreate/reorder those chains; unsupported maintenance boundary | Reject |
| Disable Docker iptables management | Centralizes firewall ownership | Docker warns this is likely to break container networking; greatly expands design and recovery scope | Reject |
| Project-owned chain reached from `DOCKER-USER`, plus UFW host baseline | Uses Docker's documented extension point; source-specific filtering; leaves Docker rules intact | Requires careful ordering, persistence, Docker-restart testing, and rollback | Recommended, pending owner approval |

### Recommended internal-stage policy

The existing single LAN and interface remain unchanged:

```text
Interface: enp6s18
NPM host: 192.168.10.106
Allowed source: 192.168.10.0/24
Internal NPM TCP ports: 80, 81, 443
```

The proposed policy has two separate layers:

1. **Host layer — UFW:** default deny incoming, default allow outgoing, allow
   SSH TCP `22` only from `192.168.10.0/24`, then enable UFW. This controls host
   services but is not claimed to control Docker-published ports.
2. **Container-forwarding layer — Docker `DOCKER-USER`:** insert one jump to a
   project-owned chain. In that chain, accept established/related flows, allow
   new TCP `80`, `81`, and `443` only from `192.168.10.0/24` on `enp6s18`, and
   drop other new traffic to those NPM container ports regardless of ingress
   interface. A future approved VPN requires an explicit allow rule before this
   drop. Return all unrelated
   Docker traffic without changing its policy.

The project-owned chain must be narrowly named for NPM, must not flush or set a
policy on `DOCKER-USER`, and must not affect other current or future Docker
containers. Exact packet matches must be validated against the post-DNAT view;
if original host address/port matching is required, use Docker's documented
`conntrack` approach and record the performance trade-off.

### Persistence and ordering

Do not place ad-hoc commands in shell history or depend on an in-memory rule.
The recommended automation should render a root-owned rule loader and a oneshot
systemd unit ordered after `docker.service`. The loader must be idempotent:

1. verify Docker's `DOCKER-USER` chain exists;
2. create or refresh only the project-owned NPM chain;
3. ensure exactly one jump from `DOCKER-USER` to that chain;
4. preserve Docker-managed and unrelated user rules;
5. reapply after a Docker service restart and at boot;
6. fail before NPM deployment if any required rule is absent or duplicated.

The final unit/script content requires code review and syntax/dry-run validation
before a production approval. This design does not approve installing an
additional firewall-persistence package or switching Docker to its experimental
nftables backend.

### Validation sequence for a future approved firewall apply

1. Keep the existing owner SSH session open and establish a second LAN SSH
   session before enabling UFW; stop if either session fails.
2. Confirm UFW default policies and the LAN-only SSH allow rule before enabling.
3. Confirm the project-owned chain and its single `DOCKER-USER` jump without
   exposing unrelated rules or secrets.
4. Before NPM exists, confirm SSH remains reachable and no TCP `80`, `81`, or
   `443` listener has appeared.
5. After a separately approved NPM apply, validate TCP `80/81/443` from an
   approved LAN client and validate rejection from a genuinely non-LAN/routed
   test source when such a safe source is available. A same-LAN test alone does
   not prove the negative path.
6. Confirm TCP `81` remains absent from router forwarding and public-port tests.
7. Restart Docker only in a separately approved validation window, then prove
   the project chain and access policy were restored before retaining the design.

### Rollback

If SSH validation fails, use the still-open session or Proxmox console to disable
UFW and restore the previous host access state. For the Docker layer, stop and
disable only the project-owned rule-loader unit, remove only its jump and chain,
and confirm Docker's own chains remain intact. Stop/remove the NPM container if
it was separately deployed, then confirm TCP `80`, `81`, and `443` no longer
listen. Never flush the complete filter table, `DOCKER-USER`, or Docker-managed
chains.

### Firewall stop conditions

Stop for loss of either SSH validation session, a missing/duplicated jump,
failure to distinguish host UFW from Docker forwarding, an unexpected non-LAN
allow path, changes to Docker-managed chains, rules that affect unrelated
containers, non-persistent policy after restart, or lack of Proxmox-console
recovery access.

### Applied IPv4 firewall evidence — 2026-07-19

- UFW is active with low logging, default-deny incoming, default-allow outgoing,
  default-deny routed traffic, and SSH TCP `22` allowed only from
  `192.168.10.0/24`.
- `DOCKER-USER` has exactly one jump to `NPM-FILTER`. The project chain accepts
  established/related traffic, permits new TCP `80`, `81`, and `443` only from
  `192.168.10.0/24` on `enp6s18`, drops other new IPv4 traffic to those ports,
  and returns unrelated traffic.
- The root-owned loader is mode `0750`; the root-owned systemd unit is mode
  `0644`, enabled, and active. A repeat check-mode run reported zero changes.
- A fresh SSH/Ansible connection succeeded. No NPM path, container, or listener
  on TCP `80`, `81`, or `443` exists.
- The owner separately approved one Docker daemon restart. After the restart, a
  fresh SSH/Ansible connection succeeded; Docker and the firewall unit were
  active, the unit remained enabled, UFW policy was unchanged, and the exact
  single jump plus project-chain rules were restored. Containers remained empty
  and TCP `80`, `81`, and `443` remained unused.

### IPv6 publication gate

`npm01` has a global IPv6 address and Docker's IPv6 `DOCKER-USER` chain is
currently empty. UFW protects IPv6 host input, but the project-owned Docker
forwarding chain is IPv4-only. There is no present exposure because NPM is not
deployed and TCP `80`, `81`, and `443` are unused.

The owner approved explicit IPv4 binding for all three NPM ports on 2026-07-19.
The prepared Compose template binds TCP `80`, `81`, and `443` only to
`192.168.10.106`; it does not publish them on the host's global IPv6 address.
The alternatives reviewed were:

| Option | Benefits | Risks and impact | Assessment |
|---|---|---|---|
| Bind TCP `80`, `81`, and `443` to `192.168.10.106` | Prevents unintended Docker IPv6 publication; matches the current IPv4 LAN/router architecture; smallest change | Future intentional native IPv6 publication would require a reviewed change | Recommended for the current internal stage |
| Add equivalent IPv6 Docker filtering and publish IPv6 | Preserves dual-stack service potential | Requires stable approved IPv6 prefix, IPv6 router/firewall facts, external tests, and wider public-edge review | Defer; facts and approval are absent |
| Disable host/Docker IPv6 | Removes the path globally | Changes VM/network behaviour beyond NPM and may affect future services | Reject as disproportionate |

The explicit IPv4 binding is approved for the current internal stage. This is a
Compose preparation change only; it does not approve an NPM service start or
public IPv4 publication. Ansible syntax/check mode, host-address assertions, and
temporary Docker Compose schema validation passed. Native IPv6 publication
remains deferred.

## Approved automation-preparation boundary

The approved preparation creates a dedicated `npm` role and `npm.yml` playbook
limited to `npm01`. Do not
mix application deployment into the existing generic Docker role. The role must:

1. assert the exact host and approved operating system;
2. assert that TCP `80`, `81`, and `443` do not conflict before first deployment;
3. create only the approved persistent paths and a pinned Compose definition;
4. include timezone `Asia/Dhaka`;
5. disable external CDN IP-range fetching during the internal stage so an
   unreachable upstream does not block backend startup;
6. avoid plaintext secrets and avoid creating any proxy host automatically;
7. support `--syntax-check` and a meaningful `--check --limit npm01` run;
8. start containers only during a separately approved apply.

## Administrator identity and first-login workflow

### Upstream behaviour

Official NPM `v2.15.1` source provides two first-admin paths:

1. Without `INITIAL_ADMIN_EMAIL` and `INITIAL_ADMIN_PASSWORD`, the
   unauthenticated setup wizard is available only while no active user exists.
   It requests full name, email, and a password of 8–100 characters, then signs
   in the new administrator.
2. With both variables, the backend creates the initial user automatically but
   logs the supplied initial email **and plaintext password**. This path is
   rejected for this project.

The Compose template intentionally omits both `INITIAL_ADMIN_*` variables. Do
not add them through Compose, Ansible Vault, command-line extra variables, or a
temporary environment file; Vault encryption at rest would not prevent the
upstream runtime log disclosure.

Official references:

- [NPM v2.15.1 initial-user backend](https://github.com/NginxProxyManager/nginx-proxy-manager/blob/v2.15.1/backend/setup.js)
- [NPM v2.15.1 setup wizard](https://github.com/NginxProxyManager/nginx-proxy-manager/blob/v2.15.1/frontend/src/pages/Setup/index.tsx)
- [NPM v2.15.1 2FA API](https://github.com/NginxProxyManager/nginx-proxy-manager/blob/v2.15.1/backend/schema/paths/users/userID/2fa/enable/post.json)

### Approved security recommendation

- The owner approved `ryansamir90@gmail.com` as the NPM administrator email on
  2026-07-19. This records identity only; it does not store a password or 2FA
  material.
- Use the approved password manager to generate and store one unique password
  of 20–100 characters. NPM's upstream minimum is only eight; the project uses
  a stronger minimum without placing the value in automation.
- Complete the wizard only from an approved LAN client at
  `http://192.168.10.106:81`. Never make TCP `81` public.
- NPM `2.15.1` has backend 2FA endpoints but no frontend 2FA control. Do not pass
  TOTP secrets through ad-hoc API tooling; keep TCP `81` LAN/VPN-only.
- Never paste the password, TOTP secret, QR content, session token, or backup
  codes into chat, Git, screenshots, tickets, commands, or Ansible output.

### First-login validation and stop conditions

1. Confirm the browser URL is exactly the LAN address and TCP `81` is not
   router-forwarded.
2. Confirm the wizard, rather than a pre-existing login account, is shown. Stop
   for an unexpected user; do not reset or delete the SQLite file.
3. The owner enters full name, approved email, and password directly in the
   browser. The AI does not receive or verify the secret value.
4. Confirm the new user has administrator access. UI-based 2FA is unavailable in
   this release; do not expose TCP `81` publicly.
5. Stop for plaintext credentials in logs, an unexpected account, wizard access
   from an unapproved path, 2FA failure, missing backup codes, or failed re-login.

Initial account state resides in SQLite and belongs in the NPM backup/restore
scope. Do not rerun setup by deleting `database.sqlite`.

## Validation after a future approved service deployment

1. Confirm the exact image tag and manifest digest.
2. Confirm only the expected NPM container exists and remains healthy/stable.
3. Confirm TCP `80`, `443`, and LAN-bound `81`; confirm no database or extra
   stream port is exposed.
4. Validate administration access from an approved LAN client and rejected
   access from every unapproved path available for testing.
5. Change the default administrator credential immediately using the approved
   identity and secret-storage workflow; never print it in logs or Git.
6. Confirm `/data` and `/etc/letsencrypt` persistence across a container restart.
7. Recheck RAM, swap, disk, load, Docker logs, and existing CRM/MongoDB health.
8. Confirm there is still no proxy host, certificate, DNS change, or router rule.

## Rollback

For a failed initial service deployment, stop and remove only the NPM Compose
containers and network, then revalidate that TCP `80`, `81`, and `443` are no
longer listening. Retain the persistent directories for evidence unless the
owner separately approves their removal. Revert any approved firewall rule using
its documented inverse operation. Do not delete NPM data or certificate state as
part of an automatic rollback.

## Stop conditions

Stop before or during deployment for any unapproved listening interface, public
TCP `81` path, mutable/unverified image reference, plaintext secret, unexpected
container, missing persistence, firewall uncertainty, port conflict, repeated
container restart, material RAM/swap pressure, or inability to reverse the
change safely.

## Owner decisions required before production implementation

1. SQLite and the `/opt/nginx-proxy-manager` persistent layout are approved.
2. Non-deploying Ansible/Compose preparation and validation are approved.
3. Approve or reject the layered UFW plus project-owned `DOCKER-USER` design.
4. The IPv4 firewall apply and Docker-restart persistence validation are
   complete.
5. Explicit IPv4 binding of NPM TCP `80`, `81`, and `443` is approved and
   prepared; native IPv6 publication remains deferred.
6. Owner-controlled administrator email `ryansamir90@gmail.com` is approved and
   recorded. Password generation, entry, and TOTP/backup-code handling remain
   owner-operated and never enter automation or chat.
7. The first internal NPM service apply and administrator setup are complete and
   validated; no proxy host or public stage is approved.

No NPM service, proxy host, administrator secret, certificate, DNS record,
router rule, firewall rule, CRM setting, or VM resource was changed by this plan.

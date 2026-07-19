# Nginx Proxy Manager Internal Deployment Plan

**Status:** NPM public HTTPS edge for CRM is deployed; TCP `81`, HSTS, and later release gates remain controlled separately
**Host:** `npm01` (`192.168.10.106`)
**Initial scope:** This document began with the internal NPM service and LAN/VPN-only administration stage and now records the first approved public CRM HTTPS publication state on the same host

## Purpose and boundary

The approved traffic architecture remains:

```text
User -> npm01 -> crm01:3000
```

The first deployment stage did not publish the CRM; that internal-only history
is retained below. The current approved state now publishes the CRM only
through NPM on TCP `80/443`. TCP `81` remains an administration port and must
remain reachable only from the office LAN or an approved VPN. SSH, databases,
Proxmox, and NPM administration must never be publicly forwarded.
The `crm01:3000` hop is the current internal CRM application listener only; it
is not a public-facing port and must never be router-forwarded directly.

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
   new public TCP `80` and `443` on `enp6s18`, allow new LAN-only TCP `81`
   from `192.168.10.0/24` on `enp6s18`, and drop other new TCP `81` traffic
   that also arrives on `enp6s18`. The final drop must stay scoped to the
   inbound LAN/public ingress interface so it does not accidentally block
   unrelated forwarded Docker egress such as Let's Encrypt API calls from the
   NPM container. A future approved VPN requires an explicit allow rule before
   this drop. Return all unrelated Docker traffic without changing its policy.

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
  established/related traffic, permits new public TCP `80` and `443` on
  `enp6s18`, permits new TCP `81` only from `192.168.10.0/24` on `enp6s18`,
  drops other new TCP `81` traffic on that ingress interface, and returns
  unrelated traffic.
- The root-owned loader is mode `0750`; the root-owned systemd unit is mode
  `0644`, enabled, and active. A repeat check-mode run reported zero changes.
- A first public-stage adjustment was required before certificate issuance
  because the earlier LAN-only drop logic also matched forwarded NPM container
  egress on TCP `443`, blocking outbound Let's Encrypt API access. The active
  rule now keeps the drop ingress-scoped so outbound certificate traffic is not
  intercepted.
- The owner separately approved one Docker daemon restart. After the restart, a
  fresh SSH/Ansible connection succeeded; Docker and the firewall unit were
  active, the unit remained enabled, UFW policy was unchanged, and the exact
  single jump plus project-chain rules were restored.

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

### Interim renewal evidence — 2026-07-19

- NPM user/account ID `1` remains active with email
  `ryansamir90@gmail.com`, matching the approved initial renewal/proxy alert
  identity.
- Let's Encrypt certificate `id=3` for `crm.asalarealestate.com` is stored in
  `/etc/letsencrypt/live/npm-3/` and currently expires on
  `2026-10-17 02:27:51 UTC`.
- Recent NPM backend logs show the built-in message
  `Let's Encrypt Renewal Timer initialized`.
- The same log stream shows the hourly worker cadence repeating
  `Renewing SSL certs expiring within 30 days ...`
  followed by
  `Completed SSL cert renew process`.
- A dedicated monitoring/alerting stack is still deferred to the future
  `mon01` phase, so current renewal assurance is the validated built-in NPM
  worker plus documented manual review.

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

## Required fact collection before any proxy host or public-edge design

Internal NPM service validation is complete. The next approved project step is
to collect and record the owner-controlled facts that decide whether a later CRM
proxy/TLS stage is even possible. This fact collection is documentation only.
It does not approve or perform any proxy host creation, DNS change, certificate
request, router forwarding, or public exposure.

| Required fact | Why it is needed | Current state |
|---|---|---|
| Intended CRM FQDN | Determines the candidate proxy-host name, certificate subject, and browser validation path | Owner provided `crm.asalarealestate.com` |
| DNS provider and exact zone-control path | Determines who can create/rollback records and whether DNS-01 is even possible later | Owner-controlled Cloudflare zone |
| Public IPv4 reachability or CGNAT status | Determines whether direct inbound HTTP-01/router forwarding is feasible | Owner reports public IPv4 `103.147.107.152`; CGNAT not currently indicated |
| Router ownership, admin access, and current TCP `80`/`443` use | Determines whether the owner can safely forward only the approved ports and whether conflicts exist | Owner admin access exists to `D-Link DIR-X3000Z`; port forwarding is available; TCP `80`/`443` are owner-confirmed free |
| Intent for native IPv6 publication | Confirms whether the current approved IPv4-only binding remains sufficient or whether a later reviewed IPv6 design is needed | Owner does not require IPv6 publication; keep IPv4-only design |
| Preferred certificate boundary | Confirms whether a later stage should evaluate HTTP-01 only, DNS-01, or no public certificate path yet | Owner agreed to review/use HTTP-01 first on public TCP `80`/`443` |
| TCP `81` administration path | Confirms whether LAN-only remains enough or whether a separately approved VPN path is needed before wider proxy work | LAN-only validated; VPN remains separate |
| Monitoring/alert recipient for proxy and renewal failures | Prevents a certificate/proxy stage from launching without an owner-visible failure path | Owner email first; future monitoring system later |

### Owner-reported fact package — 2026-07-19

- Intended CRM FQDN: `crm.asalarealestate.com`
- DNS provider/account control: owner-controlled Cloudflare zone
- Current public DNS state: the owner reports the CRM subdomain already exists
  in Cloudflare and points to public IPv4 `103.147.107.152`
- Public reachability baseline: the owner reports a public IPv4 address is
  available and CGNAT is not currently indicated
- Router access baseline: owner admin access exists to a `D-Link DIR-X3000Z`
  router, and the owner confirms port forwarding is available
- Native IPv6 publication intent: not required; keep the current IPv4-only
  publication design and reviewed IPv6 deferral
- Preferred certificate boundary: review/use HTTP-01 first on public TCP `80`
  and `443`
- Monitoring/alert ownership: send initial renewal/proxy alerts to the owner
  email and add a future monitoring system later

The following edge facts still need explicit confirmation before any proxy-host,
certificate, or forwarding stage:

- whether any existing router/NAT, ISP, or upstream firewall rule conflicts
  with the intended direct reverse-proxy path despite the owner-confirmed free
  TCP `80`/`443` baseline.

### Remaining upstream-conflict confirmation checklist

Confirm the following before any CRM proxy-host apply or HTTP-01 certificate
attempt:

1. The router WAN/public IPv4 reported by `D-Link DIR-X3000Z` matches
   `103.147.107.152`.
2. No ISP modem, ONU, or upstream router adds another NAT layer or separate
   inbound firewall in front of `D-Link DIR-X3000Z`.
3. No existing upstream rule already consumes, redirects, or filters inbound
   TCP `80` or `443`.
4. The ISP path permits inbound TCP `80` and `443`.
5. Any future forwarding rule on `D-Link DIR-X3000Z` can be removed quickly if
   the proxy or certificate step fails.

### Owner-reported upstream result — 2026-07-19

The owner reports that all five checks above are satisfied:

- the router WAN/public IP matches `103.147.107.152`
- the ISP ONU sits upstream, but PPPoE authentication is performed on
  `D-Link DIR-X3000Z`, so an additional upstream NAT layer is not currently
  indicated
- TCP `80` and `443` have not previously been forwarded on this path
- no inbound-forwarding issue is currently known on the ISP path
- future forwarding rules can be removed quickly because router control remains
  with the owner

Treat these as owner-reported facts. If later validation contradicts any one of
them, keep the project at the current documentation/approval stage and do not
apply the first CRM proxy host yet.

## Recommended first CRM proxy-host boundary

After the remaining upstream-conflict fact is confirmed and before any public
certificate or router step, the first CRM proxy validation should stay internal
to the LAN:

1. Create one proxy host for `crm.asalarealestate.com` to backend
   `http://192.168.10.101:3000`.
2. Do not request a certificate yet and do not enable public router forwarding
   during this first proxy step.
3. Use a temporary host override on one approved LAN client so the real FQDN
   resolves to `192.168.10.106`.
4. Validate the proxied CRM application path, then either retain the proxy host
   for the later public stage or remove it cleanly if validation fails.

This boundary keeps NPM administration on LAN/VPN only, preserves the chosen
HTTP-01 path for the later public certificate stage, and avoids mixing public
edge risk with the first application-proxy test. The internal backend remains
`crm01:3000`; only `npm01` should ever receive public TCP `80/443`.

### Applied first CRM proxy-host result — 2026-07-19

The approved internal CRM proxy host now exists on `npm01`:

- domain: `crm.asalarealestate.com`
- backend: `http://192.168.10.101:3000`
- certificate: none
- router forwarding: none
- public DNS change during this stage: none

Machine validation confirmed the saved NPM row, generated proxy-host config,
`meta.nginx_online=true`, proxied `/healthz` success through a
resolve-equivalent FQDN test to `192.168.10.106`, and proxied `/login` HTTP
`200`. The direct CRM backend remained healthy.

### Approved collection boundary

1. The owner may provide these facts directly, or separately approve read-only
   observation needed to confirm them.
2. Do not log in to the DNS provider or router, request a certificate, create a
   proxy host, edit public DNS, or change forwarding rules during this stage.
3. If any fact reveals CGNAT, missing router control, conflicting public-port
   use, or a desire for native IPv6 publication, stop and return to
   documentation and owner review before proposing implementation.

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

## Owner decisions required before proxy host or public-edge implementation

1. SQLite and the `/opt/nginx-proxy-manager` persistent layout are approved.
2. The layered UFW plus project-owned `DOCKER-USER` design is approved; the
   IPv4 firewall apply and Docker-restart persistence validation are complete.
3. Explicit IPv4 binding of NPM TCP `80`, `81`, and `443` is approved and
   prepared; native IPv6 publication remains deferred unless the owner later
   opens a separate reviewed design.
4. Owner-controlled administrator email `ryansamir90@gmail.com` is approved and
   recorded. Password generation, entry, and TOTP/backup-code handling remain
   owner-operated and never enter automation or chat.
5. Internal NPM service deployment/setup validation is complete; do not rerun
   bootstrap or create a replacement administrator.
6. The owner-reported fact package is now complete for the first internal
   proxy-validation stage: FQDN
   `crm.asalarealestate.com`, owner-controlled Cloudflare DNS, public IPv4
   `103.147.107.152`, router admin access with port-forward capability on
   `D-Link DIR-X3000Z`, owner-confirmed free TCP `80`/`443`, no native IPv6
   publication requirement, and HTTP-01 as the first certificate path.
7. The upstream NAT/firewall-conflict checklist is owner-reported complete.
8. Initial monitoring/renewal ownership is the owner email, with a future
   monitoring system to be added later.
9. The recommended first CRM proxy-validation method is a temporary hosts-file
   override on one approved LAN client that resolves the real FQDN to
   `192.168.10.106`.
10. One internal CRM proxy host is now deployed and machine-validated without a
   certificate, public DNS change, or router forwarding.
11. Separately approve any browser-side validation completion, future
   certificate workflow, public DNS change, or router forwarding as later
   stages.

No public certificate, public DNS record, or router rule was changed by this
documentation update.

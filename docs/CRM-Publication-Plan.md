# CRM Access and HTTPS Publication Plan

**Status:** First public HTTPS stage deployed and owner-accepted; later hardening gates remain open
**Scope:** Access path from users to `crm01` through `npm01`
**Current state:** `crm01:3000` remains the internal application listener only;
it is not a public/router-facing port. `npm01` now publishes
`crm.asalarealestate.com` with a Let's Encrypt certificate and forced HTTPS on
public TCP `80/443`, while TCP `81` remains LAN/VPN-only.

## Current approved design

Public application traffic now follows one path only:

```text
Internet → Router TCP 80/443 → npm01 → http://192.168.10.101:3000
```

No direct port forwarding to `crm01`, SSH, Proxmox, or MongoDB is permitted. Nginx Proxy Manager administration must remain LAN/VPN-only and must never be forwarded publicly.

The backend hop to `crm01:3000` is an internal application port only. It is not
the old Windows publication model and it must never be router-forwarded or
published directly to the Internet.

## Access alternatives

| Option | Benefits | Risks / limitations | Assessment |
|---|---|---|---|
| Keep internal-only | Lowest exposure; current validated state | Office-LAN access only | Safe current default |
| VPN-only staff access | Remote use without public CRM login; follows remote-administration security direction | Requires VPN implementation and user onboarding | Recommended near-term remote-access option |
| Public HTTPS through `npm01` | Normal browser access from anywhere | Exposes authentication and application attack surface; requires app hardening, DNS, TLS, edge rules, monitoring, and incident response | Do not implement until all gates pass |
| Cloud tunnel service | Can work behind CGNAT and avoid router forwarding | External dependency and architecture change; does not match the currently approved direct reverse-proxy model | Not approved |

## Application readiness review — 2026-07-19

The previously deployed CRM baseline sets Express `trust proxy` in production, supports `SESSION_COOKIE_SECURE`, uses `HttpOnly` and `SameSite=Lax` session cookies, and applies CSRF protection. These are compatible with HTTPS termination at one trusted reverse proxy.

That historical baseline used `express-session` without an explicit production session store, so it fell back to `MemoryStore`. The official Express documentation states that this default is not designed for production, leaks memory under most conditions, and does not scale past one process. The application still has no declared login rate-limiter or HTTP security-header middleware, and no MFA capability is documented. See the [official Express session documentation](https://expressjs.com/en/resources/middleware/session/).

The owner subsequently approved the recommended MongoDB-backed design. CRM
revision `e7a9ddbf8e8e3b12ba187906484e813150a3490f` was merged after tests and CI.
It encrypts session payloads with the existing Vault-managed `SESSION_SECRET`,
stores them in `crm_prod.sessions`, applies a 12-hour rolling lifetime and a
MongoDB TTL index, and keeps the internal HTTP cookie override explicit. The
existing `crm_app` account already has the approved `readWrite` scope on
`crm_prod`, so no new database privilege or firewall rule is introduced.

Browser restart validation and the focused Enter-key login fix have passed.
Unrestricted public login remains blocked until the remaining hardening and
edge gates pass.

### Approved authentication-abuse policy

- Apply rate limiting only to `POST /login`; login-page reads and authenticated
  application traffic are not included.
- Allow at most 5 failed attempts per normalized account-and-client-IP key in a
  15-minute window, plus a broader limit of 25 failed attempts per client IP in
  the same window.
- Successful logins do not consume either quota. Return a generic HTTP `429`
  response with `Retry-After` and standard rate-limit headers; do not reveal
  whether an account exists.
- Hash the normalized email before composing the account limiter key; do not
  retain a raw email address in the limiter store.
- The initial single-instance canary may use the library memory store. Its
  counters reset on application restart and do not coordinate multiple
  instances, so a shared store is required before horizontal scaling and must
  be reconsidered during final public-release review.

### Approved security-header policy

- Apply Helmet's non-transport security headers globally, including protection
  against framing and MIME sniffing and a restrictive referrer policy.
- Keep HSTS disabled while the canary is served over internal HTTP. Enable it
  only after trusted HTTPS is stable and rollback has been exercised.
- Keep CSP enforcement disabled in this focused change because the current EJS
  views contain inline scripts and event handlers. CSP requires a separately
  tested nonce/external-script migration; silently allowing unsafe inline script
  would provide little protection.

## Required hardening before public HTTPS

1. Replace `MemoryStore` with an approved persistent session store. **Complete: machine checks and browser restart validation passed.**
2. Add login and authentication rate limiting with the approved abuse policy. **Complete: tests, CI, and live internal-canary validation passed.**
3. Add and validate security headers, keeping HSTS off until HTTPS is stable. **Compatible headers complete; live checks passed, while HSTS and CSP remain intentionally deferred.**
4. Remove the internal override or set `SESSION_COOKIE_SECURE=true` before proxy validation.
5. Confirm proxy trust remains limited to the single `npm01` hop; do not broadly trust arbitrary forwarding headers.
6. Review password policy, admin-account protection, audit logging, session lifetime, logout invalidation, and incident response. **Internal baseline complete; compromised-password screening, MFA direction, routine audit ownership, and external incident evidence remain public-release gates.**
7. Run dependency, application, and authentication-path tests against the exact deployment revision. **Complete for internal revision `dca592b946e1aad1b297c05d51cab58e7cac97c9`; repeat at every proxy/public stage.**

### Approved password and admin-account policy

- New passwords must contain 15–128 Unicode code points. Spaces, paste, browser
  autofill, and password managers remain supported; no arbitrary character-class
  composition or scheduled-expiry rule is imposed.
- Reject a small local list of common passwords immediately. A maintained
  compromised-password screening source remains required before unrestricted
  public release; it must not transmit plaintext passwords.
- Apply the policy to new accounts and future password changes. Do not silently
  invalidate or rewrite existing password hashes during this canary.
- Prevent an authenticated admin from demoting or deleting their own account,
  and prevent any operation that would demote or delete the last admin.
- Record successful and denied account-administration actions in the existing
  audit collection without storing submitted passwords.

### Audit and incident-handling baseline

- Derive audit client addresses from Express's one-hop trusted `req.ip`; do not
  trust a raw client-supplied forwarding header.
- Keep detailed internal errors in server logs/audit records while returning
  generic user-facing errors that do not disclose database or stack details.
- Review failed logins, limiter responses, role changes, user creation/deletion,
  and audit-write failures during an incident. Preserve evidence before account
  or service recovery actions.
- No automatic audit-log deletion is approved until business/legal retention is
  decided. Public release still requires alerting, routine review ownership, and
  a documented credential-compromise response.

### CSP migration boundary

The current views contain inline scripts and HTML event handlers. Enforcing a
strict CSP now would break login, lead, and administration interactions. CSP
migration therefore remains a focused follow-up: move event handlers and inline
scripts into same-origin static files or add per-response nonces, validate every
critical route, begin with report-only observation, then enforce. An
`unsafe-inline` production policy is not accepted as closure of this gate.

### Session-store alternatives

| Store | Benefits | Risks / impact | Recommendation |
|---|---|---|---|
| Existing in-memory store | No change | Officially unsuitable for production; sessions disappear on restart; memory/scaling risk | Reject for public use |
| MongoDB-backed store on `db01` | Uses existing protected database host; persistent sessions; no new VM | Adds dependency and a session collection; requires scoped user/retention/index design and backup exclusion/retention decision | Recommended for current hardware, subject to owner approval |
| Redis session store | Common dedicated session design | Adds another service, memory use, security policy, and recovery scope on constrained hardware | Defer |

The MongoDB-backed design is approved for the constrained pilot. Session data
is ephemeral and is excluded from future `crm_prod` application-data archives;
recovery intentionally signs users out. Rollback pins the prior revision
`ae9539ca575df9ffdafe047c49b20fff2473b858`; the unused TTL-managed `sessions`
collection may remain without affecting the prior application.

## Nginx Proxy Manager prerequisites

Before deploying NPM or a proxy host, record and approve:

| Required fact | Status |
|---|---|
| Final CRM FQDN | Owner provided `crm.asalarealestate.com` |
| DNS provider and account control | Owner-controlled Cloudflare zone |
| Public IPv4 or CGNAT status | Owner reports public IPv4 `103.147.107.152`; CGNAT not currently indicated |
| Router ownership and port-forward capability | Owner admin access exists to `D-Link DIR-X3000Z`; port forwarding is available; owner confirms TCP `80`/`443` are currently free |
| NPM host/service design | Internal NPM service is validated on `npm01`; no CRM proxy host, certificate, DNS change, or router rule exists |
| NPM admin identity/secret storage | Approved email is recorded; password remains owner-managed in the approved password manager; TCP `81` remains LAN/VPN-only |
| Certificate method | Owner agreed to review/use Let's Encrypt HTTP-01 on public TCP `80`/`443` first |
| Backend | Planned internal-only backend `http://192.168.10.101:3000`; do not public-forward this port |
| NPM management access | LAN/VPN only; validated internally; TCP `81` must not be publicly forwarded |
| Native IPv6 publication intent | Owner does not require IPv6 publication; keep IPv4-only design |
| Monitoring and renewal alerts | Owner email as the initial alert destination, with a future monitoring system to be added later |

### Required fact package before any proxy/TLS stage

Collect and record the exact owner-controlled inputs listed in the
[NPM Deployment Plan](NPM-Deployment-Plan.md) before designing even a staged
internal CRM proxy/TLS path. This preserves the approved workflow of
documentation, validation, owner approval, implementation, validation, and
changelog.

At minimum, the fact package must capture the intended CRM FQDN, DNS-provider
control path, public IPv4 versus CGNAT status, router ownership and TCP
`80`/`443` forwarding capability, current/public-port conflicts, native IPv6
publication intent, and the desired certificate boundary. If any one of those
items is unknown, stop before proxy-host or TLS design work.

Current owner-reported facts already satisfy the FQDN, DNS-control, public IPv4,
router-admin, and IPv6-intent portions of that package:

- `crm.asalarealestate.com` is the intended CRM FQDN.
- The owner controls the relevant Cloudflare DNS zone and reports the CRM
  subdomain already points to public IPv4 `103.147.107.152`.
- Router admin access exists on `D-Link DIR-X3000Z`, and the owner confirms
  port forwarding is available.
- Native IPv6 publication is not required for this project stage.

The owner has now confirmed that TCP `80` and `443` are currently free on the
router/public-edge path, agreed to use/review HTTP-01 first, and chose the
owner email plus a future monitoring system as the renewal/alert ownership
path.

### Remaining upstream-conflict confirmation checklist

Before approving any proxy-host or HTTP-01 certificate implementation, confirm:

1. The router WAN/public IPv4 shown by `D-Link DIR-X3000Z` matches the intended
   public address `103.147.107.152`.
2. No upstream ISP modem, ONU, or secondary router is performing additional NAT
   or inbound firewalling ahead of `D-Link DIR-X3000Z`.
3. No existing inbound rule on any upstream device already consumes or rewrites
   TCP `80` or `443`.
4. The ISP does not block inbound TCP `80` or `443` for this connection.
5. The owner can reverse any future forwarding rule quickly if proxy or
   certificate validation fails.

### Owner-reported upstream result — 2026-07-19

The owner reports that all five checks above are satisfied:

- `D-Link DIR-X3000Z` shows the intended public IPv4 `103.147.107.152`
- the ISP ONU is upstream of the router, but PPPoE login happens on
  `D-Link DIR-X3000Z`, so no separate upstream NAT/firewall layer is currently
  indicated
- TCP `80` and `443` have not previously been forwarded on this path
- the ISP path has not shown an inbound-forwarding problem on the owner's
  existing use
- the owner has full router control and can remove a future forwarding rule
  quickly if needed

Treat these as owner-reported facts. If later validation contradicts any one of
them, stop before approving the first proxy-host implementation stage.

## Staged validation workflow

### Pre-stage gate — Fact collection

1. Record the owner-controlled fact package described above.
2. Keep `npm01` administration on LAN/VPN only and make no DNS, TLS, proxy-host,
   or router change during this gate.
3. Review the collected facts with the owner before choosing any internal TLS
   validation path or public edge design.

### Stage 1 — Internal proxy only

1. Use the already validated internal NPM service on `npm01`; do not rebuild or
   replace it unless a separate fault-recovery path is approved.
2. Create an internal-only CRM proxy host to `crm01:3000` only after the owner
   reviews the collected facts and separately approves this stage.
3. Do not change the router or public DNS during this stage.
4. Enable `SESSION_COOKIE_SECURE=true` only when testing through trusted HTTPS;
   retain an approved rollback to the internal HTTP canary.
5. Validate health, login, CSRF-protected forms, permissions, forwarding
   headers, logs, memory, and session persistence across an application restart.

### Recommended Stage 1 design for the chosen HTTP-01 path

The chosen certificate path is public HTTP-01, but the first proxy-host
validation should still happen without public DNS or router exposure. The
recommended sequence is:

1. Create one NPM proxy host for `crm.asalarealestate.com` that forwards to
   `http://192.168.10.101:3000`.
2. Keep the proxy internal-only at first: no certificate request, no router
   forwarding, and no public DNS change during this validation step.
3. On one approved LAN client only, add a temporary local host override so
   `crm.asalarealestate.com` resolves to `192.168.10.106`. This validates the
   real production host header and NPM routing path without changing the public
   Internet view.
4. Validate CRM health, login, CSRF-protected actions, permission-sensitive
   routes, audit IP behaviour, rate limiting, and session persistence through
   the proxied path.
5. If the stage is rejected or rolled back, remove only the temporary client
   host override and disable/remove only the CRM proxy host. Do not alter the
   already validated NPM base service or administrator setup.

### Internal proxy-host alternatives

| Option | Benefits | Risks / limitations | Assessment |
|---|---|---|---|
| Temporary hosts-file override on one approved LAN client | Tests the real FQDN and Host header without public DNS or router changes; simplest path toward later HTTP-01 cutover | Requires temporary client-side change and careful rollback/removal | Recommended |
| Temporary alternate internal hostname | Avoids editing one workstation's hosts file | Does not validate the final production host header, cookie domain assumptions, or exact NPM matching path | Not recommended |
| Immediate public DNS/router cutover before internal proxy validation | Tests the real public path sooner | Exposes too many variables at once and weakens rollback isolation | Reject for the first proxy stage |

### Stage 1 validation evidence

Record the following before considering any later certificate or public stage:

1. The exact proxy host name, backend target, and NPM route state.
2. Successful `/healthz` through the proxied FQDN path.
3. Successful login and logout through the proxied FQDN path.
4. Successful CSRF-protected create/edit flows and a permission-sensitive route
   check.
5. Forwarded client IP behaviour in application logs/audit evidence.
6. Session persistence across a CRM container restart while the proxy host
   remains unchanged.
7. Confirmed absence of public DNS change, certificate request, or router rule.

### Applied Stage 1 result — 2026-07-19

The approved internal-only proxy host was created through NPM's native
proxy-host create/configure/reload flow with these current settings:

- domain: `crm.asalarealestate.com`
- backend: `http://192.168.10.101:3000`
- certificate: none
- forced SSL/HSTS: disabled
- public DNS change: none during this stage
- router forwarding: none during this stage

Machine validation confirmed:

1. NPM stored proxy-host row `id=1` with backend `192.168.10.101:3000`,
   `enabled=1`, and `meta.nginx_online=true`.
2. NPM rendered `/data/nginx/proxy_host/1.conf` for
   `crm.asalarealestate.com`.
3. A control-node request using a temporary resolve-equivalent override to
   `192.168.10.106` returned proxied `/healthz` response `{\"status\":\"ok\"}`.
4. A proxied `GET /login` returned HTTP `200` with the expected CRM security
   headers and session-cookie issuance.
5. The direct CRM backend on `crm01:3000` remained healthy during validation.

The following Stage 1 checks are still best completed from one approved LAN
browser client before any certificate/public stage:

- interactive owner login/logout through the proxied FQDN
- representative CSRF-protected create/edit behaviour
- permission-sensitive route confirmation

### Owner LAN-browser validation checklist

Use one approved LAN client only. Before starting, add a temporary local host
override so `crm.asalarealestate.com` resolves to `192.168.10.106`, then open
`http://crm.asalarealestate.com`.

1. Confirm the browser reaches the CRM login page at
   `http://crm.asalarealestate.com/login` or the equivalent unauthenticated
   route, not the NPM admin page and not the old Windows host.
2. Sign in with the approved existing CRM account and confirm the authenticated
   dashboard loads normally.
3. Open one permission-sensitive area that should be allowed for your account
   and confirm it renders successfully.
4. Attempt one representative create or edit workflow that is safe to perform
   on the current pilot dataset, then confirm the save succeeds and the result
   is visible after reload.
5. Sign out and confirm the application returns to the unauthenticated state.
6. Sign back in and confirm the same account can still reach the expected
   dashboard and representative record views.
7. Keep one authenticated browser tab open for the later restart-persistence
   check if that stage is separately approved.

Stop immediately for any redirect loop, broken login, CSRF error, missing
session cookie, wrong permission result, unexpected old-host content, or any
write behaviour that does not match the current internal canary.

### Owner LAN-browser result — 2026-07-19

The owner completed the temporary host-override validation on an approved LAN
client and reported that the internal proxy stage behaved as expected:

- CRM login page loaded through `http://crm.asalarealestate.com`
- authenticated access worked normally
- the proxied application path behaved correctly for the owner's check
- the temporary host override was removed afterward

Browser session continuation after removing the host override is not treated as
an error by itself. The current authenticated browser session and recent DNS or
TCP connection reuse can persist briefly after the local override is removed.
Use a fresh tab, full reload, browser restart, or local DNS-cache flush when a
clean post-override path check is required.

### Proxied restart-persistence result — 2026-07-19

Because the owner had already validated the real proxied login path from an
approved LAN browser, the remaining machine check focused specifically on
authenticated session continuity through the proxied FQDN path after restarting
only the CRM application container.

The validation used one temporary synthetic admin session created inside the
approved MongoDB-backed session store without reading or printing any existing
user password. It then exercised the proxied auth-gated route
`http://crm.asalarealestate.com/admin/users` by targeting `192.168.10.106`
with the correct Host header:

1. An unauthenticated proxied request returned HTTP `302` to `/login`.
2. The same proxied route returned HTTP `200` with the temporary authenticated
   session cookie.
3. Only `realestate-crm-app` was restarted on `crm01`; `/healthz` returned
   `200` again immediately after the restart.
4. The same saved proxied session cookie still returned HTTP `200` from
   `/admin/users` after the application restart.
5. The temporary local cookie file used for the check was deleted afterward.

This result confirms that the current internal NPM proxy path preserves the
approved persistent-session design across an application-container restart. It
does not replace the owner's earlier interactive login validation, and it makes
no certificate, DNS, router, or public-edge change.

### Stage 2 — Public edge readiness

1. Confirm public IP/CGNAT status, FQDN ownership, DNS control, router rules, and certificate method.
2. Forward only TCP 80 and 443 to `npm01`; never forward TCP 81.
3. Obtain and validate the TLS certificate, forced HTTPS, renewal, and security headers.
4. Test externally without exposing administrative interfaces or backend ports.
5. Record rollback: remove public DNS/forwarding, disable the proxy host, and return to internal-only access.

### Stage 3 — Owner release

Release public access only after the owner accepts security, functional, backup, capacity, external scan, logging, and rollback evidence. Publication approval is separate from planning and application-hardening approval.

## HTTP-01-specific boundary

Because the owner selected HTTP-01 first, do not request or validate a
Let's Encrypt certificate until all of the following are true:

1. The internal proxy-host stage above has passed on the real FQDN through the
   temporary LAN-client override.
2. The owner separately approves router forwarding of only TCP `80` and `443`
   to `npm01`.
3. The owner confirms no upstream NAT/firewall rule blocks inbound HTTP-01
   challenge traffic.
4. The owner accepts that public DNS already points the CRM hostname at
   `103.147.107.152`, so certificate validation will probe the real public edge.

Do not use DNS-01 as an implementation shortcut unless the owner later reopens
that method through a separate documented review.

### Applied Stage 2 result — 2026-07-19

The owner approved the first public HTTPS stage and then:

- forwarded only router TCP `80` and `443` to `npm01`
- kept TCP `81` unforwarded
- changed the Cloudflare record for `crm.asalarealestate.com` to `DNS only`
- did not enable a native IPv6 publication path

Implementation then completed as follows:

1. The NPM Docker-aware firewall was adjusted from the earlier LAN-only proxy
   stage so public TCP `80` and `443` are now allowed on `enp6s18`, while TCP
   `81` remains LAN-only. The ingress drop rule stayed interface-scoped so it
   no longer blocked outbound Let's Encrypt API traffic from the NPM
   container.
2. `crm01` was updated to `SESSION_COOKIE_SECURE=true` and the application
   container was recreated successfully; `/healthz` returned `200` afterward.
3. NPM issued Let's Encrypt certificate `id=3` for
   `crm.asalarealestate.com` by direct public HTTP-01. The issued certificate
   is valid through 2026-10-17.
4. Proxy host `id=1` was updated to use certificate `id=3`, `ssl_forced=true`,
   `http2_support=true`, and `hsts_enabled=false`.

Validation confirmed:

1. NPM stored proxy host `id=1` with `certificate_id=3`, `ssl_forced=true`,
   `http2_support=true`, and `meta.nginx_online=true`.
2. Generated NPM config `/data/nginx/proxy_host/1.conf` contains both
   `listen 80;` and `listen 443 ssl;`, the expected server name, and the
   Let's Encrypt certificate paths.
3. The NPM host now listens on `192.168.10.106:80`, `:81`, and `:443`; TCP
   `81` remains LAN-bound by both listener binding and firewall policy.
4. `http://192.168.10.106/login` with Host header
   `crm.asalarealestate.com` returns HTTP `301` to
   `https://crm.asalarealestate.com/login`.
5. `https://crm.asalarealestate.com/login` against the bound NPM listener
   returns HTTP `200` with the expected CRM security headers and a `Secure`
   `crm.sid` cookie.
6. `https://crm.asalarealestate.com/healthz` against the bound NPM listener
   returns `{\"status\":\"ok\"}`.
7. The issued certificate subject is `CN=crm.asalarealestate.com`, the issuer
   is Let's Encrypt `YE2`, and the current resolver view from `npm01` shows
   only IPv4 `103.147.107.152` with no separate native IPv6 answer in use.

Tooling limitation:

- A direct external control-node `curl` validation could not be completed
  because the local tool-approval service rejected the network request before
  execution. Public reachability is still strongly evidenced by the successful
  Let's Encrypt HTTP-01 validation itself, plus the listener/certificate/header
  checks above.

### Owner release result — 2026-07-19

The owner has now accepted the first public HTTPS stage as operationally ready.
Owner-reported acceptance evidence includes:

1. `crm.asalarealestate.com` worked from the external Internet.
2. LAN access was also confirmed acceptable.
3. Normal CRM workflow behaviour was confirmed acceptable by the owner.

This completes the first publication/release gate for the current approved
scope. Remaining work is now limited to later hardening and operational
follow-up items such as HSTS, CSP migration, monitoring/renewal review,
compromised-password screening, MFA direction, and any optional external
negative-path testing.

## Stop conditions

Stop publication work for any authentication bypass, broken CSRF/session behaviour, certificate failure, unexpected public port, proxy-loop/forwarding error, memory or swap pressure, missing backup, inability to roll back, or unresolved CGNAT/DNS ownership issue.

## Owner decisions required

1. Choose internal-only, VPN-only, or eventual public HTTPS access.
2. MongoDB-backed session design is approved and internally validated.
3. The owner-provided FQDN, Cloudflare control, public IPv4, router-admin
   access with port-forward capability, free TCP `80`/`443`, and no-IPv6
   requirement are recorded.
4. Certificate method is owner-approved for first review/use:
   direct public HTTP-01 on TCP `80`/`443`.
5. Monitoring/renewal ownership is owner-approved in principle: use the owner
   email as the initial alert destination and add a future monitoring system
   later.
6. The recommended first proxy-validation method is a temporary hosts-file
   override on one approved LAN client that maps
   `crm.asalarealestate.com` to `192.168.10.106`.
7. The upstream NAT/firewall-conflict checklist is owner-reported complete.
8. The internal NPM CRM proxy host is deployed and validated through both
   machine checks and owner LAN-browser checks, without a certificate or
   router/public-DNS change.
9. The restart-persistence, certificate, public DNS, router-forwarding, and
   first owner release stages are complete for the current scope. Any later
   hardening or architectural change still requires separate review and owner
   approval.

No DNS, NPM service, proxy host, TLS certificate, router forwarding, or CRM configuration was changed by this plan.

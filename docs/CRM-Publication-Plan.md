# CRM Access and HTTPS Publication Plan

**Status:** MongoDB session, login keyboard, rate-limit, and compatible security-header canaries validated; no publication approved
**Scope:** Access path from users to `crm01` through `npm01`
**Current state:** Internal HTTP canary at `crm01:3000`; `npm01` has Docker baseline but no deployed Nginx Proxy Manager service or CRM proxy host

## Current approved design

Public application traffic, if approved, follows one path only:

```text
Internet → Router TCP 80/443 → npm01 → http://192.168.10.101:3000
```

No direct port forwarding to `crm01`, SSH, Proxmox, or MongoDB is permitted. Nginx Proxy Manager administration must remain LAN/VPN-only and must never be forwarded publicly.

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
6. Review password policy, admin-account protection, audit logging, session lifetime, logout invalidation, and incident response.
7. Run dependency, application, and authentication-path tests against the exact deployment revision.

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
| Final CRM FQDN | Pending owner input |
| DNS provider and account control | Pending owner input |
| Public IPv4 or CGNAT status | Pending router/ISP validation |
| Router ownership and port-forward capability | Pending owner validation |
| NPM admin identity/secret storage | Pending; must use Vault/approved password manager |
| Certificate method | Pending; Let's Encrypt HTTP-01 for public 80/443 or approved DNS-01 workflow |
| Backend | Planned `http://192.168.10.101:3000` |
| NPM management access | LAN/VPN only; TCP 81 must not be publicly forwarded |
| Monitoring and renewal alerts | Pending design |

## Staged validation workflow

### Stage 1 — Internal proxy only

1. Deploy Nginx Proxy Manager on `npm01` from documented, pinned configuration after owner approval.
2. Restrict its administration interface to LAN/VPN.
3. Create an internal-only CRM proxy host to `crm01:3000`; do not change the router or public DNS.
4. Enable `SESSION_COOKIE_SECURE=true` only when testing through trusted HTTPS; retain an approved rollback to the internal HTTP canary.
5. Validate health, login, CSRF-protected forms, permissions, forwarding headers, logs, memory, and session persistence across an application restart.

### Stage 2 — Public edge readiness

1. Confirm public IP/CGNAT status, FQDN ownership, DNS control, router rules, and certificate method.
2. Forward only TCP 80 and 443 to `npm01`; never forward TCP 81.
3. Obtain and validate the TLS certificate, forced HTTPS, renewal, and security headers.
4. Test externally without exposing administrative interfaces or backend ports.
5. Record rollback: remove public DNS/forwarding, disable the proxy host, and return to internal-only access.

### Stage 3 — Owner release

Release public access only after the owner accepts security, functional, backup, capacity, external scan, logging, and rollback evidence. Publication approval is separate from planning and application-hardening approval.

## Stop conditions

Stop publication work for any authentication bypass, broken CSRF/session behaviour, certificate failure, unexpected public port, proxy-loop/forwarding error, memory or swap pressure, missing backup, inability to roll back, or unresolved CGNAT/DNS ownership issue.

## Owner decisions required

1. Choose internal-only, VPN-only, or eventual public HTTPS access.
2. MongoDB-backed session design approved; complete internal canary validation before treating this gate as closed.
3. Provide the intended CRM FQDN and DNS provider.
4. Authorize read-only router/public-IP/CGNAT fact collection before any edge change.

No DNS, NPM service, proxy host, TLS certificate, router forwarding, or CRM configuration was changed by this plan.

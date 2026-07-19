# Monitoring Strategy

`mon01` exists as an Ubuntu 24.04 base VM. No monitoring service is deployed yet.

Planned stack: Grafana, Prometheus, and Uptime Kuma.

Decide native versus containerized deployment when the monitoring phase begins. Add `mon01` to the Docker group only if the containerized design is approved.

## Interim CRM HTTPS renewal coverage

Before any dedicated monitoring stack is deployed, the current CRM public HTTPS
publication relies on Nginx Proxy Manager's built-in Let's Encrypt renewal
logic plus owner-visible identity anchoring:

- published host: `crm.asalarealestate.com`
- NPM certificate ID: `3`
- provider: Let's Encrypt
- current validity: `2026-07-19` to `2026-10-17`
- NPM certificate owner/admin identity: `ryansamir90@gmail.com`
- future alerting direction: dedicated monitoring system later

### Validated interim state — 2026-07-19

1. The active certificate on `npm01` is stored in
   `/etc/letsencrypt/live/npm-3/fullchain.pem` with subject
   `CN=crm.asalarealestate.com`, issuer `Let's Encrypt YE2`, and expiry
   `2026-10-17 02:27:51 UTC`.
2. The NPM backend log shows `Let's Encrypt Renewal Timer initialized`.
3. The renewal worker is running on an hourly cadence and recent log windows
   show repeated:
   `Renewing SSL certs expiring within 30 days ...`
   followed by
   `Completed SSL cert renew process`.
4. The certificate record is owned by NPM user ID `1`, whose current email is
   `ryansamir90@gmail.com`.

### Interim operating check

Until `mon01` monitoring is deployed, treat the following as the minimum manual
renewal check:

1. Reconfirm the public site opens at `https://crm.asalarealestate.com`.
2. Reconfirm the current certificate expiry date from NPM at least monthly and
   after any NPM restore or container recreation.
3. Reconfirm recent NPM logs still show the hourly renewal-worker messages.
4. Escalate immediately for any missing renewal log cadence, certificate expiry
   inside 30 days without renewal, repeated renewal errors, or public HTTPS
   failure.

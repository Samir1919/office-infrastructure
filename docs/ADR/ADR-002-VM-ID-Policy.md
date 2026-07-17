# ADR-002: VM ID and IP Address Policy

- **Status:** Accepted
- **Date:** 2026-07-17

Every production VM ID matches the final octet of its static IP address: VM101 → `192.168.10.101`; VM106 → `192.168.10.106`. This supersedes the original illustrative `.10`, `.20`, and similar IP examples.

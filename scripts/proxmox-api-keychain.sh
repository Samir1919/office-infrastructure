#!/bin/sh

exec /usr/bin/security find-generic-password \
  -a 'infra-audit@pve!codex' \
  -s 'office-infrastructure-proxmox-api-token' \
  -w

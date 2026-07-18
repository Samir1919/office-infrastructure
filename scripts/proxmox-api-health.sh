#!/bin/sh

set -eu

PVE_API_IP=${PVE_API_IP:-192.168.10.95}
PVE_API_HOST=${PVE_API_HOST:-pve01.local}
PVE_API_PORT=${PVE_API_PORT:-8006}
PVE_NODE=${PVE_NODE:-pve01}
PVE_STORAGE=${PVE_STORAGE:-local-lvm}
PVE_CERT_FILE=${PVE_CERT_FILE:-"$HOME/.config/office-infrastructure/pve01-presented-cert.pem"}
PVE_TOKEN_ID='infra-audit@pve!codex'
PVE_SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ ! -r "$PVE_CERT_FILE" ]; then
  echo "Verified Proxmox certificate not found: $PVE_CERT_FILE" >&2
  echo "Run scripts/install-proxmox-presented-cert.sh after console fingerprint verification." >&2
  exit 1
fi

PVE_TOKEN_SECRET=$($PVE_SCRIPT_DIR/proxmox-api-keychain.sh)
PVE_API_BASE="https://${PVE_API_HOST}:${PVE_API_PORT}/api2/json"

pve_api_get() {
  /usr/bin/curl \
    --silent \
    --show-error \
    --fail \
    --cacert "$PVE_CERT_FILE" \
    --resolve "${PVE_API_HOST}:${PVE_API_PORT}:${PVE_API_IP}" \
    --header "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}" \
    "${PVE_API_BASE}$1"
}

echo 'Proxmox version'
pve_api_get '/version' | /usr/bin/jq '.data | {version, release, repoid}'

echo 'API token permissions'
pve_api_get '/access/permissions' | /usr/bin/jq '
  .data
  | to_entries
  | map({path: .key, privileges: (.value | keys | sort)})
  | sort_by(.path)'

echo 'pve01 node health'
pve_api_get "/nodes/${PVE_NODE}/status" | /usr/bin/jq --arg node "$PVE_NODE" '
  .data | {
    node: $node,
    status,
    uptime_seconds: .uptime,
    cpu_fraction: .cpu,
    load_average: .loadavg,
    memory_used_bytes: (.memory.used // .memory // .mem),
    memory_total_bytes: (.memory.total // .maxmem),
    swap_used_bytes: (.swap.used // .swap),
    swap_total_bytes: (.swap.total // .maxswap),
    rootfs_used_bytes: (.rootfs.used // null),
    rootfs_total_bytes: (.rootfs.total // null),
    kernel_version: .kversion,
    pve_manager_version: .pveversion
  }'

echo 'pve01 LVM-Thin storage health'
pve_api_get "/nodes/${PVE_NODE}/storage/${PVE_STORAGE}/status" | /usr/bin/jq --arg storage "$PVE_STORAGE" '
  .data | {
    storage: $storage,
    active,
    enabled,
    type,
    content,
    used_bytes: .used,
    available_bytes: .avail,
    total_bytes: .total,
    used_fraction: (if .total > 0 then (.used / .total) else null end)
  }'

echo 'VM resource status'
pve_api_get '/cluster/resources?type=vm' | /usr/bin/jq '
  .data
  | map({vmid, name, node, status, cpu, maxcpu, mem, maxmem, disk, maxdisk, uptime})
  | sort_by(.vmid)'

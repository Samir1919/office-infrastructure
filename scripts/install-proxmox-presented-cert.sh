#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 '<console SHA-256 fingerprint>'" >&2
  exit 2
fi

PVE_EXPECTED_FINGERPRINT=$1
PVE_API_IP=${PVE_API_IP:-192.168.10.95}
PVE_API_HOST=${PVE_API_HOST:-pve01.local}
PVE_CERT_DIR=${PVE_CERT_DIR:-"$HOME/.config/office-infrastructure"}
PVE_CERT_FILE=${PVE_CERT_FILE:-"$PVE_CERT_DIR/pve01-presented-cert.pem"}
PVE_CERT_RAW=$(mktemp /private/tmp/office-infrastructure-pve-cert.XXXXXX)
PVE_CERT_PEM="${PVE_CERT_RAW}.pem"

cleanup() {
  rm -f -- "$PVE_CERT_RAW" "$PVE_CERT_PEM"
}
trap cleanup EXIT HUP INT TERM

openssl s_client \
  -connect "${PVE_API_IP}:8006" \
  -servername "$PVE_API_HOST" \
  </dev/null >"$PVE_CERT_RAW" 2>/dev/null

openssl x509 -in "$PVE_CERT_RAW" -out "$PVE_CERT_PEM"

PVE_ACTUAL_FINGERPRINT=$(openssl x509 \
  -in "$PVE_CERT_PEM" \
  -noout -fingerprint -sha256 | sed 's/^.*=//')

PVE_EXPECTED_NORMALIZED=$(printf '%s' "$PVE_EXPECTED_FINGERPRINT" | sed 's/^.*=//' | tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')
PVE_ACTUAL_NORMALIZED=$(printf '%s' "$PVE_ACTUAL_FINGERPRINT" | sed 's/^.*=//' | tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')

if [ "$PVE_EXPECTED_NORMALIZED" != "$PVE_ACTUAL_NORMALIZED" ]; then
  echo "Certificate fingerprint mismatch; nothing was installed." >&2
  echo "Expected: $PVE_EXPECTED_FINGERPRINT" >&2
  echo "Presented: $PVE_ACTUAL_FINGERPRINT" >&2
  exit 1
fi

mkdir -p "$PVE_CERT_DIR"
chmod 0700 "$PVE_CERT_DIR"
install -m 0600 "$PVE_CERT_PEM" "$PVE_CERT_FILE"

echo "Verified Proxmox certificate installed at: $PVE_CERT_FILE"
openssl x509 -in "$PVE_CERT_FILE" \
  -noout -fingerprint -sha256 -subject -issuer -dates

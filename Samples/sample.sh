#!/usr/bin/env bash
set -euo pipefail

APP_NAME="quicklook-demo"
ENVIRONMENT="staging"
PORTS=(8080 9090 9443)

log() {
  printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"
}

for port in "${PORTS[@]}"; do
  url="http://127.0.0.1:${port}/health"
  log "checking ${APP_NAME} ${ENVIRONMENT} at ${url}"
  curl --fail --silent --show-error --max-time 2 "$url" || true
done

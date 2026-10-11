#!/usr/bin/env bash
# Cold backup of the FreeIPA data volume. Output: backups/ipa-data-<timestamp>.tar.gz
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p backups
TS="$(date +%Y%m%d-%H%M%S)"
docker compose stop
tar -czpf "backups/ipa-data-$TS.tar.gz" data
docker compose start
echo "Backup written: backups/ipa-data-$TS.tar.gz"

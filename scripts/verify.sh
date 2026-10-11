#!/usr/bin/env bash
# Quick health check of the running FreeIPA container.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
set -a; . ./.env; set +a

ok()   { printf '\033[1;32m[PASS]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*"; }

docker inspect -f '{{.State.Running}}' freeipa 2>/dev/null | grep -q true && ok "container running" || fail "container not running"

docker exec freeipa bash -c "echo '$IPA_ADMIN_PASSWORD' | kinit admin" >/dev/null 2>&1 \
  && ok "kinit admin" || fail "kinit admin"

docker exec freeipa ipa user-find --sizelimit=1 >/dev/null 2>&1 \
  && ok "ipa user-find" || fail "ipa user-find"

if command -v dig >/dev/null; then
  dig +short @"$IPA_IP" "$IPA_HOSTNAME" | grep -q "$IPA_IP" && ok "DNS answers for $IPA_HOSTNAME" || fail "DNS lookup"
else
  echo "(install dnsutils to test DNS: sudo apt install dnsutils)"
fi

for p in 80 443 389 636 88 464; do
  timeout 3 bash -c "</dev/tcp/$IPA_IP/$p" 2>/dev/null && ok "tcp/$p open" || fail "tcp/$p closed"
done

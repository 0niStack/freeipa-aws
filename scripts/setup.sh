#!/usr/bin/env bash
# Prepare an Ubuntu 22.04/24.04 EC2 host and start the FreeIPA server container.
# Usage: sudo ./scripts/setup.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"
. /etc/os-release
[[ "$ID" == "ubuntu" ]] || warn "Tested on Ubuntu only (found: $ID)"

# ---- .env ---------------------------------------------------------------
[[ -f .env ]] || { cp .env.example .env; log "Created .env from .env.example"; }
chmod 600 .env
set -a; . ./.env; set +a

[[ "$IPA_HOSTNAME" == *.* ]] || die "IPA_HOSTNAME must be a FQDN"
[[ "$IPA_HOSTNAME" != *.local ]] || die "Do not use .local (conflicts with mDNS)"
[[ "${IPA_HOSTNAME#*.}" == "$IPA_DOMAIN" ]] || warn "Hostname domain differs from IPA_DOMAIN"

set_env() { # key value
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi
}
genpw() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24; }

# ---- passwords ----------------------------------------------------------
if [[ "$IPA_ADMIN_PASSWORD" == "CHANGE_ME" ]]; then
  IPA_ADMIN_PASSWORD="$(genpw)"; set_env IPA_ADMIN_PASSWORD "$IPA_ADMIN_PASSWORD"
  log "Generated admin password (saved in .env)"
fi
if [[ "$IPA_DM_PASSWORD" == "CHANGE_ME" ]]; then
  IPA_DM_PASSWORD="$(genpw)"; set_env IPA_DM_PASSWORD "$IPA_DM_PASSWORD"
  log "Generated Directory Manager password (saved in .env)"
fi

# ---- private IP (IMDSv2, falls back to local route) ---------------------
if [[ -z "${IPA_IP:-}" ]]; then
  TOKEN="$(curl -s -m 3 -X PUT http://169.254.169.254/latest/api/token \
           -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' || true)"
  if [[ -n "$TOKEN" ]]; then
    IPA_IP="$(curl -s -m 3 -H "X-aws-ec2-metadata-token: $TOKEN" \
              http://169.254.169.254/latest/meta-data/local-ipv4 || true)"
  fi
  [[ -n "${IPA_IP:-}" ]] || IPA_IP="$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')"
  [[ -n "$IPA_IP" ]] || die "Could not detect private IP; set IPA_IP in .env"
  set_env IPA_IP "$IPA_IP"
fi
log "Using private IP $IPA_IP"

# ---- hostname -----------------------------------------------------------
log "Setting hostname to $IPA_HOSTNAME"
hostnamectl set-hostname "$IPA_HOSTNAME"
SHORT="${IPA_HOSTNAME%%.*}"
sed -i "/[[:space:]]${IPA_HOSTNAME}\([[:space:]]\|\$\)/d" /etc/hosts
echo "$IPA_IP $IPA_HOSTNAME $SHORT" >> /etc/hosts
mkdir -p /etc/cloud/cloud.cfg.d
echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg

# ---- Docker -------------------------------------------------------------
if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
  log "Installing Docker Engine + Compose plugin"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
fi

# ---- host requirements --------------------------------------------------
MEM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
(( MEM_MB >= 3500 )) || warn "Only ${MEM_MB} MB RAM; use t3.medium (4 GB) or larger"
[[ "$(stat -fc %T /sys/fs/cgroup)" == "cgroup2fs" ]] || warn "Host is not on cgroup v2; the container may not start"

# ---- optional ufw -------------------------------------------------------
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  log "ufw is active: opening FreeIPA ports"
  for p in 80/tcp 443/tcp 389/tcp 636/tcp 88/tcp 88/udp 464/tcp 464/udp 53/tcp 53/udp; do
    ufw allow "$p" >/dev/null
  done
fi

# ---- start --------------------------------------------------------------
mkdir -p data
if [[ -f data/etc/ipa/default.conf ]]; then
  log "Existing FreeIPA data found, starting container"
else
  log "First run: installing FreeIPA (takes roughly 5-10 minutes)"
fi
docker compose pull
docker compose up -d

log "Waiting for installation to finish (Ctrl+C is safe; it keeps running)..."
for _ in $(seq 1 120); do
  if docker logs freeipa 2>&1 | grep -q "FreeIPA server configured\|FreeIPA server started"; then
    log "FreeIPA is up"; break
  fi
  if [[ "$(docker inspect -f '{{.State.Running}}' freeipa 2>/dev/null)" != "true" ]]; then
    die "Container stopped. Check: docker logs freeipa"
  fi
  sleep 10
done

cat <<MSG

 Web UI : https://$IPA_HOSTNAME   (user: admin)
 Admin password / DM password are stored in: $ROOT/.env
 Verify : sudo ./scripts/verify.sh
 Logs   : docker logs -f freeipa

MSG

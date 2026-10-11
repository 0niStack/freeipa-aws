#!/usr/bin/env bash
# Enroll an Ubuntu client into the FreeIPA domain.
# Usage: sudo ./client-enroll.sh <ipa-server-ip> <ipa-fqdn> <domain> <realm> [admin-password]
# Example: sudo ./client-enroll.sh 10.0.1.10 ipa.example.com example.com EXAMPLE.COM
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }
[[ $# -ge 4 ]] || { sed -n '2,4p' "$0"; exit 1; }
IP="$1"; FQDN="$2"; DOMAIN="$3"; REALM="$4"
PW="${5:-}"

# Client needs its own FQDN, e.g. client1.example.com
CLIENT_FQDN="$(hostname -f)"
[[ "$CLIENT_FQDN" == *.* ]] || { echo "Set a client FQDN first: hostnamectl set-hostname client1.$DOMAIN"; exit 1; }

# Use the IPA server for this domain's DNS (systemd-resolved)
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/freeipa.conf <<CONF
[Resolve]
DNS=$IP
Domains=~$DOMAIN
CONF
systemctl restart systemd-resolved
echo "$IP $FQDN" >> /etc/hosts   # bootstrap; remove later if you like

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y freeipa-client

ARGS=(--unattended --domain="$DOMAIN" --realm="$REALM" --server="$FQDN"
      --principal=admin --mkhomedir --force-ntpd)
[[ -n "$PW" ]] && ARGS+=(--password="$PW")
ipa-client-install "${ARGS[@]}" || { echo "Enrollment failed, see /var/log/ipaclient-install.log"; exit 1; }

echo "Enrolled. Test with: id admin@$DOMAIN"

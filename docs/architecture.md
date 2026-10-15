# Architecture

## Overview

```
                 Admin laptop
                      |  https (443)
                      v
   +------------------ AWS VPC ------------------------------+
   |                                                           |
   |   EC2 (Ubuntu 22.04/24.04, Docker)                        |
   |   +---------------------------------------------------+   |
   |   |  Container: freeipa/freeipa-server (Rocky 9)      |   |
   |   |  systemd -> 389-DS, KDC, kadmin, BIND, Dogtag CA, |   |
   |   |             Apache (web UI), custodia             |   |
   |   +-------------------------+-------------------------+   |
   |                             | bind mount                  |
   |                       ./data  ->  /data                   |
   |                                                           |
   |   Ubuntu clients (freeipa-client, SSSD)                   |
   |   --- Kerberos 88/464, LDAP 389/636, DNS 53 --->  server  |
   +-----------------------------------------------------------+
```

## Why a container on Ubuntu?

The FreeIPA **server** packages are only built for the RHEL family. Ubuntu only ships the
**client**. The official `freeipa/freeipa-server` image solves this: the server runs in a
Rocky Linux userland inside Docker, while the host stays Ubuntu.

## Key design decisions

| Decision | Reason |
|---|---|
| systemd inside the container | The image runs all IPA services under systemd. That is why the container needs the host cgroup namespace (`cgroup: host`) and a read-write `/sys/fs/cgroup` mount |
| Ports bound to the private IP | Port 53 would otherwise clash with `systemd-resolved` on `127.0.0.53` |
| `--setup-dns` with `--no-reverse` | The server hosts the zone for the domain. Reverse zones are skipped because AWS controls PTR records |
| `--no-ntp` | AWS Time Sync (`169.254.169.123`) keeps the host clock accurate, and the container shares the host kernel clock |
| `dns: 127.0.0.1` | The server must be able to reach its own DNS service during install |
| `--skip-mem-check` | The installer's memory check fails under cgroup v2 in containers, so the host RAM is verified by `setup.sh` instead |
| Single data directory | Everything lives in `./data`, so backups and restores are simple |

## Data and state

| Path | Content |
|---|---|
| `./data` (host) | All IPA configuration, LDAP data, CA keys and logs |
| `/data` (container) | Same directory as seen by the container |
| `./data/var/log/ipaserver-install.log` | Detailed installer log |
| `.env` | Domain, realm, hostname, IP, passwords (secret) |

If `./data` is deleted, the server is gone. See [operations.md](operations.md) for backups.

## Ports

| Port | Protocol | Service |
|---|---|---|
| 53 | TCP + UDP | DNS |
| 80, 443 | TCP | Web UI and CA |
| 88 | TCP + UDP | Kerberos |
| 464 | TCP + UDP | Kerberos password change |
| 389, 636 | TCP | LDAP, LDAPS |

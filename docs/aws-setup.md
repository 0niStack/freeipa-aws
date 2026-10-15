# AWS setup

## 1. Launch the EC2 instance

| Setting | Value |
|---|---|
| AMI | Ubuntu Server 22.04 or 24.04 LTS |
| Instance type | `t3.medium` (4 GB RAM) or larger |
| Storage | 20 GB gp3 or more |
| Elastic IP | Strongly recommended |

> FreeIPA is tied to its hostname and IP address. Without an Elastic IP, a stop/start can change the
> address and break DNS records and enrolled clients.

A `t3.small` or smaller does not have enough memory for the CA and directory server together.

## 2. Security group

Limit the sources to your VPC CIDR. Also allow 22 and 443 from your admin IP.

| Port | Protocol | Service |
|---|---|---|
| 22 | TCP | SSH |
| 80, 443 | TCP | Web UI / CA |
| 389, 636 | TCP | LDAP / LDAPS |
| 88, 464 | TCP + UDP | Kerberos / kpasswd |
| 53 | TCP + UDP | DNS |

NTP (123/UDP) is not required because the server uses AWS Time Sync.

## 3. Name resolution

FreeIPA needs a fully qualified hostname (for example `ipa.corp.example.com`). Pick one of these ways to
resolve it:

| Option | Best for |
|---|---|
| Route 53 private hosted zone | Machines inside the VPC |
| Hosts file on your laptop | Reaching the web UI from outside |
| VPC DHCP options set with the IPA private IP as DNS | Clients that should use IPA DNS automatically |

Do not use a `.local` domain. It conflicts with mDNS.

## 4. Verify the host

```bash
free -h                                  # about 2 GB or more available
stat -fc %T /sys/fs/cgroup               # must print: cgroup2fs
hostname -f                              # must print the FQDN (setup.sh sets it)
```

Ubuntu 22.04 and 24.04 use cgroup v2 by default.

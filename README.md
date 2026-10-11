# FreeIPA Server on AWS (Ubuntu host)

Automated deployment of a FreeIPA server (LDAP, Kerberos, DNS, CA, web UI) on an Ubuntu EC2 instance.

> **Why a container?** FreeIPA's server packages (`ipa-server`) only exist for the RHEL family
> (RHEL, Rocky, Alma, Fedora). Ubuntu supports the FreeIPA **client** (`freeipa-client`) but not the server.
> This project runs the official `freeipa/freeipa-server` image with Docker on Ubuntu, and enrolls Ubuntu clients natively.

## Project layout

```
freeipa-aws-ubuntu/
├── README.md
├── .env.example          # configuration template
├── docker-compose.yml    # FreeIPA server container
└── scripts/
    ├── setup.sh          # host prep + Docker + start FreeIPA (run on the server)
    ├── verify.sh         # health checks
    ├── client-enroll.sh  # enroll an Ubuntu client (run on clients)
    └── backup.sh         # cold backup of the data volume
```

## 1. Launch the EC2 instance

| Setting | Value |
|---|---|
| AMI | Ubuntu Server 22.04 or 24.04 LTS |
| Instance type | `t3.medium` or larger (4 GB RAM minimum) |
| Storage | 20 GB gp3 or more |
| Elastic IP | Recommended (FreeIPA is tied to its hostname and IP) |

**Security group inbound rules** (limit sources to your VPC CIDR; 22 and 443 also to your admin IP):

| Port | Protocol | Service |
|---|---|---|
| 22 | TCP | SSH |
| 80, 443 | TCP | Web UI / CA |
| 389, 636 | TCP | LDAP / LDAPS |
| 88, 464 | TCP + UDP | Kerberos / kpasswd |
| 53 | TCP + UDP | DNS |

NTP (123/UDP) is not needed: AWS Time Sync (`169.254.169.123`) keeps clocks accurate, and the server runs with `--no-ntp`.

## 2. Configure

```bash
git clone <your-repo> freeipa-aws-ubuntu   # or unzip the project
cd freeipa-aws-ubuntu
cp .env.example .env
nano .env
```

Set at least:

- `IPA_DOMAIN` e.g. `corp.example.com`
- `IPA_REALM` e.g. `CORP.EXAMPLE.COM` (domain in uppercase)
- `IPA_HOSTNAME` e.g. `ipa.corp.example.com`

Do **not** use `.local` domains (they conflict with mDNS). Leave `IPA_IP` empty and the passwords as `CHANGE_ME`;
the script auto-detects the private IP and generates strong passwords.

## 3. Install

```bash
sudo ./scripts/setup.sh
```

The script:

1. Validates `.env` and generates passwords (saved to `.env`, mode 600)
2. Detects the private IP via IMDSv2
3. Sets the hostname, updates `/etc/hosts`, and stops cloud-init from resetting the hostname
4. Installs Docker Engine and the Compose plugin
5. Checks RAM and cgroup v2, and opens ufw ports if ufw is active
6. Pulls the image, starts the container, and waits for the install (about 5-10 minutes)

Port 53 is bound to the private IP only, so it doesn't clash with Ubuntu's `systemd-resolved` on `127.0.0.53`.

## 4. Verify

```bash
sudo ./scripts/verify.sh
docker logs -f freeipa
```

Open `https://<IPA_HOSTNAME>` and log in as `admin` (password in `.env`).
Resolve the name either through a Route 53 private hosted zone, or by adding it to your laptop's hosts file with the Elastic IP.

## 5. Enroll Ubuntu clients

Point clients at the IPA server for DNS. Easiest is a VPC **DHCP options set** with the IPA private IP as the DNS server,
or let the script do it per host. On each client (needs its own FQDN, e.g. `client1.corp.example.com`):

```bash
sudo hostnamectl set-hostname client1.corp.example.com
sudo ./scripts/client-enroll.sh 10.0.1.10 ipa.corp.example.com corp.example.com CORP.EXAMPLE.COM 'AdminPassword'
```

Test with `id admin@corp.example.com`. Home directories are created at first login (`--mkhomedir`).

## Day-2 operations

```bash
docker compose ps                      # status
docker exec -it freeipa bash           # shell inside the server
docker exec freeipa kinit admin        # then run `ipa ...` commands
sudo ./scripts/backup.sh               # stop, archive ./data, start
docker compose pull && docker compose up -d   # upgrade (back up first!)
```

All state lives in `./data`. Keep it on EBS and back it up (snapshot the volume or use `backup.sh`).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Container exits immediately | Host not on cgroup v2, or too little RAM. See `docker logs freeipa` |
| `address already in use` on port 53 | Something else is bound to the private IP:53. `sudo ss -lunp \| grep :53` |
| Clients can't enroll | Security group port closed (88, 389, 464, 53) or client DNS not pointing at IPA |
| Install hangs at hostname check | `hostname -f` must return the FQDN and resolve to the private IP |
| IP changed after stop/start | Use an Elastic IP; changing the IP means re-running with the new `IPA_IP` and fixing DNS records |
| Want to start over | `docker compose down && sudo rm -rf data` (destroys all IPA data) |

## Notes

- Not tested on a live instance from here, so run it in a test VPC first. The image's tags and options can change; check the
  [freeipa-container docs](https://github.com/freeipa/freeipa-container) if the container misbehaves.
- Use strong passwords and restrict the security group. Treat `.env` as a secret (it's in `.gitignore`).
- For production, consider a replica in a second AZ and regular backups.

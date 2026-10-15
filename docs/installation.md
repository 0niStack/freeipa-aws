# Installation

## 1. Get the project

```bash
git clone https://github.com/0niStack/freeipa-aws.git
cd freeipa-aws
```

## 2. Configure

```bash
cp .env.example .env
nano .env
```

Set at least `IPA_DOMAIN`, `IPA_REALM` and `IPA_HOSTNAME`. Leave `IPA_IP` empty and the passwords as
`CHANGE_ME`. See [configuration.md](configuration.md) for every variable.

## 3. Run the installer

```bash
sudo ./scripts/setup.sh
```

What the script does:

1. Validates `.env` and generates passwords (saved to `.env`, mode 600)
2. Detects the private IP through IMDSv2
3. Sets the hostname, updates `/etc/hosts`, and stops cloud-init from resetting the hostname
4. Installs Docker Engine and the Compose plugin
5. Checks RAM and cgroup v2, and opens ufw ports if ufw is active
6. Pulls the image, starts the container, and waits for the install

## 4. Watch the install

```bash
docker logs -f freeipa
```

The first run takes 5-10 minutes. Expected stages:

| Stage | What you see | Typical time |
|---|---|---|
| Boot | `Queued start job for default target Minimal target for containerized FreeIPA server` | seconds |
| Directory server | `Configuring directory server (dirsrv)` | 1-2 min |
| Kerberos, custodia | `Configuring Kerberos KDC`, `Configuring ipa-custodia` | 1 min |
| Certificate server | `Configuring certificate server (pki-tomcatd)` | 3-6 min, often looks frozen |
| Finish | DNS, web UI, `FreeIPA server configured.` | 1-2 min |

During the certificate server stage you may see `A start job is running for Configur… first start (3min 30s / no limit)`.
That is only systemd's status line for the installer and is normal.

Messages such as `certutil: Could not find cert: ... PR_FILE_NOT_FOUND_ERROR` in the CA log are DEBUG
existence checks, not failures. The installer then creates the missing certificate.

To follow the CA step in detail:

```bash
docker exec -it freeipa sh -c 'tail -f /var/log/pki/pki-ca-spawn.*.log'
```

(The `sh -c` matters: the `*` must be expanded inside the container.)

## 5. Verify

```bash
docker exec freeipa ipactl status        # every service RUNNING
sudo ./scripts/verify.sh
```

Then get a ticket and run a command:

```bash
docker exec -it freeipa kinit admin
docker exec -it freeipa ipa user-find admin
```

## 6. Sign in

See [web-ui-access.md](web-ui-access.md).

## Re-running after a failure

A half-finished install leaves bad state in `./data`. Start clean:

```bash
docker compose down
sudo rm -rf data
docker compose up -d
docker logs -f freeipa
```

# Troubleshooting

Start with:

```bash
docker compose ps -a
docker logs --tail 100 freeipa
docker exec freeipa ipactl status
```

Detailed installer log: `./data/var/log/ipaserver-install.log`

## Container starts and exits in a loop

### `Failed to create /init.scope control group: Read-only file system`

systemd cannot write to the cgroup tree.

- The `/sys/fs/cgroup` mount must be `rw`, not `ro`.
- Add `cgroup: host` to the service.

### `Failed to create /init.scope control group: No such file or directory`

The cgroup mount is writable but the container uses a private cgroup namespace. Check:

```bash
docker inspect freeipa --format '{{.HostConfig.CgroupnsMode}}'    # must print: host
docker compose config | grep -n cgroup                            # must show: cgroup: host
```

If `cgroup: host` is missing from the output, the YAML key is not indented under the service, or the file
on the server is not the version you edited. If it is still failing, enable user-namespace remapping in
`/etc/docker/daemon.json` (`{ "userns-remap": "default" }`), restart Docker, and remove `userns_mode: "host"`.

Also confirm the host uses cgroup v2: `stat -fc %T /sys/fs/cgroup` should print `cgroup2fs`.

## Installer errors

### `Unable to determine the amount of available RAM`

The installer's memory check cannot read cgroup v2 memory info in a container. The installer command
includes `--skip-mem-check`. Make sure the host really has about 2 GB or more available (`free -h`).

### Install fails at the DNS or hostname step

- `dns: 127.0.0.1` must be set on the service
- `hostname -f` on the host returns the FQDN, and it resolves to the private IP
- `IPA_FORWARDER` must not be empty (the compose file provides a default)

### `address already in use` on port 53

```bash
sudo ss -lunp | grep :53
```

Ports must be published on the private IP only (`${IPA_IP}:53:53`), so they do not clash with
`systemd-resolved` on `127.0.0.53`.

### Container stays unconfigured after a failed attempt

```bash
docker compose down
sudo rm -rf data
docker compose up -d
```

## Install looks stuck

The certificate server step (`configuring certificate server instance`) takes several minutes and prints
little. Check that work is happening:

```bash
docker stats --no-stream freeipa
docker exec freeipa sh -c 'tail -n 5 /var/log/pki/pki-ca-spawn.*.log'
```

High CPU and advancing log timestamps mean it is progressing. Only worry if the log has not changed for
more than 5 minutes and CPU is near zero.

`ipactl status` printing `IPA is not configured` during the install is expected.

## Commands

### `ipa: ERROR: unknown command 'kinit'`

`kinit` is not an `ipa` subcommand. Run `kinit admin`, then `klist`.

### `docker exec ... tail /var/log/pki/pki-ca-spawn.*.log` says no such file

The `*` was expanded by the host shell. Run it through a shell in the container:

```bash
docker exec freeipa sh -c 'tail -n 5 /var/log/pki/pki-ca-spawn.*.log'
```

## `setup.sh` never says "FreeIPA is up"

With `set -o pipefail`, `docker logs | grep -q` can report failure even when grep matches, because
`docker logs` receives SIGPIPE when grep exits early. Replace the check in the wait loop with:

```bash
logs="$(docker logs freeipa 2>&1 || true)"
if grep -q "FreeIPA server configured\|FreeIPA server started" <<<"$logs"; then
  log "FreeIPA is up"; break
fi
```

## Web UI

| Symptom | Fix |
|---|---|
| Timeout | Security group 443 closed, wrong IP in hosts file |
| Redirect to another name | Use the exact `IPA_HOSTNAME`, not the IP |
| Certificate warning | Expected; import `https://<IPA_HOSTNAME>/ipa/config/ca.crt` to trust it |
| Wrong password | `grep IPA_ADMIN_PASSWORD .env`, then `docker exec -it freeipa kinit admin` |

## Clients

| Symptom | Fix |
|---|---|
| Cannot enroll | Ports 88, 389, 464, 53 closed, or client DNS does not point at IPA |
| `Unable to find IPA Server` | Check `dig SRV _ldap._tcp.corp.example.com @<IPA_IP>` |
| Time skew | `chronyc tracking`; AWS Time Sync should keep clocks aligned |
| IP changed after stop/start | Use an Elastic IP, update `IPA_IP` and fix DNS records |

## GitHub Actions

FreeIPA needs systemd, a writable cgroup tree and about 2 GB of RAM, so it will not run reliably on a
standard hosted runner. Use CI only for static checks (`shellcheck scripts/*.sh`, `docker compose config`)
and deploy on EC2.

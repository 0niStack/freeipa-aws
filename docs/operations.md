# Operations

## Status and logs

```bash
docker compose ps
docker logs -f freeipa
docker exec freeipa ipactl status
sudo ./scripts/verify.sh
```

## Start, stop, restart

```bash
docker compose stop
docker compose start
docker compose restart
```

Allow a minute or two after a start for all IPA services to come up.

## Backup

All state lives in `./data`. For a consistent cold backup:

```bash
sudo ./scripts/backup.sh          # stops the container, archives ./data, starts it again
```

The archive contains CA private keys and password hashes. Store it encrypted and off the instance (for
example in a private S3 bucket with encryption enabled). Also consider EBS snapshots of the data volume.

## Restore

```bash
docker compose down
sudo rm -rf data
sudo tar -xzf <backup-file>.tar.gz     # restores ./data
docker compose up -d
docker logs -f freeipa
```

Restore onto an instance with the **same hostname and IP**. Check the archive's layout first so that
`./data` ends up in the project directory.

## Upgrade

```bash
sudo ./scripts/backup.sh               # always back up first
docker compose pull
docker compose up -d
docker logs -f freeipa
```

The container detects data written by a different image version and upgrades the configuration and data on
start. Pin `IPA_IMAGE` to a specific tag for predictable upgrades.

## Start over

```bash
docker compose down
sudo rm -rf data
docker compose up -d
```

This destroys all IPA data.

## IP address changes

If the instance IP changes (no Elastic IP), update `IPA_IP` in `.env`, fix the DNS records, and re-enroll
or update clients. Use an Elastic IP to avoid this.

## High availability

For production, add a replica in a second Availability Zone with `ipa-replica-install`, and keep regular
backups. A single container is a single point of failure for authentication.

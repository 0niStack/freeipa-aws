# User management, access control and sudo

Run these commands inside the container after getting a ticket:

```bash
docker exec -it freeipa bash
kinit admin
```

Note: `kinit` is a standalone command, not `ipa kinit`.

## Users

```bash
ipa user-add alice --first=Alice --last=Smith --password
ipa user-show alice
ipa user-find
ipa passwd alice                 # reset a password
ipa user-disable alice
ipa user-del alice
```

New users must change their temporary password at first login.

## Groups

```bash
ipa group-add devops --desc="DevOps team"
ipa group-add-member devops --users=alice,bob
ipa group-show devops
```

## Hosts and host groups

Enrolled clients appear automatically. Group them for easier rules:

```bash
ipa host-find
ipa hostgroup-add iptv-hosts --desc="IPTV servers"
ipa hostgroup-add-member iptv-hosts --hosts=iptv01.corp.example.com
```

## Host-based access control (who can log in where)

By default the `allow_all` rule lets every user log in to every host. To restrict access, create
specific rules, then disable `allow_all`.

Let `alice` log in only to `iptv01`:

```bash
ipa hbacrule-add alice_iptv
ipa hbacrule-add-user alice_iptv --users=alice
ipa hbacrule-add-host alice_iptv --hosts=iptv01.corp.example.com
ipa hbacrule-add-service alice_iptv --hbacsvcs=sshd
```

Keep `admin` able to reach every host (create this **before** disabling `allow_all`):

```bash
ipa hbacrule-add admins_all --hostcat=all --servicecat=all
ipa hbacrule-add-user admins_all --groups=admins
```

Now disable the default rule and test:

```bash
ipa hbacrule-disable allow_all
ipa hbactest --user=alice --host=iptv01.corp.example.com --service=sshd
```

`ipa hbactest` shows whether access would be granted and which rule matched.

## Sudo rules (who can sudo where)

Clients need `libsss-sudo` installed (see [client-enrollment.md](client-enrollment.md)).

Let `alice` run any command with sudo on `iptv01` only:

```bash
ipa sudorule-add alice_iptv_sudo
ipa sudorule-add-user alice_iptv_sudo --users=alice
ipa sudorule-add-host alice_iptv_sudo --hosts=iptv01.corp.example.com
ipa sudorule-mod alice_iptv_sudo --cmdcat=all
```

To allow only specific commands, add them instead of `--cmdcat=all`:

```bash
ipa sudocmd-add /usr/bin/systemctl
ipa sudorule-add-allow-command alice_iptv_sudo --sudocmds=/usr/bin/systemctl
```

Refresh the cache on the client after changes:

```bash
sudo sss_cache -E
sudo -l -U alice
```

## SSH keys

```bash
ipa user-mod alice --sshpubkey="ssh-ed25519 AAAA... alice@laptop"
```

Enrolled hosts fetch the key through SSSD.

## Tips

- Prefer groups over individual users in rules so access is easy to audit.
- Always test with `ipa hbactest` before disabling `allow_all`.
- Keep a break-glass path (the `admin` account and SSH key access to the EC2 host).

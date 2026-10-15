# Enrolling Ubuntu clients

Ubuntu supports the FreeIPA **client** natively through the `freeipa-client` package.

## Prerequisites

| Requirement | Detail |
|---|---|
| Client FQDN | For example `client1.corp.example.com` |
| DNS | The client must resolve the IPA server and the SRV records. Point it at the IPA server's private IP |
| Network | Ports 88, 464, 389, 636, 53 and 443 open from the client to the server |
| Time | Within a few minutes of the server (AWS Time Sync handles this on EC2) |

### Point the client at IPA DNS

The easiest way is a VPC **DHCP options set** with the IPA private IP as the domain name server.
Alternatively `scripts/client-enroll.sh` configures it per host.

## Enroll with the script

```bash
sudo hostnamectl set-hostname client1.corp.example.com
sudo ./scripts/client-enroll.sh 10.0.1.10 ipa.corp.example.com corp.example.com CORP.EXAMPLE.COM 'AdminPassword'
```

Arguments in order: IPA private IP, IPA FQDN, domain, realm, admin password.

## Enroll manually

```bash
sudo apt-get update
sudo apt-get install -y freeipa-client chrony libsss-sudo
sudo hostnamectl set-hostname client1.corp.example.com

sudo ipa-client-install \
  --hostname="$(hostname -f)" \
  --server=ipa.corp.example.com \
  --domain=corp.example.com \
  --realm=CORP.EXAMPLE.COM \
  --principal=admin \
  --password='AdminPassword' \
  --mkhomedir \
  --no-ntp \
  --unattended
```

`libsss-sudo` is needed if you plan to use central sudo rules (see [user-management.md](user-management.md)).
`--mkhomedir` creates home directories at first login.

## Test

```bash
id admin@corp.example.com
kinit admin
klist
```

Log in as a directory user over SSH:

```bash
ssh alice@client1.corp.example.com
```

## Un-enroll

```bash
sudo ipa-client-install --uninstall
```

Then remove the host entry on the server with `ipa host-del client1.corp.example.com`.

## Common problems

| Symptom | Fix |
|---|---|
| `Unable to find IPA Server to join` | Client DNS does not point at IPA, or SRV records not reachable |
| Hostname error | `hostname -f` must return the FQDN |
| Time skew errors | Check `chronyc tracking` |
| `Cannot contact any KDC` | Security group ports 88/464 closed |

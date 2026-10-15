# Accessing the web UI

URL: `https://<IPA_HOSTNAME>/ipa/ui/`, for example `https://ipa.corp.example.com/ipa/ui/`

## Use the hostname, not the IP

FreeIPA redirects requests that do not use its FQDN, so `https://<ip-address>` will not work.

## 1. Find the public IP

In the EC2 console, or on the server:

```bash
TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4
```

## 2. Make the hostname resolve on your laptop

`corp.example.com` is not public DNS, so add a hosts entry:

```
<PUBLIC_IP>   ipa.corp.example.com
```

| OS | File |
|---|---|
| Windows | `C:\Windows\System32\drivers\etc\hosts` (edit as Administrator) |
| macOS / Linux | `/etc/hosts` (`sudo nano /etc/hosts`) |

## 3. Open the port

Allow inbound TCP 443 (and 80 for the redirect) from your IP in the security group.

## 4. Sign in

| Field | Value |
|---|---|
| Username | `admin` |
| Password | `IPA_ADMIN_PASSWORD` from `.env` (`grep IPA_ADMIN_PASSWORD .env`) |

## Certificate warning

The server certificate is issued by FreeIPA's own CA, which your browser does not trust. Choose
"Advanced" and continue. To remove the warning, download the CA certificate from
`https://ipa.corp.example.com/ipa/config/ca.crt` and import it into your browser or operating system.

## If it does not work

| Problem | Check |
|---|---|
| Page times out | Security group port 443, hosts entry, correct public IP |
| Redirected to another hostname | You opened it by IP or a name other than `IPA_HOSTNAME` |
| Login fails | `docker exec -it freeipa kinit admin` to test the password at the Kerberos level |
| Test from the laptop | `curl -k https://ipa.corp.example.com/ipa/ui/` |

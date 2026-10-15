# Security checklist

## Network

- [ ] Security group sources limited to the VPC CIDR; SSH (22) and HTTPS (443) also limited to admin IPs
- [ ] Ports 389/636 (LDAP/LDAPS), 88/464 (Kerberos) and 53 (DNS) not exposed to the internet
- [ ] Elastic IP attached so the address is stable

## Secrets

- [ ] `.env` has mode 600 and is never committed (it is in `.gitignore`)
- [ ] Admin password stored in a password manager, then rotated from the default generated value if shared
- [ ] Backups encrypted and stored off the instance (they contain CA keys)

```bash
ls -l .env            # -rw------- expected
git check-ignore .env # should print .env
```

## Accounts

- [ ] Use named admin accounts for daily work and keep `admin` as break-glass
- [ ] Enforce password policy: `ipa pwpolicy-mod --minlength=12 --maxfail=5`
- [ ] Use SSH keys through `ipa user-mod --sshpubkey`
- [ ] Restrict logins with HBAC rules instead of leaving `allow_all` enabled (see [user-management.md](user-management.md))

## Host

- [ ] Enable unattended security updates on the Ubuntu host
- [ ] Keep Docker and the FreeIPA image updated (back up first)
- [ ] Use IMDSv2 only on the instance
- [ ] Do not run other services on the IPA server

## Certificates

- [ ] Download and distribute the CA certificate (`/ipa/config/ca.crt`) so clients trust the server
- [ ] Track certificate expiry: `docker exec freeipa ipa-getcert list`

## Container

- [ ] Do not use `privileged: true`; it is not supported by the image
- [ ] Do not publish ports you do not need

# Hetzner Auction Ubuntu 24.04 Server

Config and helpers for a Hetzner auction server running Ubuntu 24.04.

## Set Up

### 1. SSH config: [`/etc/ssh/sshd_config`](./etc/ssh/sshd_config)

This is a hardened OpenSSH server config. It:

- **Disables root SSH:** `PermitRootLogin no`
- **Key-only auth:** password and keyboard-interactive are off; only `PubkeyAuthentication` is used
- **Restricts login to one user:** `AllowUsers server` (only `server` can SSH)
- **Keeps PAM** for account/session handling
- **Disables X11 forwarding**

## Services

| Service         | Port | Subdomain          |
| --------------- | ---- | ------------------ |
| Keycloak (Auth) | 2404 | auth.yongbeom.net  |
| Linkwarden      | 2405 | links.yongbeom.net  |
| Nextcloud AIO   | 2406 | -                  |

### KeyCloak

1. Create Realm

- Create realm (`apps`)

2. Create Client
   - Protocol: **OpenID Connect**
   - Client ID: **`linkwarden`**
   - Client authentication: **ON**
   - Standard flow: **ON**
   - Implicit flow: **OFF**
   - Direct access grants: **OFF**
   - Service accounts roles: **OFF**
   - Valid Redirect URIs: **`https://links.yongbeom.net/api/auth/callback/keycloak`**
   - Web Origins: **`https://links.yongbeom.net`**
3. Get Client Secret
   - In `Clients → linkwarden → Credentials` paste client secret into `.env`
4. Environment Variables:

```env
NEXT_PUBLIC_KEYCLOAK_ENABLED=1
KEYCLOAK_CUSTOM_NAME=Keycloak
KEYCLOAK_ISSUER=http://auth.yongbeom.net/realms/apps
KEYCLOAK_CLIENT_ID=linkwarden
KEYCLOAK_CLIENT_SECRET=...
```

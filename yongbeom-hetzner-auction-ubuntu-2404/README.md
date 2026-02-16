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

| Service         | Port | Subdomain         |
| --------------- | ---- | ----------------- |
| Keycloak (Auth) | 2404 | auth.yongbeom.net |

### KeyCloak

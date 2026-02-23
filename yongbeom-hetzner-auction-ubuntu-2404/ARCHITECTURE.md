# Architecture

## Service Summary

| Service | Summary |
|---|---|
| Caddy | Public HTTPS entrypoint and reverse proxy routing traffic to each internal app service by hostname. |
| Keycloak | Central identity provider (SSO/OIDC) backed by PostgreSQL, with a dedicated automated backup job. |
| Linkwarden | Bookmark/archive application backed by PostgreSQL + Meilisearch, with a dedicated automated backup job. |
| Nextcloud AIO | Self-hosted drive/collaboration suite managed via the AIO master container. |
| Vaultwarden | Lightweight Bitwarden-compatible password manager with a dedicated automated backup job. |
| OpenBao | Secrets management service (Vault-compatible) using local raft storage, with a dedicated automated backup job. |
| Immich | Photo/video management platform with its API server, ML worker, Redis (Valkey), PostgreSQL, and backup job. |
| Forgejo | Self-hosted git forge backed by PostgreSQL, with a dedicated automated backup job. |
| Offline Notion | Self-hosted Notion-like stack (client, backend, Redis, VoidAuth) with a dedicated backup job. |
| AWS Route53 DNS module | Creates A/AAAA records (including `www`) for each service domain. |
| Backup bucket module (B2 + Cloudflare R2) | Provisions per-service object storage buckets used as backup destinations. |

## Architecture Diagram

<img width="2089" height="2181" alt="image" src="https://github.com/user-attachments/assets/702e9cd3-1821-4a70-868e-ad10f7ed74bf" />


## Sources Used

- `yongbeom-hetzner-auction-ubuntu-2404/tofu-infra/main.tf`
- `yongbeom-hetzner-auction-ubuntu-2404/tofu-infra/aws-dns-record/dns.tf`
- `yongbeom-hetzner-auction-ubuntu-2404/tofu-infra/backup_bucket/main.tf`
- `yongbeom-hetzner-auction-ubuntu-2404/caddy/Caddyfile`
- `yongbeom-hetzner-auction-ubuntu-2404/docker-compose.yaml`
- `yongbeom-hetzner-auction-ubuntu-2404/{keycloak,linkwarden,nextcloud,vaultwarden,openbao,immich}/docker-compose.yaml`
- `yongbeom-hetzner-auction-ubuntu-2404/BACKUPS.md`
- `yongbeom-hetzner-auction-ubuntu-2404/*/backup/crontab`
- `yongbeom-hetzner-auction-ubuntu-2404/offline-notion/docker-compose.yml`

# Backups Runbook (Reviewed, Excluding Git Submodules)

This document is the current-state backup runbook for first-party services in this repo.
Excluded from this review by request: git submodules (including `offline-notion`).

## Scope

Services reviewed:
- `immich`
- `keycloak`
- `linkwarden`
- `openbao`
- `vaultwarden`

Not covered by current sidecar backup:
- `nextcloud` (uses its own lifecycle and should follow official Nextcloud AIO backup/restore guidance)

## Current Strategy Summary

- Backup mechanism: per-service `backup` container running `restic` + `supercronic`.
- Repositories: Backblaze B2 (`B2_REPO`) and Cloudflare R2 (`R2_REPO`).
- Encryption: restic repository encryption via `RESTIC_PASSWORD`.
- Concurrency control: local lock directory (`/tmp/backup.lock`) per backup container.
- Retention defaults:
  - Most services: `--keep-daily 7 --keep-weekly 4 --keep-monthly 12`
  - OpenBao adds `--keep-hourly 24` (15-minute schedule).
- Execution model: scheduled inside backup containers, not host cron.

## Service Matrix (As Implemented)

| Service | Schedule | Backed up data | DB approach | Downtime impact |
|---|---|---|---|---|
| `immich` | `03:10` daily | `/data/immich` (bind mounts include server files and raw postgres dir) | Optional `pg_dumpall` when PG env vars are set | No intentional stop/start |
| `keycloak` | `03:25` daily | `/data` containing `pgdump.dump` | Required `pg_dump --format=custom` before restic | No intentional stop/start |
| `linkwarden` | `03:40` daily | `/data/linkwarden` (includes app files, meilisearch data, postgres data dir) | No logical dump; file-level capture after stopping containers | Stops `linkwarden_server`, `linkwarden_meilisearch`, `linkwarden_postgres` during backup |
| `openbao` | Every `15` minutes | Raft snapshot file (`bao operator raft snapshot save`) | Service-native raft snapshot | No app container stop, snapshot via API/token |
| `vaultwarden` | `04:20` daily | `/data/vaultwarden` | File-level backup only | Stops `vaultwarden` during backup |

References:
- Schedules: `immich/backup/crontab`, `keycloak/backup/crontab`, `linkwarden/backup/crontab`, `openbao/backup/crontab`, `vaultwarden/backup/crontab`
- Logic: each service `backup/backup.sh`
- Wiring: each service `docker-compose.yaml`

## Environment Variables (Actual Names)

Global required:
- `RESTIC_PASSWORD`

B2:
- `B2_REPO`
- `B2_ACCOUNT_ID`
- `B2_ACCOUNT_KEY`

R2:
- `R2_REPO`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` (usually `auto`)

Retention:
- `KEEP_DAILY`
- `KEEP_WEEKLY`
- `KEEP_MONTHLY`
- `KEEP_HOURLY` (OpenBao)

Service-specific examples:
- Postgres dumps: `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`
- OpenBao snapshot auth: `VAULT_ADDR`, `VAULT_TOKEN`

## Risk Review

1. Documentation drift existed and is now corrected here:
- Prior doc had wrong schedule/behavior for multiple services.
- Prior doc referenced `B2_APPLICATION_KEY_ID/B2_APPLICATION_KEY`, but scripts use `B2_ACCOUNT_ID/B2_ACCOUNT_KEY`.

2. Database protection strategy is inconsistent:
- `keycloak` uses logical dump (`pg_dump`) and is restore-friendly.
- `immich` mixes raw postgres files and optional `pg_dumpall`.
- `linkwarden` backs up raw postgres files without logical dump.

3. Downtime tradeoff:
- `linkwarden` and `vaultwarden` backups intentionally stop services.
- This improves consistency for file-level snapshots but creates backup-window unavailability.

4. No explicit backup health verification loop:
- No built-in scheduled `restic check`.
- No automated alerting on backup failure.

5. Partial-failure handling differs by service:
- `keycloak` logs repo-level failures but still reaches a success end-path, reducing signal clarity.

## Restore Procedures

### 1) Restore files from restic

```bash
export RESTIC_PASSWORD='...'
export RESTIC_REPOSITORY='b2:<bucket>:<path>'  # or s3:https://<r2-endpoint>/<bucket>/<path>

# For B2
export B2_ACCOUNT_ID='...'
export B2_ACCOUNT_KEY='...'

# For R2
export AWS_ACCESS_KEY_ID='...'
export AWS_SECRET_ACCESS_KEY='...'
export AWS_DEFAULT_REGION='auto'

restic snapshots
restic restore <snapshot_id> --target /tmp/restore
```

### 2) Restore Keycloak database dump (`pg_dump --format=custom`)

```bash
pg_restore \
  -h <postgres_host> \
  -p 5432 \
  -U <postgres_user> \
  -d <database_name> \
  /tmp/restore/data/pgdump.dump
```

### 3) Restore Immich `pg_dumpall` output (plain SQL, if present)

`pg_dumpall` output is plain SQL and should be restored with `psql`, not `pg_restore`.

```bash
psql \
  -h <postgres_host> \
  -p 5432 \
  -U <postgres_superuser> \
  -f /tmp/restore/data/immich/pgdumpall/pgdump.sql
```

### 4) Restore OpenBao raft snapshot

Use OpenBao raft snapshot restore workflow against a stopped/unsealed target per OpenBao operational procedure, using the restored `openbao.raft` artifact.

## Validation Checklist (Operational)

- Confirm each backup container is running and cron has executed in the last 24h (OpenBao: last 15m).
- Confirm both repositories receive snapshots for each service where dual-target is expected.
- Perform at least quarterly restore drills:
  - File restore drill for each service.
  - DB restore drill for `keycloak`.
  - OpenBao raft snapshot restore drill in a non-production environment.
- Record restore time and missing steps back into this file.

## Priority Improvements

1. Standardize DB backups:
- Add logical dump for `linkwarden` postgres.
- Decide whether `immich` should keep raw PG files or rely on logical dump only.

2. Add integrity verification:
- Add scheduled `restic check` (for both B2 and R2 repos).

3. Tighten failure signaling:
- Make backup containers fail hard on any repo failure.
- Add log-based alerting or notification on failed runs.

4. Nextcloud:
- Document official Nextcloud AIO backup/restore process separately and link it here.

# Backup Sidecar Standard

This repository now applies a uniform `backup` service per Compose project using a restic sidecar.

## What it does

- Runs inside each project as service name `backup`.
- Uses labels:
  - `com.backup.enabled=true`
  - `com.backup.project=<project_dir_name>`
- Schedules backups daily via supercronic inside each backup container.
- Sends backups to both remotes when configured:
  - Backblaze B2 via restic `b2:` repo (`B2_REPO`).
  - Cloudflare R2 via restic `s3:` repo (`R2_REPO` + AWS-compatible credentials).
- Applies retention:
  - `--keep-daily 7`
  - `--keep-weekly 4`
  - `--keep-monthly 12`
- Logs to stdout/stderr.

## Backup timing (staggered)

Backups are intentionally staggered so postgres logical dumps do not start at the same minute.

| Project | Daily time (local) | Notes |
|---|---|---|
| immich | 03:10 | includes `pg_dump` |
| keycloak | 03:25 | includes `pg_dump` |
| linkwarden | 03:40 | includes `pg_dump` |
| offline-notion | 04:00 | file backup |
| openbao | 04:10 | file backup |
| vaultwarden | 04:20 | file backup |

Timing is configured per project in `backup/crontab`.

## TODO

- Nextcloud: confirm and adopt the official Nextcloud AIO-recommended backup/restore solution instead of restic sidecar file backup.

## Data selection rules

- Bind-mounted app data is mounted read-only under `/data/<service>/<mount_name>`.
- Raw postgres data directories are excluded from file-level backup.
- If postgres is detected/configured, `backup.sh` also runs logical backup using `pg_dump` over Docker networking (`PGHOST` etc.).
- If `BACKUP_PATHS` is unset, `backup.sh` defaults to backing up `/data`.

## Required environment variables

- Always:
  - `RESTIC_PASSWORD`
- B2 target:
  - `B2_REPO`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`
- R2 target:
  - `R2_REPO`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION` (`auto` default)
- Retention (optional overrides):
  - `KEEP_DAILY`, `KEEP_WEEKLY`, `KEEP_MONTHLY`
- Optional data path override:
  - `BACKUP_PATHS` (space-separated paths)
- Optional postgres logical backup:
  - `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`

## Restore examples

### Restore files

```bash
export RESTIC_PASSWORD='...'
export RESTIC_REPOSITORY='b2:bucket/path'
export B2_ACCOUNT_ID='...'
export B2_ACCOUNT_KEY='...'

restic snapshots
restic restore <snapshot_id> --target /tmp/restore
```

### Restore postgres dump

```bash
pg_restore \
  -h <postgres_host> \
  -p 5432 \
  -U <postgres_user> \
  -d <database_name> \
  /tmp/restore/tmp/backup-artifacts/postgres-<db>-<timestamp>.dump
```

Adjust restore paths to match the selected snapshot and mount layout.

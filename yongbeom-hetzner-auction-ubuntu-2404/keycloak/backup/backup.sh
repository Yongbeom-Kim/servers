#!/bin/sh
#
# Required environment variables:
#   RESTIC_PASSWORD          - Password for the restic repository
#
#   At least one of the following repository variables must be set:
#     B2_REPO         - Restic repository URL for Backblaze B2 (e.g. "b2:my-bucket:path")
#       B2_APPLICATION_KEY_ID - B2 account/app key id
#       B2_APPLICATION_KEY   - B2 account/app key
#
#     R2_REPO         - Restic repository URL for Cloudflare R2/S3-compatible
#       AWS_ACCESS_KEY_ID     - AWS/R2 Access Key ID (required if R2_REPO is set)
#       AWS_SECRET_ACCESS_KEY - AWS/R2 Secret Access Key (required if R2_REPO is set)
#       AWS_DEFAULT_REGION    - AWS region (optional for R2; default: 'auto')
#
# Optional environment variables:
#   KEEP_DAILY      - Number of daily backups to keep (default: 7)
#   KEEP_WEEKLY     - Number of weekly backups to keep (default: 4)
#   KEEP_MONTHLY    - Number of monthly backups to keep (default: 12)
#

set -eu

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*"
}

KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-12}"

LOCK_DIR="/tmp/backup.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another backup run is active; skipping"
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT INT TERM

BACKUP_PATH=/data
mkdir -p "$BACKUP_PATH"

PG_DUMP_PATH="${BACKUP_PATH}/pgdump.dump"

export PGPASSWORD
log "creating pg_dump from ${PGHOST}:${PGPORT:-5432}/${PGDATABASE}"

if ! pg_dump \
  --format=custom \
  --no-owner \
  --no-privileges \
  -h "${PGHOST}" \
  -p "${PGPORT:-5432}" \
  -U "${PGUSER}" \
  -d "${PGDATABASE}" \
  -f "$PG_DUMP_PATH"; then
  log "pg_dump failed"
  exit 1
fi

run_repo() {
  repo_name="$1"
  repo_url="$2"
  shift 2

  if [ -z "$repo_url" ]; then
    log "$repo_name repository is not set; skipping"
    return 0
  fi

  export RESTIC_REPOSITORY="$repo_url"
  if ! restic snapshots >/dev/null 2>&1; then
    log "initializing $repo_name repository"
    restic init
  fi

  log "running restic backup to $repo_name"
  log "backing up files in $@"
  ls -l "$@"
  restic backup "$@"
  restic forget \
    --prune \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY"
}

export B2_ACCOUNT_ID B2_ACCOUNT_KEY
if run_repo "B2" "$B2_REPO" /data; then
  log "B2 backup completed successfully"
else
  log "B2 backup failed"
fi

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
if run_repo "R2" "$R2_REPO" /data; then
  log "R2 backup completed successfully"
else
  log "R2 backup failed"
fi

log "backup completed successfully"

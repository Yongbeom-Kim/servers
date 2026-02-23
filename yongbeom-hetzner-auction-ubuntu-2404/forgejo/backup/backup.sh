#!/bin/sh
#
# Backs up Forgejo PostgreSQL database (pg_dump) and data directory with restic.
# No container stop required: pg_dump provides a consistent DB snapshot and
# git objects are immutable files.
#
# Required environment variables:
#   RESTIC_PASSWORD          - Password for the restic repository
#   PGHOST, PGDATABASE, PGUSER, PGPASSWORD - Postgres connection
#
#   At least one of the following repository variables must be set:
#     B2_REPO         - Restic repository URL for Backblaze B2
#       B2_ACCOUNT_ID  - B2 account id
#       B2_ACCOUNT_KEY - B2 account key
#
#     R2_REPO         - Restic repository URL for Cloudflare R2/S3-compatible
#       AWS_ACCESS_KEY_ID     - AWS/R2 Access Key ID
#       AWS_SECRET_ACCESS_KEY - AWS/R2 Secret Access Key
#       AWS_DEFAULT_REGION    - AWS region (optional; default: 'auto')
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
BACKUP_PATH="${BACKUP_PATH:-/data/forgejo}"

LOCK_DIR="/tmp/backup.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another backup run is active; skipping"
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT INT TERM

# --- pg_dump ---
PG_DUMP_DIR="/data/pgdump"
PG_DUMP_PATH="${PG_DUMP_DIR}/pgdump.dump"
mkdir -p "$PG_DUMP_DIR"

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

# --- restic backup (pgdump + data) ---
run_repo() {
  repo_name="$1"
  repo_url="$2"

  if [ -z "$repo_url" ]; then
    log "$repo_name repository is not set; skipping"
    return 0
  fi

  export RESTIC_REPOSITORY="$repo_url"
  if ! restic snapshots >/dev/null 2>&1; then
    log "initializing ${repo_name} repository"
    restic init
  fi

  log "running restic backup to $repo_name"
  restic backup "$BACKUP_PATH" "$PG_DUMP_DIR"
  restic forget \
    --prune \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY"
}

export B2_ACCOUNT_ID B2_ACCOUNT_KEY
if run_repo "B2" "$B2_REPO"; then
  log "B2 backup completed successfully"
else
  log "B2 backup failed"
fi

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
if run_repo "R2" "$R2_REPO"; then
  log "R2 backup completed successfully"
else
  log "R2 backup failed"
fi

log "backup completed successfully"

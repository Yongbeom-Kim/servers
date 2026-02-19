#!/bin/sh
set -eu

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*"
}

KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-12}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"

DUMP_FILE="/tmp/linkwarden-${PGDATABASE}-$(date +%F-%H%M%S).dump"

cleanup() {
  rm -f "$DUMP_FILE"
}
trap cleanup EXIT INT TERM

log "creating pg_dump: ${PGHOST}:${PGPORT}/${PGDATABASE}"
export PGPASSWORD
pg_dump \
  --format=custom \
  --no-owner \
  --no-privileges \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$PGUSER" \
  -d "$PGDATABASE" \
  -f "$DUMP_FILE"

backup_repo() {
  repo_name="$1"
  repo_url="$2"

  export RESTIC_REPOSITORY="$repo_url"
  if ! restic snapshots >/dev/null 2>&1; then
    log "initializing ${repo_name} repository"
    restic init
  fi

  log "uploading dump to ${repo_name}"
  restic backup "$DUMP_FILE"
  restic forget \
    --prune \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY"
}

export B2_ACCOUNT_ID="$B2_APPLICATION_KEY_ID"
export B2_ACCOUNT_KEY="$B2_APPLICATION_KEY"
backup_repo "B2" "$B2_REPO"

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
backup_repo "R2" "$R2_REPO"

log "backup completed successfully"

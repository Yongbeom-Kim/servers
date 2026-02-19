#!/bin/sh
#
# Required environment variables:
#   RESTIC_PASSWORD          - Password for the restic repository
#   BACKUP_PATH              - Path(s) to back up (e.g. "/data/keycloak")
#   BACKUP_TARGET_CONTAINERS - Optional. Space-separated container names to stop during backup (restarted on exit).
#
#   At least one of the following repository variables must be set:
#     B2_REPO         - Restic repository URL for Backblaze B2 (e.g. "b2:my-bucket:path")
#       B2_APPLICATION_KEY_ID - B2 Application Key ID (required if B2_REPO is set)
#       B2_APPLICATION_KEY    - B2 Application Key (required if B2_REPO is set)
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
# Optional PostgreSQL logical backup (before restic):
#   PGHOST           - PostgreSQL host (e.g. "immich-database" or "immich_postgres" when run in same compose)
#   PGPORT           - PostgreSQL port (default: 5432)
#   PGUSER           - PostgreSQL user (must be superuser or have pg_dumpall role for pg_dumpall)
#   PGPASSWORD      - PostgreSQL password
#   PG_DUMPALL_DIR  - Writable directory to write pg_dumpall output; will be included in restic backup
#

set -eu

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*"
}

KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-12}"

if [ -z "${RESTIC_PASSWORD:-}" ]; then
  log "RESTIC_PASSWORD is required"
  exit 1
fi

if [ -z "${BACKUP_PATH:-}" ]; then
  log "BACKUP_PATH is required"
  exit 1
fi

LOCK_DIR="/tmp/backup.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another backup run is active; skipping"
  exit 0
fi

cleanup() {
  set +e
  cleanup_failed=0

  rm -rf "$LOCK_DIR" || cleanup_failed=1
  if [ "$cleanup_failed" -ne 0 ]; then
    log "cleanup encountered errors"
  fi
}
trap cleanup EXIT INT TERM

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
  restic backup "$@"
  restic forget \
    --prune \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY"
}

set -- $BACKUP_PATH
PG_DUMPALL_DIR=${BACKUP_PATH}/pgdumpall

if [ -z "${B2_REPO:-}" ] && [ -z "${R2_REPO:-}" ]; then
  log "no repository configured; set B2_REPO and/or R2_REPO"
  exit 1
fi

if [ -n "${B2_REPO:-}" ]; then
  if [ -z "${B2_ACCOUNT_ID:-}" ] || [ -z "${B2_ACCOUNT_KEY:-}" ]; then
    log "B2_REPO is set but B2_ACCOUNT_ID or B2_ACCOUNT_KEY is missing"
    exit 1
  fi
fi

if [ -n "${R2_REPO:-}" ]; then
  if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    log "R2_REPO is set but AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY is missing"
    exit 1
  fi
fi

# Optional: pg_dumpall before restic (requires PGHOST, PGUSER, PGPASSWORD, PG_DUMPALL_DIR)
PG_DUMPALL_PATH=""
if [ -n "${PGHOST:-}" ] && [ -n "${PGUSER:-}" ] && [ -n "${PGPASSWORD:-}" ] && [ -n "${PG_DUMPALL_DIR:-}" ]; then
  mkdir -p "$PG_DUMPALL_DIR"
  PG_DUMPALL_PATH="$PG_DUMPALL_DIR/pgdump.sql"
  log "creating pg_dumpall from ${PGHOST}:${PGPORT:-5432}"
  export PGPASSWORD
  if ! pg_dumpall \
    -h "${PGHOST}" \
    -p "${PGPORT:-5432}" \
    -U "${PGUSER}" \
    -f "$PG_DUMPALL_PATH"; then
    log "pg_dumpall failed"
    exit 1
  fi
  log "pg_dumpall wrote $PG_DUMPALL_PATH"
fi

if [ -n "${B2_REPO:-}" ]; then
  export B2_ACCOUNT_ID B2_ACCOUNT_KEY
  run_repo "B2" "$B2_REPO" "$@"
fi

if [ -n "${R2_REPO:-}" ]; then
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
  run_repo "R2" "$R2_REPO" "$@"
fi

log "backup completed successfully"

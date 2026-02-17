#!/bin/sh
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

DATA_PATHS="${BACKUP_PATHS:-}"
if [ -z "$DATA_PATHS" ] && [ -d /data ]; then
  DATA_PATHS="/data"
fi

ARTIFACT_DIR="/tmp/backup-artifacts"
mkdir -p "$ARTIFACT_DIR"

LOCK_DIR="/tmp/backup.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another backup run is active; skipping"
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT INT TERM

PG_DUMP_PATH=""
has_any_pg_var=0
for pg_var in PGHOST PGDATABASE PGUSER PGPASSWORD; do
  eval "pg_val=\${$pg_var:-}"
  if [ -n "$pg_val" ]; then
    has_any_pg_var=1
    break
  fi
done

if [ "${PGHOST:-}" ] && [ "${PGDATABASE:-}" ] && [ "${PGUSER:-}" ] && [ "${PGPASSWORD:-}" ]; then
  export PGPASSWORD
  PG_DUMP_PATH="$ARTIFACT_DIR/postgres-${PGDATABASE}-$(date +%F-%H%M%S).dump"
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
elif [ "$has_any_pg_var" -eq 1 ]; then
  log "PG* variables are only partially configured; skipping pg_dump"
fi

TARGETS=""
if [ -n "$DATA_PATHS" ]; then
  TARGETS="$TARGETS $DATA_PATHS"
fi
if [ -n "$PG_DUMP_PATH" ]; then
  TARGETS="$TARGETS $PG_DUMP_PATH"
fi

if [ -z "$TARGETS" ]; then
  log "nothing to back up; set BACKUP_PATHS or mount data under /data"
  exit 0
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
  restic backup "$@"
  restic forget \
    --prune \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY"
}

set -- $TARGETS

attempted=0
failures=0

if [ -n "${B2_REPO:-}" ]; then
  attempted=$((attempted + 1))
  if [ -z "${B2_ACCOUNT_ID:-}" ] || [ -z "${B2_ACCOUNT_KEY:-}" ]; then
    log "B2_REPO is set but B2_ACCOUNT_ID or B2_ACCOUNT_KEY is missing"
    failures=$((failures + 1))
  else
    export B2_ACCOUNT_ID B2_ACCOUNT_KEY
    if ! run_repo "B2" "$B2_REPO" "$@"; then
      failures=$((failures + 1))
    fi
  fi
fi

if [ -n "${R2_REPO:-}" ]; then
  attempted=$((attempted + 1))
  if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    log "R2_REPO is set but AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY is missing"
    failures=$((failures + 1))
  else
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
    if ! run_repo "R2" "$R2_REPO" "$@"; then
      failures=$((failures + 1))
    fi
  fi
fi

if [ "$attempted" -eq 0 ]; then
  log "no repository configured; set B2_REPO and/or R2_REPO"
  exit 1
fi

if [ "$failures" -gt 0 ]; then
  log "backup finished with ${failures} failure(s)"
  exit 1
fi

log "backup completed successfully"

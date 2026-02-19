#!/bin/sh
#
# Required environment variables:
#   RESTIC_PASSWORD   - Password for the restic repository
#   BACKUP_PATH       - Path(s) to back up (e.g. "/data/vaultwarden/data")
#
#   At least one of the following repository variables must be set:
#     B2_REPO         - Restic repository URL for Backblaze B2 (e.g. "b2:my-bucket:path")
#       B2_APPLICATION_KEY_ID - B2 Application Key ID (required if B2_REPO is set)
#       B2_APPLICATION_KEY    - B2 Application Key (required if B2_REPO is set)
#
#     R2_REPO         - Restic repository URL for Cloudflare R2/S3-compatible (e.g. "s3:https://ACCOUNT_ID.r2.cloudflarestorage.com/bucket/path")
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
BACKUP_TARGET_CONTAINER="${BACKUP_TARGET_CONTAINER:?}"

LOCK_DIR="/tmp/backup.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another backup run is active; skipping"
  exit 0
fi

container_stopped=0
cleanup() {
  set +e
  cleanup_failed=0
  if [ "$container_stopped" -eq 1 ]; then
    log "starting container: $BACKUP_TARGET_CONTAINER"
    docker start "$BACKUP_TARGET_CONTAINER" >/dev/null || cleanup_failed=1
  fi
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

if ! command -v docker >/dev/null 2>&1; then
  log "docker CLI is required to stop/start vaultwarden"
  exit 1
fi

if ! docker inspect "$BACKUP_TARGET_CONTAINER" >/dev/null 2>&1; then
  log "target container does not exist: $BACKUP_TARGET_CONTAINER"
  exit 1
fi

if docker ps --format '{{.Names}}' | grep -Fx "$BACKUP_TARGET_CONTAINER" >/dev/null 2>&1; then
  log "stopping container: $BACKUP_TARGET_CONTAINER"
  docker stop "$BACKUP_TARGET_CONTAINER" >/dev/null
  container_stopped=1
else
  log "target container is already stopped: $BACKUP_TARGET_CONTAINER"
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

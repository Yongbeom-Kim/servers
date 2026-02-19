#!/bin/sh
#
# Stops Linkwarden containers, backs up /data/linkwarden with restic, then starts
# containers again. Requires Docker socket and BACKUP_TARGET_CONTAINERS.
#
# Required environment variables:
#   RESTIC_PASSWORD          - Password for the restic repository
#   BACKUP_TARGET_CONTAINERS - Space-separated container names to stop/start
#
#   At least one of:
#     B2_REPO, B2_ACCOUNT_ID, B2_ACCOUNT_KEY
#     R2_REPO, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
#
# Optional: KEEP_DAILY, KEEP_WEEKLY, KEEP_MONTHLY, AWS_DEFAULT_REGION
#

set -eu

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*"
}

KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-12}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
BACKUP_PATH="${BACKUP_PATH:-/data/linkwarden}"
BACKUP_TARGET_CONTAINERS="${BACKUP_TARGET_CONTAINERS:-linkwarden_server linkwarden_meilisearch linkwarden_postgres}"

LOCK_DIR="/tmp/backup.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another backup run is active; skipping"
  exit 0
fi

STOPPED_CONTAINERS=""
cleanup() {
  set +e
  cleanup_failed=0

  for container in $STOPPED_CONTAINERS; do
    log "starting container: $container"
    docker start "$container" || cleanup_failed=1
  done

  rm -rf "$LOCK_DIR" || cleanup_failed=1
  if [ "$cleanup_failed" -ne 0 ]; then
    log "cleanup encountered errors"
  fi
}
trap cleanup EXIT INT TERM

if ! command -v docker >/dev/null 2>&1; then
  log "docker CLI is required to stop/start containers"
  exit 1
fi

for container in $BACKUP_TARGET_CONTAINERS; do
  if ! docker inspect "$container" >/dev/null 2>&1; then
    log "target container does not exist: $container"
    exit 1
  fi
done

for container in $BACKUP_TARGET_CONTAINERS; do
  if docker ps --format '{{.Names}}' | grep -Fx "$container" >/dev/null 2>&1; then
    log "stopping container: $container"
    docker stop "$container" >/dev/null
    STOPPED_CONTAINERS="$container $STOPPED_CONTAINERS"
  else
    log "target container is already stopped: $container"
  fi
done

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

  log "uploading $BACKUP_PATH to $repo_name"
  restic backup "$BACKUP_PATH"
  restic forget \
    --prune \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY"
}

export B2_ACCOUNT_ID B2_ACCOUNT_KEY
run_repo "B2" "$B2_REPO"

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
run_repo "R2" "$R2_REPO"

log "backup completed successfully"

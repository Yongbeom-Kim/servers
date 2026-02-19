#!/bin/sh
#
# Backs up OpenBao via "openbao operator raft snapshot save" over compose DNS,
# then uploads the snapshot with restic. No container stops or volume mounts.
#
# Required environment variables:
#   RESTIC_PASSWORD       - Password for the restic repository
#   VAULT_ADDR            - OpenBao API address (e.g. http://openbao-server:8200)
#   VAULT_TOKEN           - Token with permission to take raft snapshots
#
#   At least one of:
#     B2_REPO              - Restic repository URL for Backblaze B2
#       B2_ACCOUNT_ID      - B2 Application Key ID (required if B2_REPO is set)
#       B2_ACCOUNT_KEY     - B2 Application Key (required if B2_REPO is set)
#     R2_REPO              - Restic repository URL for Cloudflare R2
#       AWS_ACCESS_KEY_ID  - AWS/R2 Access Key ID (required if R2_REPO is set)
#       AWS_SECRET_ACCESS_KEY - AWS/R2 Secret Access Key (required if R2_REPO is set)
#       AWS_DEFAULT_REGION    - optional; default 'auto'
#
# Optional:
#   KEEP_HOURLY  - Hourly backups to keep (default: 24; use with 15-min schedule)
#   KEEP_DAILY   - Daily backups to keep (default: 7)
#   KEEP_WEEKLY  - Weekly backups to keep (default: 4)
#   KEEP_MONTHLY - Monthly backups to keep (default: 12)
#   SNAPSHOT_PATH - Where to write the raft snapshot (default: /data/snapshot/openbao.raft)
#

set -eu

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*"
}

if [ "${BACKUP_ON_STARTUP:-false}" = "true" ]; then
  log "BACKUP_ON_STARTUP is true; sleeping for 100 seconds to allow manual unseal..."
  sleep 100
fi


KEEP_HOURLY="${KEEP_HOURLY:-24}"
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-12}"
SNAPSHOT_PATH="${SNAPSHOT_PATH:-/data/snapshot/openbao.raft}"

if [ -z "${RESTIC_PASSWORD:-}" ]; then
  log "RESTIC_PASSWORD is required"
  exit 1
fi

if [ -z "${VAULT_ADDR:-}" ]; then
  log "VAULT_ADDR is required (e.g. http://openbao-server:8200)"
  exit 1
fi

if [ -z "${VAULT_TOKEN:-}" ]; then
  log "VAULT_TOKEN is required"
  exit 1
fi

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

LOCK_DIR="/tmp/backup.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another backup run is active; skipping"
  exit 0
fi

cleanup() {
  set +e
  rm -rf "$LOCK_DIR"
  if [ -n "${SNAPSHOT_DIR:-}" ] && [ -d "$SNAPSHOT_DIR" ]; then
    rm -f "$SNAPSHOT_PATH"
  fi
}
trap cleanup EXIT INT TERM

SNAPSHOT_DIR="${SNAPSHOT_PATH%/*}"
mkdir -p "$SNAPSHOT_DIR"

log "renewing OpenBao token"
if ! bao token renew >/dev/null 2>&1; then
  log "failed to renew token"
  exit 1
fi

log "taking raft snapshot from OpenBao at $VAULT_ADDR"
if ! bao operator raft snapshot save "$SNAPSHOT_PATH"; then
  log "raft snapshot save failed"
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
  restic backup "$@"
  restic forget \
    --prune \
    --keep-hourly "$KEEP_HOURLY" \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY"
}

if [ -n "${B2_REPO:-}" ]; then
  export B2_ACCOUNT_ID B2_ACCOUNT_KEY
  run_repo "B2" "$B2_REPO" "$SNAPSHOT_PATH"
fi

if [ -n "${R2_REPO:-}" ]; then
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
  run_repo "R2" "$R2_REPO" "$SNAPSHOT_PATH"
fi

log "backup completed successfully"

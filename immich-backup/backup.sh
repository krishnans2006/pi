#!/bin/sh

set -eu

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

: "${GOOGLE_DRIVE_CLIENT_ID:?GOOGLE_DRIVE_CLIENT_ID must be set}"
: "${GOOGLE_DRIVE_CLIENT_SECRET:?GOOGLE_DRIVE_CLIENT_SECRET must be set}"
: "${GOOGLE_DRIVE_TOKEN:?GOOGLE_DRIVE_TOKEN must be set}"
: "${RCLONE_CRYPT_PASSWORD:?RCLONE_CRYPT_PASSWORD must be set}"
: "${RCLONE_CRYPT_SALT:?RCLONE_CRYPT_SALT must be set}"
: "${RCLONE_REMOTE_PATH:?RCLONE_REMOTE_PATH must be set}"

# RCLONE_CRYPT_PASSWORD is also a backend override recognized by rclone. Keep
# its plain value in a non-exported shell variable, then remove the override.
CRYPT_PASSWORD_PLAIN="$RCLONE_CRYPT_PASSWORD"
CRYPT_SALT_PLAIN="$RCLONE_CRYPT_SALT"
unset RCLONE_CRYPT_PASSWORD RCLONE_CRYPT_SALT

BACKUP_INTERVAL_SECONDS="${BACKUP_INTERVAL_SECONDS:-86400}"
BACKUP_RETRY_INTERVAL_SECONDS="${BACKUP_RETRY_INTERVAL_SECONDS:-3600}"

case "$BACKUP_INTERVAL_SECONDS" in
  ''|*[!0-9]*)
    log "BACKUP_INTERVAL_SECONDS must be a positive integer"
    exit 1
    ;;
esac

case "$BACKUP_RETRY_INTERVAL_SECONDS" in
  ''|*[!0-9]*)
    log "BACKUP_RETRY_INTERVAL_SECONDS must be a positive integer"
    exit 1
    ;;
esac

if [ "$BACKUP_INTERVAL_SECONDS" -eq 0 ] ||
  [ "$BACKUP_RETRY_INTERVAL_SECONDS" -eq 0 ]; then
  log "Backup intervals must be greater than zero"
  exit 1
fi

case "$RCLONE_REMOTE_PATH" in
  gdrive:*) ;;
  *)
    log "RCLONE_REMOTE_PATH must start with gdrive:"
    exit 1
    ;;
esac

CONFIG_FILE=/tmp/rclone.conf
umask 077
: > "$CONFIG_FILE"

CRYPT_PASSWORD_OBSCURED="$(rclone obscure "$CRYPT_PASSWORD_PLAIN")"
CRYPT_SALT_OBSCURED="$(rclone obscure "$CRYPT_SALT_PLAIN")"

rclone --config "$CONFIG_FILE" config create gdrive drive \
  client_id "$GOOGLE_DRIVE_CLIENT_ID" \
  client_secret "$GOOGLE_DRIVE_CLIENT_SECRET" \
  token "$GOOGLE_DRIVE_TOKEN" \
  scope drive.file \
  --obscure \
  --non-interactive \
  --no-output

rclone --config "$CONFIG_FILE" config create encrypted crypt \
  remote "$RCLONE_REMOTE_PATH" \
  password "$CRYPT_PASSWORD_OBSCURED" \
  password2 "$CRYPT_SALT_OBSCURED" \
  filename_encryption standard \
  directory_name_encryption true \
  --no-obscure \
  --non-interactive \
  --no-output

# Arguments supplied with `docker compose run` are forwarded to rclone. This
# provides one-off access to the same encrypted remote for checks and restores.
if [ "$#" -gt 0 ]; then
  exec rclone --config "$CONFIG_FILE" "$@"
fi

while true; do
  log "Starting encrypted backup to $RCLONE_REMOTE_PATH"

  if rclone --config "$CONFIG_FILE" copy /source encrypted: \
    --create-empty-src-dirs \
    --log-level INFO; then
    delay="$BACKUP_INTERVAL_SECONDS"
    log "Backup completed; next run in $delay seconds"
  else
    delay="$BACKUP_RETRY_INTERVAL_SECONDS"
    log "Backup failed; retrying in $delay seconds"
  fi

  sleep "$delay"
done

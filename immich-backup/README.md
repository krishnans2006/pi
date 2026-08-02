# Encrypted Immich backups

This service makes an encrypted copy of the complete Immich media directory
(including `backups/`) in Google Drive. It runs once when the container starts
and then every 24 hours. The source is mounted read-only, and `rclone copy`
never deletes remote files when a local file disappears.

File contents, file names, and directory names are encrypted locally by
rclone's `crypt` backend before upload.

## Setup

Google requires one interactive OAuth login; that part cannot be safely
automated. The container automatically builds both rclone remotes from the
resulting token and the values in `.env`.

1. Copy the sample configuration:

   ```sh
   cp .env.sample .env
   ```

2. In the [Google Cloud Console](https://console.cloud.google.com/):

   - Create or select a project and enable the Google Drive API.
   - Configure the OAuth consent screen. For a long-lived refresh token, use
     production rather than testing mode.
   - Create an OAuth client ID with application type **Desktop app**.
   - Put its client ID and client secret in `.env`.

   A custom client is necessary because rclone's shared Google Drive client is
   being retired during 2026.

3. On a Linux computer with a browser, generate the token with a temporary
   container. Substitute the client ID and secret from the previous step:

   ```sh
   docker run --rm -it --network host rclone/rclone:latest \
     authorize drive CLIENT_ID CLIENT_SECRET \
     --drive-scope drive.file \
     --auth-no-open-browser
   ```

   Open the printed localhost URL in that computer's browser, approve access,
   and paste the JSON token printed by rclone into `GOOGLE_DRIVE_TOKEN` in
   `.env`. The `drive.file` scope limits the app to files it creates.

4. Set `RCLONE_REMOTE_PATH`, both crypt secrets, and (if different) the Immich
   `UPLOAD_LOCATION` in `.env`. Do not pre-create the Drive destination folder;
   the restricted OAuth scope lets rclone create and manage it.

   Keep the crypt password and salt in a password manager. Both are required
   for a restore, and changing either value makes existing backups unreadable.
   Enter their plain values in `.env`, not output from `rclone obscure`; the
   startup script obscures them when it generates the temporary rclone config.

5. Start the service:

   ```sh
   docker compose up -d
   docker compose logs -f
   ```

## Useful commands

Run an extra backup immediately:

```sh
docker compose run --rm backup copy /source encrypted: --create-empty-src-dirs
```

List the decrypted names in the remote:

```sh
docker compose run --rm backup lsf encrypted:
```

Restore into a new local `restore` directory:

```sh
mkdir restore
docker compose run --rm -v "$PWD/restore:/restore" \
  backup copy encrypted: /restore
```

The normal container retries a failed backup after one hour. After a
successful run, it waits for `BACKUP_INTERVAL_SECONDS` before running again.

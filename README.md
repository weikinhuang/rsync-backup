Container for daily backups based on rsync
---

Mainly useful for backups in a cron environment.

## Scripts

### `disk-backup.sh`

This script creates a backup using rsync of a local or a remote directory.

Environment variables are used to configure the script.

```bash
TARGET_DIR=         # path where the backups are stored
SOURCE_DIR=         # local or remote path to backup eg. /home/foobar OR foobar@some.host.com:/home/foobar
SSH_OPTIONS=        # ssh options to pass into rsync eg. -o UserKnownHostsFile=/dev/null
RSYNC_OPTIONS=      # additional rsync options
```

### `disk-cleanup.sh`

This script cleans up old backups older than `MAX_AGE`

Environment variables are used to configure the script.

```bash
TARGET_DIR=         # path where the backups are stored
MAX_AGE=            # oldest backup to keep in days, anything older will be deleted
```

## Development

Build container with:

```bash
docker build -t rsync-backup .
```

Run container with:

```bash
docker run -it --rm \
    -v $(pwd)/container/usr/local/bin/disk-backup.sh:/usr/local/bin/disk-backup.sh:ro \
    -v $(pwd)/container/usr/local/bin/disk-backup-cleanup.sh:/usr/local/bin/disk-backup-cleanup.sh:ro \
    rsync-backup bash
```

Testing scripts:
```bash
env SOURCE_DIR=/etc/profile.d TARGET_DIR=/tmp disk-backup.sh
```

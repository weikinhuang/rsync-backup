Container for daily backups based on rsync
---

Backup script using incremental rsync and hardlinks.

---

[![Docker Image](https://img.shields.io/docker/pulls/weikinhuang/rsync-backup.svg)](https://hub.docker.com/r/weikinhuang/rsync-backup/)

---
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

## Usage Scenarios

#### One-off

```bash
docker run --rm \
    --env "SOURCE_DIR=/source" \
    --env "TARGET_DIR=/target" \
    --volume "/apps:/source:ro" \
    --volume "/backups/apps:/target" \
    weikinhuang/rsync-backup:latest
```

#### Crontab

`crontab`:
```
30 9 * * * /usr/bin/docker run --rm --env "SOURCE_DIR=/source" --env "TARGET_DIR=/target" --volume "/apps:/source:ro" --volume "/backups/apps:/target" weikinhuang/rsync-backup:latest
```

#### Systemd Timer

`rsync-backup.apps.timer`:
```ini
[Unit]
Description=Timer for rsync backup of "/apps" directory
Requires=docker.service

[Timer]
OnCalendar=*-*-* 09:30:00

[Install]
WantedBy=timers.target
```

`rsync-backup.apps.service`:
```ini
[Unit]
Description=rsync backup of "/apps" directory
Requires=docker.service

[Service]
TimeoutStartSec=0
Type=oneshot

Environment=DOCKER_IMAGE=weikinhuang/rsync-backup:latest
Environment=CONTAINER_NAME=%n

Environment="SOURCE_DIR=/apps"
Environment="TARGET_DIR=/backups/apps"

ExecStartPre=-/usr/bin/docker pull "${DOCKER_IMAGE}"
ExecStart=/usr/bin/docker run --rm \
    --name "${CONTAINER_NAME}" \
    --env "SOURCE_DIR=/source" \
    --env "TARGET_DIR=/target" \
    --volume "${SOURCE_DIR}:/source:ro" \
    --volume "${TARGET_DIR}:/target" \
    "${DOCKER_IMAGE}"
```

#### Kubernetes

`backup.yaml`:
```yaml
kind: CronJob
apiVersion: batch/v2alpha1  # batch/v1beta1 for k8s >= 1.8
metadata:
  name: backup-apps
  namespace: default
spec:
  schedule: "30 9 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 5
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: rsync-backup
            image: weikinhuang/rsync-backup:latest
            imagePullPolicy: Always
            env:
              - name: SOURCE_DIR
                value: "/source"
              - name: TARGET_DIR
                value: "/target"
            volumeMounts:
              - name: source
                mountPath: /source
                readOnly: true
              - name: target
                mountPath: /target
          # restartPolicy: OnFailure # retry until success
          volumes:
            - name: source
              hostPath:
                path: /apps
            - name: target
              hostPath:
                path: /backups/apps
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

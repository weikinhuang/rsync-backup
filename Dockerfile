FROM alpine:latest
LABEL maintainer="Wei Kin Huang"

RUN set -x \
    && apk add --no-cache \
        bash \
        openssh-client \
        rsync

COPY container/ /

CMD [ "disk-backup.sh" ]

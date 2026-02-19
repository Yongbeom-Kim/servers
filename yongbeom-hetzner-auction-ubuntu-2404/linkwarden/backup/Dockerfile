FROM alpine:3.21

RUN apk add --no-cache ca-certificates curl docker-cli restic tzdata

# Latest releases available at https://github.com/aptible/supercronic/releases
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.43/supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=f97b92132b61a8f827c3faf67106dc0e4467ccf2 \
    SUPERCRONIC=supercronic-linux-amd64

RUN curl -fsSLO "$SUPERCRONIC_URL" \
  && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
  && chmod +x "$SUPERCRONIC" \
  && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
  && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

WORKDIR /work

COPY backup.sh /usr/local/bin/backup.sh
COPY crontab /etc/crontab

RUN chmod +x /usr/local/bin/backup.sh

CMD ["sh", "-c", "if [ \"${BACKUP_ON_STARTUP:-false}\" = \"true\" ]; then /usr/local/bin/backup.sh; fi; exec supercronic /etc/crontab"]

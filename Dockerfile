FROM alpine:3.22

# hadolint ignore=DL3018
RUN apk --no-cache add bash gzip groff less aws-cli tar openssl ca-certificates gnupg tzdata

COPY backup.sh /usr/bin/backup.sh
COPY gpg.conf /root/.gnupg/gpg.conf
COPY dirmngr.conf /root/.gnupg/dirmngr.conf

RUN chmod 0600 /root/.gnupg && \
    chmod +x /usr/bin/backup.sh

CMD ["/usr/bin/backup.sh"]

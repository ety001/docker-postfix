FROM alpine:3.10

RUN \
    apk add --no-cache \
    supervisor \
    openssl \
    postfix \
    opendkim \
    opendkim-utils \
    cyrus-sasl \
    libsasl \
    cyrus-sasl-plain

COPY supervisord.conf /etc/supervisord.conf
COPY postfix.sh /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/

CMD ["/usr/local/bin/entrypoint.sh"]

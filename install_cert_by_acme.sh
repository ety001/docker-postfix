#!/bin/ash

acme.sh --installcert \
    -d example.com \
    --key-file /etc/postfix_conf/tls/example.com.key \
    --cert-file /etc/postfix_conf/tls/example.com.crt \
    --ca-file /etc/postfix_conf/tls/example.com.pem \
    --reloadcmd "docker restart postfix"

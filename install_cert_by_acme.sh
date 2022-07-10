#!/bin/ash

acme.sh --installcert \
    -d example.com \
    --key-file /etc/postfix_conf/tls/example.com.key \
    --fullchain-file /etc/postfix_conf/tls/example.com.crt \
    --reloadcmd "docker restart postfix"

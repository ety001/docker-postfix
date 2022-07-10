#!/bin/ash

## Basic configuration
# The network interface addresses that this mail system receives mail on.
# Specify "all" to receive mail on all network interfaces.
postconf -e 'inet_interfaces = all'

# The internet hostname of this mail system.
if [ ! -z "$MTA_HOST" ]; then
    postconf -e "myhostname = $MTA_HOST"
    postconf -e "mydomain = $MTA_HOST"
fi

# The domain name that locally-posted mail appears to come from, and that
# locally posted mail is delivered to. Example: $mydomain
postconf -e 'myorigin = $mydomain'
postconf -e 'smtpd_banner = ETY001 Email Server'
postconf -e 'maillog_file = /dev/stdout'
# Network style
postconf -e 'mynetworks_style = host'
# The list of domains that are delivered via the $local_transport mail
# delivery transport. Default: $myhostname, localhost.$mydomain, localhost
postconf -e 'mydestination = $myhostname, $mydomain, localhost.$mydomain, localhost'
# What destination domains and/or subdomains this system will relay mail to.
postconf -e 'relay_domains ='
# Lookup tables with all names or addresses of local recipients. The default
# (proxy:unix:passwd.byname $alias_maps) will cause postfix to access
# the /etc/passwd file.
postconf -e 'local_recipient_maps ='

## Spam configuration
# This can reduce the amount of spam you will receive.
# From http://wiki.apache.org/spamassassin/OtherTricks#line-69
# This setting will slow down the sending from connecting clients. This trick
# can reduce spam as spammers dont have time to wait.
postconf -e 'smtpd_client_restrictions = permit_sasl_authenticated'
postconf -e 'smtpd_delay_reject = no'
# Reject if the MAIL FROM domain has
#   1) no DNS A or MX record
#   2) a malformed MX record or MAIL FROM address is not a fully-qualified domain
postconf -e 'smtpd_sender_restrictions = reject_unknown_sender_domain'
# Protect against bots/spammers that trigger lots of errors or scan for
# accounts. When the error count reaches the soft-limit, delay the response by
# the sleep-time but if the hard-limit is reached, postfix will disconnect.
postconf -e 'smtpd_error_sleep_time = 30'
postconf -e 'smtpd_soft_error_limit = 10'
postconf -e 'smtpd_hard_error_limit = 20'

## SMTP-AUTH configuration
# The name of the Postfix SMTP server's local SASL authentication realm. (default: empty)
postconf -e 'smtpd_sasl_local_domain = $mydomain'
# Enable SASL authentication in the Postfix SMTP server.
postconf -e 'smtpd_sasl_auth_enable = yes'
# The SASL plug-in type that the Postfix SMTP server should use for authentication.
postconf -e 'smtpd_sasl_type = cyrus'
# Postfix SMTP server SASL security options. noanonymous disallow methods
# that allow anonymous authentication.
postconf -e 'smtpd_sasl_security_options = noanonymous'
# Enable inter-operability with remote SMTP clients that implement an obsolete
# version of the AUTH command
postconf -e 'broken_sasl_auth_clients = yes'
# Do not report the SASL authenticated user name in the smtpd Received message header.
postconf -e 'smtpd_sasl_authenticated_header = no'
#
postconf -e 'smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, defer_unauth_destination'
# Optional restrictions that the Postfix SMTP server applies in the context of
# a client RCPT TO command, after smtpd_relay_restrictions.
postconf -e 'smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination'
# email file size 5M
postconf -e 'message_size_limit = 5242880'

# Use sasl2
cat > /etc/sasl2/smtpd.conf <<EOF
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
EOF
# Generate sasldb2
echo $MTA_USERS | tr , \\n | while IFS=':' read -r _user _password; do
    echo $_password | saslpasswd2 -p -c -u $MTA_HOST $_user
done
chown postfix:postfix /etc/sasl2/sasldb2

## TLS configuration
TLSDIR=/etc/postfix/tls
mkdir -p $TLSDIR

TLS_CRT=$(find $TLSDIR -name *.crt)
TLS_KEY=$(find $TLSDIR -name *.key)
TLS_CA=$(find $TLSDIR -name *.pem)

if [ -n "$TLS_CRT" -a -n "$TLS_KEY" ]; then
    echo "TLS: $TLS_CRT and $TLS_KEY are found, enabling..."
    # Configures the server certificate file and key file as well as the CA's
    # intermediate certificate file.
    postconf -e "smtpd_tls_cert_file = $TLS_CRT"
    postconf -e "smtpd_tls_key_file= $TLS_KEY"

    postconf -e "smtp_tls_cert_file = $TLS_CRT"
    postconf -e "smtp_tls_key_file= $TLS_KEY"

    if [ -n "$TLS_CA" ]; then
        postconf -e "smtpd_tls_CAfile = $TLS_CA"
        postconf -e "smtp_tls_CAfile = $TLS_CA"
    fi

    chown -R root:root $TLSDIR
    chmod -R 0700 $TLSDIR
    chmod -R 0400 $TLSDIR/*

    # If enable TLS, then use TLS auth only.
    #postconf -e 'smtpd_tls_auth_only = yes'

    # With this, the Postfix SMTP server announces STARTTLS support to remote SMTP
    # clients, but does not require that clients use TLS encryption.
    postconf -e 'smtpd_use_tls = yes'

    # With this, the Postfix SMTP server announces STARTTLS support to remote SMTP clients,
    # but does not require that clients use TLS encryption.
    postconf -e 'smtpd_tls_security_level = may'
    postconf -e 'smtp_tls_security_level = may'

    # TLS activity logging
    if [ -n "$DEBUG" ]; then
        postconf -e 'smtpd_tls_loglevel = 2'
        postconf -e 'smtp_tls_loglevel = 2'
    else
        postconf -e 'smtpd_tls_loglevel = 0'
        postconf -e 'smtp_tls_loglevel = 0'
    fi
    postconf -e 'smtpd_tls_received_header = yes'

    # Postfix SMTP server and the remote SMTP client negotiate a session, which
    # takes some computer time and network bandwidth. SSL protocol versions other
    # than SSLv2 support resumption of cached sessions.
    postconf -e 'smtpd_tls_session_cache_database = btree:/var/lib/postfix/smtpd_scache'
    postconf -e 'smtp_tls_session_cache_database = btree:/var/lib/postfix/smtp_scache'
    # Cached Postfix SMTP server session information expires after a certain
    # amount of time.RFC2246 recommends a maximum of 24 hours.
    postconf -e 'smtpd_tls_session_cache_timeout = 3600s'
    postconf -e 'smtp_tls_session_cache_timeout = 3600s'
else
    echo "TLS: Certificate and Private key are missing, skip..."
fi

## OpenDKIM
# Directory to store DKIM keys
DKIM_KEYDIR=/etc/opendkim/keys
# A Selector is created while generating keys, a selector can be unique
# keyword which is associated in keys and included in DKIM signature.
DKIM_SELECTOR=mail

if [ -z "$(find $DKIM_KEYDIR -name *.private)" ]; then
    echo "OpenDKIM: Default DKIM keys for $MTA_DOMAIN doesn't exist, generating..."
    opendkim-genkey -D $DKIM_KEYDIR -s $DKIM_SELECTOR -d $MTA_DOMAIN
    echo "OpenDKIM: Default DKIM keys for $MTA_DOMAIN created in $DKIM_KEYDIR"
else
    echo "OpenDKIM: Default DKIM keys for $MTA_DOMAIN exists, skip..."
fi

# $DKIM_SELECTOR.private is the private key for the domain
# $DKIM_SELECTOR.txt is the public key that will publish in DNS TXT record
echo "OpenDKIM: Regulating the permissions of Default DKIM Keys..."
chown -R root:opendkim $DKIM_KEYDIR
chmod 640 $DKIM_KEYDIR/$DKIM_SELECTOR.private
chmod 644 $DKIM_KEYDIR/$DKIM_SELECTOR.txt

echo "OpenDKIM: Showing contents of $DKIM_KEYDIR/$DKIM_SELECTOR.txt"
cat $DKIM_KEYDIR/$DKIM_SELECTOR.txt

DKIM_CONF=/etc/opendkim/opendkim.conf
DKIM_KEY_TABLE=/etc/opendkim/KeyTable
DKIM_SIGNING_TABLE=/etc/opendkim/SigningTable
DKIM_TRUSTED_HOSTS=/etc/opendkim/TrustedHosts
echo "OpenDKIM: Configuring $DKIM_CONF..."
cat > $DKIM_CONF <<EOF

# Set by docker-postfix
Mode                sv
Socket              inet:8891@127.0.0.1

Selector	    ${DKIM_SELECTOR}
Domain              ${MTA_DOMAIN}
KeyFile             ${DKIM_KEYDIR}/${DKIM_SELECTOR}.private
Canonicalization    relaxed/simple
ExternalIgnoreList  refile:${DKIM_TRUSTED_HOSTS}
InternalHosts       refile:${DKIM_TRUSTED_HOSTS}
KeyTable            refile:${DKIM_KEY_TABLE}
SigningTable        refile:${DKIM_SIGNING_TABLE}
EOF

echo "OpenDKIM: Configuring $DKIM_KEY_TABLE..."
cat > $DKIM_KEY_TABLE <<EOF

# Set by docker-postfix
${DKIM_SELECTOR}._domainkey.${MTA_DOMAIN} ${MTA_DOMAIN}:${DKIM_SELECTOR}:${DKIM_KEYDIR}/${DKIM_SELECTOR}.private
EOF

echo "OpenDKIM: Configuring $DKIM_SIGNING_TABLE..."
cat > $DKIM_SIGNING_TABLE <<EOF

# Set by docker-postfix
*@${MTA_DOMAIN} ${DKIM_SELECTOR}._domainkey.${MTA_DOMAIN}
EOF

echo "OpenDKIM: Configuring $DKIM_TRUSTED_HOSTS..."
cat > $DKIM_TRUSTED_HOSTS <<EOF

# Set by docker-postfix
*.${MTA_DOMAIN}
EOF

echo "OpenDKIM: Configuring Postfix..."
postconf -e 'smtpd_milters = inet:127.0.0.1:8891'
postconf -e 'non_smtpd_milters=$smtpd_milters'
postconf -e 'milter_default_action=accept'

## Launch
/usr/bin/supervisord -n -c /etc/supervisord.conf

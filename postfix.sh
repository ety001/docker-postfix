#!/bin/ash

# call "postfix stop" when exiting
trap "{ echo Stopping postfix; /usr/sbin/postfix stop; exit 0; }" EXIT

# start postfix
/usr/sbin/postfix start
# avoid exiting
while true
do
    sleep 3600
done

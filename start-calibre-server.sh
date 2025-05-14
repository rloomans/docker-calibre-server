#!/usr/bin/env bash

# Resolve trusted IP addresses
TRUSTED_IPS="$(ip route | awk '/default/ { print $3 }')"
for h in $TRUSTED_HOSTS; do
    HOST_IP="$(getent ahosts "$h" | sed -e '/STREAM/!d; s/[[:space:]]\{1,\}.*$//')"
    if [ -z "${HOST_IP}" ]; then
	echo "WARNING: host '$h' not found in network. container with that name will not get write access to the library" >&2
    else
        TRUSTED_IPS="${TRUSTED_IPS},${HOST_IP}"
    fi
done
echo "trusted ips: ${TRUSTED_IPS}"

touch "/library/metadata.db"

export LANG=C.UTF-8
export XDG_RUNTIME_DIR=/tmp/runtime-root

/usr/bin/calibre-server \
    --disable-use-bonjour \
    --enable-local-write \
    --trusted-ips="${TRUSTED_IPS}" \
    "$@" \
    "/library"

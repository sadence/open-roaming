#!/bin/bash

usage() {
    echo "Usage: ${0} <realm>"
    exit 1
}

test -n "${1}" || usage

REALM="${1}"
DIGCMD=$(command -v dig)
PRINTCMD=$(command -v printf)

dig_it_srv() {
    ${DIGCMD} +short srv $SRV_HOST | sort -n -k1 |
    while read line; do
    set $line ; PORT=$3 ; HOST=$4
    $PRINTCMD "\thost ${HOST%.}:${PORT}\n"
    done
}

dig_it_naptr() {
    ${DIGCMD} +short naptr ${REALM} | grep aaa+auth:radius.tls.tcp | sort -n -k1 |
    while read line; do
    set $line ; TYPE=$3 ; HOST=$6
    if [ "$TYPE" = "\"s\"" -o "$TYPE" = "\"S\"" ]; then
        SRV_HOST=${HOST%.}
        dig_it_srv
    fi
    done
}

if [ -x "${DIGCMD}" ]; then
    SERVERS=$(dig_it_naptr)
else
    echo "${0} requires either \"dig\" or \"host\" command."
    exit 1
fi

if [ -n "${SERVERS}" ]; then
    $PRINTCMD "server radsec.${REALM} {\n${SERVERS}\n\ttype tls\n\ttls client\n\tcertificateNameCheck on\n}\n"
    exit 0
fi

exit 10                # No server found.

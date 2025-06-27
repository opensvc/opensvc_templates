#!/bin/bash

set -aeuo pipefail

CERTSDIR=$1

OPENSVC_NAMESPACE=${OPENSVC_NAMESPACE:-system}
OPENSVC_SVCNAME=${OPENSVC_SVCNAME:-haproxy}

CFGMAP="$OPENSVC_NAMESPACE/cfg/$OPENSVC_SVCNAME"
SVC="$OPENSVC_NAMESPACE/svc/$OPENSVC_SVCNAME"

TMPDIR=$(mktemp -d)
TMPCFG="$TMPDIR/haproxy.cfg"
FINALCFG="$TMPDIR/haproxy.final.cfg"
HAPROXY_CONTAINER_IMAGE="haproxy:latest"
HAPROXY_CFG_VALIDATE="om $SVC run --rid task#validatecfg"

function gencert()
{
    local CERT=$1
    ls -1 $CERTSDIR | grep -wq "^$CERT.pem" || {
	echo "[INFO] Generating ssl certificate for $CERT..."
        om $SVC run --rid task#issuecert --env domain=$CERT
    }
}

function comment()
{
    local KEY=$1
    echo "# source: key $KEY from datastore $CFGMAP"
}

function frontend_has_bind() {
    local PAYLOAD="$1"
    while IFS= read -r line; do
	set -- $line
        if [[ "$1" == "bind" ]]; then
            return 0
        fi
    done <<< "$PAYLOAD"
    return 1
}

echo "[INFO] haproxy.cfg.head"
om $CFGMAP decode --key haproxy.cfg.head > "$TMPCFG"

KEYS=$(om $CFGMAP keys --match 'haproxy.cfg.d/*')

for KEY in $KEYS; do
    CONTENT=$(om $CFGMAP decode --key "$KEY")
    COMMENT=$(comment $KEY)

    # Extraction frontend
    FRONTEND_BLOCK=$(echo "$CONTENT" | awk '
  /^\s*frontend / {in_frontend=1; next}
  /^\s*backend / {in_frontend=0}
  in_frontend && NF > 0
')

    BACKEND_BLOCK=$(echo "$CONTENT" | awk '/^\s*backend /,0')

    # Get frontend name
    FRONTEND_NAME=$(echo "$CONTENT" | grep -oP '^\s*frontend\s+\K\S+')

    if egrep -q "frontend\s+$FRONTEND_NAME\s*$" "$TMPCFG"; then
	if frontend_has_bind "$FRONTEND_BLOCK"; then
	    echo "[ERROR] $KEY: skip frontend $FRONTEND_NAME: definition conflict"
	    continue
	else
            echo "[INFO] $KEY: patch frontend $FRONTEND_NAME"
            awk -v fe_name="$FRONTEND_NAME" -v insert="$(printf "    %s\n%s\n" "$COMMENT" "$FRONTEND_BLOCK")" '
                BEGIN {in_frontend=0}
                {
                    if ($0 ~ "^\\s*frontend[[:space:]]+" fe_name "$") {
                        print
                        in_frontend = 1
                        next
                    }
                    if (in_frontend && NF == 0) {
                        print insert
                        in_frontend = 0
                    }
                    print
                }
            ' "$TMPCFG" > "$TMPCFG.tmp" && mv "$TMPCFG.tmp" "$TMPCFG"
    
            FQDNS=$(echo "$CONTENT" | sed -nE 's/.*hdr\(host\)[[:space:]]+(-[a-z]+[[:space:]]+)*//p' | \
    		                 tr ' ' '\n' | \
    				 grep -v '^-' | \
    				 grep -E '^([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})$' | \
    				 paste -sd ' '
    			         )
            for URI in $FQDNS
    	    do
    		gencert $URI
    	    done
	fi
    else
	if frontend_has_bind "$FRONTEND_BLOCK"; then
	    echo "[INFO] $KEY: add frontend $FRONTEND_NAME"
            echo -e "\n$COMMENT\nfrontend $FRONTEND_NAME\n$FRONTEND_BLOCK" >> "$TMPCFG"
	else
	    echo "[ERROR] $KEY: skip frontend $FRONTEND_NAME: missing bind directive"
	    continue
	fi
    fi

    echo -e "\n$COMMENT\n$BACKEND_BLOCK" >> "$TMPCFG"
done

# Config validation
echo "[INFO] checking configuration integrity with haproxy -c ..."
om $CFGMAP change --key haproxy.cfg.temp --from "$TMPCFG"

if $HAPROXY_CFG_VALIDATE > /dev/null 2>&1; then
    echo "[INFO] configuration is ok, update datastore ..."
    cp "$TMPCFG" "$FINALCFG"
    om $CFGMAP change --key haproxy.cfg --from "$FINALCFG"
    echo "[INFO] key haproxy.cfg updated."
else
    echo "[ERROR] configuration is invalid, cancelling change." >&2
    exit 1
fi

# Cleanup
rm -rf "$TMPDIR"

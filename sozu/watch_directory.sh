#!/bin/bash

DIR_TO_WATCH="$DIR_TO_WATCH"
OSVC_CFGMAP="$OSVC_CFGMAP"
OSVC_CFGKEY="$OSVC_CFGKEY"
LAST_CKSUM=""

DAEMON=/usr/bin/inotifywait
DAEMON_BASE=$(basename $DAEMON)
DAEMONOPTS="-m -e modify,create,delete $DIR_TO_WATCH"

type inotifywait >> /dev/null 2>&1 || {
    echo "inotifywait is missing. please install inotify-tools package"
    exit 1
}

on_file_change() {
    FILE=$1
    TIMESTAMP=$(date --utc "+%Y%m%d%H%M%S")
    CKSUM=$(md5sum $DIR_TO_WATCH/$FILE | awk '{print $1}')
    echo "----------------------------------------------"
    echo "UTC$TIMESTAMP File $DIR_TO_WATCH/$FILE changed"
    echo
    [[ ! -z $OPENSVC_SVCPATH ]] && {
	# would have been better that sozu container trap signals to reload config
        [[ $CKSUM != $LAST_CKSUM ]] && {
            om $OSVC_CFGMAP change --key $OSVC_CFGKEY --from $DIR_TO_WATCH/$FILE && {
	        LAST_CKSUM=$CKSUM
            }
            OSVC_PEERS=$(om node ls | grep -vw $HOSTNAME | awk '{printf $1 ","}' | sed -e 's/,$//')
	    # ask other cluster nodes to reload sozu config
	    om $OPENSVC_SVCPATH run --rid task#stateload --node=$OSVC_PEERS
        }
    }
}

function status {
        pgrep $DAEMON_BASE >/dev/null 2>&1
}

case $1 in
restart)
        killall $DAEMON_BASE
        $DAEMON
        ;;
start)
        status && {
                echo "already started"
                exit 0
        }
        nohup $DAEMON $DAEMONOPTS | while read -r directory events filename; do
	                                on_file_change $filename
                                    done >> /dev/null 2>&1 &
        ;;
stop)
        killall $DAEMON_BASE
        ;;
info)
        echo "Name: watch_directory.sh"
        ;;
status)
        status
        exit $?
        ;;
*)
        echo "unsupported action: $1" >&2
        exit 1
        ;;
esac

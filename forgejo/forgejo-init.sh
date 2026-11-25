#!/bin/sh
# Run by container#3init, as the git user of the forgejo image, at each start
# of the service: makes the admin account if missing, registers the runner.
set -eu

F="forgejo --config /data/gitea/conf/app.ini --work-path /data/gitea"

# container#2forgejo writes app.ini and updates the database as it starts.
i=0
until wget -q -O /dev/null http://127.0.0.1:3000/api/healthz; do
	i=$((i + 1))
	[ $i -lt 120 ] || { echo "forgejo not ready after 4 minutes" >&2; exit 1; }
	sleep 2
done

if $F admin user list --admin | awk 'NR > 1 {print $2}' | grep -qxF "$ADMIN_USER"; then
	echo "admin account $ADMIN_USER exists"
else
	$F admin user create --admin --username "$ADMIN_USER" --email "$ADMIN_EMAIL" \
		--password "$ADMIN_PASSWORD" --must-change-password=false
fi

# The registration secret is 40 hex chars, the sha1 of the runner_secret
# key: runner.sh derives the same. Register once per secret, as a register
# resets the labels the runner declared, and the runner would take no job
# until its next start.
TOKEN=$(printf %s "$RUNNER_SECRET" | sha1sum | cut -d' ' -f1)
MARK=/data/gitea/.runner-$RUNNER_NAME.sha1
if [ -f "$MARK" ] && [ "$(cat "$MARK")" = "$TOKEN" ]; then
	echo "runner $RUNNER_NAME registered"
else
	$F forgejo-cli actions register --name "$RUNNER_NAME" --secret "$TOKEN" >/dev/null
	echo "$TOKEN" > "$MARK"
	echo "runner $RUNNER_NAME registered now"
fi

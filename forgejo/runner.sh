#!/bin/sh
# Run by container#6runner: waits for its docker engine and for the forge,
# writes the configuration of the runner from runner-config.yml, starts it.
set -eu

# The runner exits at the first failure to reach the forge.
until wget -q -O /dev/null http://127.0.0.1:2375/_ping; do sleep 1; done
until wget -q -O /dev/null "$FORGEJO_URL/api/healthz"; do sleep 2; done

# The secret registered by forgejo-init.sh: the sha1 of the runner_secret
# key. The uuid of the runner is the hex encoding of its first 16 chars.
TOKEN=$(printf %s "$RUNNER_SECRET" | sha1sum | cut -d' ' -f1)
UUID=$(printf %.16s "$TOKEN" | od -An -tx1 | tr -d ' \n' |
	sed -E 's/^(.{8})(.{4})(.{4})(.{4})(.{12})$/\1-\2-\3-\4-\5/')

umask 077
mkdir -p /tmp/runner
printf %s "$TOKEN" > /tmp/runner/token
# The url is given to the jobs as the one of the forge, to clone from: the
# address of the server pod, which they reach.
sed -e "s#@URL@#$FORGEJO_URL/#" -e "s#@UUID@#$UUID#" \
	/etc/runner/runner-config.yml > /tmp/runner/config.yml
exec forgejo-runner daemon --config /tmp/runner/config.yml

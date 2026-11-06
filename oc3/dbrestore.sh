#!/bin/bash
# Run by task#dbrestore, in a container of the mariadb image sharing the
# network namespace of the database: restores /dumps/restore.me.sql.gz when
# there is one, else the latest dump of task#dbdump. The password comes from
# MYSQL_PWD. Stop the oc3 subsystems first: the next start of migrate brings
# the schema restored up to the version of oc3.
set -e -o pipefail

cd /dumps
if [ -f restore.me.sql.gz ]; then
	DUMP=restore.me.sql.gz
else
	DUMP=$(ls -1t oc3.*.sql.gz 2>/dev/null | head -n 1)
fi
if [ -z "$DUMP" ]; then
	echo "no dump to restore in /dumps" >&2
	exit 1
fi

echo "restoring /dumps/$DUMP"
gunzip -c "$DUMP" | mariadb --skip-ssl -h 127.0.0.1 -u root --batch
echo "restored /dumps/$DUMP"

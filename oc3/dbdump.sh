#!/bin/bash
# Run by task#dbdump, in a container of the mariadb image sharing the network
# namespace of the database: dumps the databases of oc3 in one transaction, a
# consistent snapshot, to /dumps/oc3.<time>.sql.gz, and keeps the last
# DUMP_RETENTION of them. The password comes from MYSQL_PWD.
set -e -o pipefail

DUMP_DIR=/dumps
DUMP_RETENTION=${DUMP_RETENTION:-3}
NAME=oc3.$(date --utc +%Y%m%d%H%M%S).sql.gz

# A dump failing midway leaves no archive behind, and rotates none out.
trap 'rm -f "$DUMP_DIR/.$NAME"' EXIT
echo "dumping the databases to $DUMP_DIR/$NAME"
mariadb-dump --skip-ssl -h 127.0.0.1 -u root \
	--single-transaction --routines --triggers --events --hex-blob \
	--databases opensvc pdns | gzip > "$DUMP_DIR/.$NAME"
mv "$DUMP_DIR/.$NAME" "$DUMP_DIR/$NAME"

cd "$DUMP_DIR"
for old in $(ls -1t oc3.*.sql.gz | tail -n +$((DUMP_RETENTION + 1))); do
	echo "removing $old"
	rm -f "$old"
done
ls -lt oc3.*.sql.gz

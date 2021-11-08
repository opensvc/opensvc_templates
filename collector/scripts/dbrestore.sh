#!/bin/bash

echo "== entering database restore procedure =="

DUMP_DIR="/dbdumps"
EXPORTFNAME="${EXPORTFNAME:-${DUMP_DIR}/restore.me.tar.gz}"
MYSQL_OPTS=${MYSQL_OPTS:-}
PATH_SCRIPT="/scripts"
LATEST_DIR=${DUMP_DIR}/latest
TIMESTAMP=$(date --utc +%Y%m%d%H%M%S)
MYSQLRESTORE="mysql -h 127.0.0.1 ${MYSQL_OPTS} --batch -u root -p$MYSQL_ROOT_PASSWORD --database=opensvc"

[[ ! -f "${EXPORTFNAME}" ]] && {
	echo "File ${EXPORTFNAME} not found"
	echo "Please make sure that ${EXPORTFNAME} is present"
	exit 1
}

echo "Restoring Database dump"

[[ -d ${DUMP_DIR}/restore ]] && rm -rf ${DUMP_DIR}/restore
mkdir -p ${DUMP_DIR}/restore

cd ${DUMP_DIR}/restore && {
	echo "   unarchiving ${EXPORTFNAME} in ${DUMP_DIR}/restore"
	tar xzf ${EXPORTFNAME} || exit 1
	DUMPFOLDER=$(ls -1)
	cd ${DUMPFOLDER}
	echo "   restore schema.dump"
	${MYSQLRESTORE} < schema.dump || exit 1
	for file in $(ls -1 *.dump | grep -v "^schema.dump$")
	do
		echo "   restore file $file"
		${MYSQLRESTORE} < $file || exit 1
	done
}
rm -rf ${DUMP_DIR}/restore
echo "Done"

#!/bin/bash

TIMESTAMP=$(date --utc +%Y%m%d%H%M%S)
BCK_DIR=/backup
PGDA_DIR=${BCK_DIR}/pg_dumpall.${TIMESTAMP}

function recursive_delete()
{
	DIR=$1
	[[ ! -d ${DIR} ]] && {
		echo "${DIR} is not a directory. Exiting"
	}
	echo "Deleting folder ${DIR}"
	rm -rf ${DIR} || {
		echo "There was an error while trying to delete ${DIR}"
		exit 1
	}
	exit 0
}

export -f recursive_delete

mkdir -p ${PGDA_DIR}
cd ${PGDA_DIR} && {
    pg_dumpall --verbose --no-password -U ${POSTGRES_USER} -h localhost -p 5432 --clean --if-exists --file=${PGDA_DIR}/pg_dumpall.${TIMESTAMP}.sql || exit 1

    # remove drop role, we are using it when we reload the database
    # do not create an already existing role
    sed -i '/^DROP ROLE IF EXISTS postgres/s/^/#/;/^CREATE ROLE postgres/s/^/#/' ${PGDA_DIR}/pg_dumpall.${TIMESTAMP}.sql

}

cd $BCK_DIR && {
    find ${BCK_DIR} -type d -name 'pg_dumpall*' -mtime +3 | xargs -n1 -I {} bash -c 'recursive_delete "{}"'
}

exit 0

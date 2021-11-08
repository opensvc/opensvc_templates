#!/bin/bash

echo "== starting database dump =="

DUMP_DIR="/dbdumps"
PATH_SCRIPT="/scripts"
LATEST_DIR=${DUMP_DIR}/latest
TIMESTAMP=$(date --utc +%Y%m%d%H%M%S)
MYSQLDUMP="mysqldump -h 127.0.0.1 -u root -p$MYSQL_ROOT_PASSWORD --hex-blob"
DUMP_RETENTION=${DUMP_RETENTION:-7}

[[ -d ${LATEST_DIR} ]] && rm -rf ${LATEST_DIR}
mkdir -p ${LATEST_DIR}

echo >$LATEST_DIR/schema.dump
cat - <<EOF >> $LATEST_DIR/schema.dump
create user if not exists opensvc@127.0.0.1 identified by 'opensvc';
create user if not exists pdns@127.0.0.1 identified by 'pdns';
create user if not exists readonly@127.0.0.1 identified by 'readonly';
EOF

# dump schema
echo "== dumping database schema =="
$MYSQLDUMP --no-data --routines --databases opensvc pdns | sed -e "s/SECURITY DEFINER/SECURITY INVOKER/" >> $LATEST_DIR/schema.dump

typeset -i total=$(wc -l $PATH_SCRIPT/dbdump.tables | awk '{print $1}')
typeset -i cpt=0
for t in $(grep -v "^#" $PATH_SCRIPT/dbdump.tables)
do
	echo "== dumping table $t =="
	$MYSQLDUMP opensvc $t >> $LATEST_DIR/$t.dump
	let cpt=$cpt+1
done

echo "== total tables: $total     dumped tables: $cpt =="

cd ${DUMP_DIR} && {
    TARBASE="opensvc.dump.${TIMESTAMP}"
    TARFILE="${TARBASE}.tar.gz"
    mv ${LATEST_DIR} ${TARBASE}
    echo "== creating tar archive ${TARFILE} =="
    tar czf ${TARFILE} ${TARBASE} && rm -rf ${TARBASE}
}

echo "== cleaning old tar archives (keeping last ${DUMP_RETENTION} files) =="
cd ${DUMP_DIR} && {
        echo "--> before cleanup <--"
	ls -1rt opensvc.dump.*
	echo
        for file in $(ls -1rt opensvc.dump.*.tar.gz | head -n -${DUMP_RETENTION})
	do
            echo "== deleting file ${file} =="
	    rm -f ${file}
	    echo
	done
        echo "--> after cleanup <--"
	ls -1rt opensvc.dump.*
}
echo "done."


#!/bin/sh
# Run once by the mariadb container, when it creates the database, after
# 01-schema.sql and 02-data.sql: the schema creates the opensvc user with a
# default password, made here the one of the sec, with the rights oc3 needs.
set -e
mariadb -uroot -p"${MARIADB_ROOT_PASSWORD}" <<SQL
CREATE USER IF NOT EXISTS 'opensvc'@'127.0.0.1' IDENTIFIED BY '${OC3_DB_PASSWORD}';
ALTER USER 'opensvc'@'127.0.0.1' IDENTIFIED BY '${OC3_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON opensvc.* TO 'opensvc'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

#!/usr/bin/env bash

set -x  # Start debug mode

PG_MAJOR=15
PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin
POSTGRES_PASSWORD=postgres
PGDATA=/var/lib/postgresql/$PG_MAJOR/main

cp /etc/postgresql/$PG_MAJOR/main/postgresql.conf /var/lib/postgresql/$PG_MAJOR/main/postgresql.conf
cp -r /etc/postgresql/$PG_MAJOR/main/conf.d /var/lib/postgresql/$PG_MAJOR/main/conf.d
cp /etc/postgresql/$PG_MAJOR/main/pg_hba.conf /var/lib/postgresql/$PG_MAJOR/main/pg_hba.conf

ls /etc/postgresql/$PG_MAJOR/main/
ls /var/lib/postgresql/$PG_MAJOR/main/

#/bin/sh -c 
/usr/local/bin/docker-entrypoint.sh "$@"

echo "###done###"

exit 0

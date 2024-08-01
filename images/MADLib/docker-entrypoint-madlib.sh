#!/usr/bin/env bash

# set -x  # Start debug mode

PG_MAJOR=15
PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin
POSTGRES_PASSWORD=postgres
PGDATA=/var/lib/postgresql/data
export PGDATA=/var/lib/postgresql/data

### init volume
mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 1777 "$PGDATA"
mkdir -p /docker-entrypoint-initdb.d
chown postgres:postgres /docker-entrypoint-initdb.d
/usr/local/bin/docker-ensure-initdb.sh "$@"

##############################
### copy configs to new volume
##############################

cp /etc/postgresql/$PG_MAJOR/main/postgresql.conf $PGDATA/postgresql.conf
cp -r /etc/postgresql/$PG_MAJOR/main/conf.d $PGDATA/conf.d
cp /etc/postgresql/$PG_MAJOR/main/pg_hba.conf $PGDATA/pg_hba.conf
cp /etc/postgresql/$PG_MAJOR/main/postgresql.auto.conf $PGDATA/postgresql.auto.conf

##################################
### install MADLib into PostgreSQL
##################################

### start PostgreSQL
/etc/init.d/postgresql start

### install MADLib
su postgres -c "PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin; /apache-madlib-2.1.0-src/build/src/bin/madpack -s madlib -p postgres -c postgres/postgres@localhost:5432/postgres install"

### reset lib paths to default - this is necessary for Citus (preloaded shared libs)
su postgres -c "PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin; psql -h localhost -c 'ALTER SYSTEM SET dynamic_library_path = \"/usr/lib/postgresql/15/lib\"'"
su postgres -c "PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin; psql -h localhost -c 'select pg_reload_conf()'"

# MADLib changes DLL path to own subfolder (?)
# copy files to stay conform to PostgreSQL paths
cp /usr/lib/postgresql/15/lib/ /apache-madlib-2.1.0-src/build/src/../src/ports/postgres/15/ -r
cp /apache-madlib-2.1.0-src/build/src/../src/ports/postgres/15/ /usr/lib/postgresql/ -r
#RUN cp /apache-madlib-2.1.0-src/build/src/../src/ports/postgres/15/lib /usr/lib/postgresql/15/ -r
cp /apache-madlib-2.1.0-src/build/src/ports/postgres/15/extension/ /usr/share/postgresql/15/ -r

### stop PostgreSQL
/etc/init.d/postgresql stop

### PostgreSQL's official entrypoint
/usr/local/bin/docker-entrypoint.sh "$@"

# echo "###done###"
# ls -lh $PGDATA

exit 0

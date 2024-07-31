#!/usr/bin/env bash

# set -x  # Start debug mode

PG_MAJOR=15
PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin
POSTGRES_PASSWORD=postgres
PGDATA=/var/lib/postgresql/data
export PGDATA=/var/lib/postgresql/data

echo "###should be empty - new path###"

chown postgres:postgres $PGDATA

ls -lh /var/lib/postgresql/data

echo "###should be empty###"

ls -lh /var/lib/postgresql/$PG_MAJOR/main

echo "###should contain config###"

ls -lh /var/lib/postgresql/$PG_MAJOR/main

echo "###show df###"
df -hT /var/lib/postgresql/15/main

echo "###should contain more config###"
ls -lh /etc/postgresql/15/main/

# echo "###done###"
# ls /etc/postgresql/$PG_MAJOR/main/
# ls /var/lib/postgresql/$PG_MAJOR/main/

mkdir /docker-entrypoint-initdb.d

dpkg -l | grep postgresql


# ln -sT docker-ensure-initdb.sh /usr/local/bin/docker-enforce-initdb.sh
/usr/local/bin/docker-ensure-initdb.sh "$@"

cp /etc/postgresql/$PG_MAJOR/main/postgresql.conf $PGDATA/postgresql.conf
cp -r /etc/postgresql/$PG_MAJOR/main/conf.d $PGDATA/conf.d
cp /etc/postgresql/$PG_MAJOR/main/pg_hba.conf $PGDATA/pg_hba.conf

### install MADLib into PostgreSQL
/etc/init.d/postgresql start
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

/etc/init.d/postgresql stop

#/bin/sh -c 
/usr/local/bin/docker-entrypoint.sh "$@"

echo "###done###"

ls -lh /var/lib/postgresql/$PG_MAJOR/main

exit 0

######################################################################################
# Dockerfile for TPCx-AI supplements - PostgreSQL + MADLib
######################################################################################
#
# This Dockerfile builds an image for PostgreSQL + MADLib to run the workload of TPCx-AI.
#
# Base Image: ubuntu:22.04
#
# Author: Patrick K. Erdelt
# Email: patrick.erdelt@bht-berlin.de
# Date: 2024-05-26
# Version: 1.0
# Description: This container runs PostgreSQL 15 with MADLib installed. It also contains some extensions that are necessary or helpful for running the workload of TPCx-AI inside the DBMS.
# 
######################################################################################




###########################################
######### Start with clean Ubuntu #########
###########################################
FROM ubuntu:22.04


####################################################
######### Some meta data of the containers #########
####################################################
LABEL maintainer="Patrick K. Erdelt <patrick.erdelt@bht-berlin.de>"
LABEL version="1.0"
LABEL description="This container runs PostgreSQL 15 with MADLib installed. It also contains some extensions that are necessary or helpful for running the workload of TPCx-AI inside the DBMS."


################################################################################
######### Make port 5432 available to the world outside this container #########
################################################################################
EXPOSE 5432


#############################################
######### Set default configuration #########
#############################################
ENV PG_MAJOR 15
### fixed major revision
ENV PATH $PATH:/usr/lib/postgresql/$PG_MAJOR/bin
### password is fixed
ENV POSTGRES_PASSWORD postgres
### it's not /var/lib/postgresql/data
ENV PGDATA /var/lib/postgresql/data
### it's not /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data


######### Get some basic tools #########
RUN apt-get update -y
RUN apt-get install wget -y
RUN apt-get install nano locate -y
RUN apt-get install git -y


############################
######### Compiler #########
############################

RUN apt-get install build-essential libsqlite3-dev zlib1g-dev libncurses5-dev libgdbm-dev libbz2-dev libssl-dev libdb-dev -y

### compile cmake
RUN wget https://github.com/Kitware/CMake/releases/download/v3.21.1/cmake-3.21.1.tar.gz \
    && tar -zxvf cmake-3.21.1.tar.gz \
    && cd cmake-3.21.1 \
    && ./bootstrap \
    && make -j$(nproc) \
    && make install


##############################
######### PostgreSQL #########
##############################

### download PostgresQL
RUN apt install dirmngr ca-certificates software-properties-common apt-transport-https lsb-release curl -y
RUN curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /usr/share/keyrings/postgresql.gpg > /dev/null
RUN echo deb [arch=amd64,arm64,ppc64el signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main | tee /etc/apt/sources.list.d/postgresql.list

### update everything
RUN apt-get update -y
RUN apt-get upgrade -y

### run installer
RUN DEBIAN_FRONTEND=noninteractive apt install postgresql-client-$PG_MAJOR postgresql-$PG_MAJOR -y
### also install dev version
RUN apt-get install -y postgresql-server-dev-$PG_MAJOR

### listen to all hosts
RUN echo "listen_addresses = '*'\n" >> /etc/postgresql/$PG_MAJOR/main/postgresql.conf
RUN echo ' \n\
    # Database administrative login by Unix domain socket \n\
    local   all             all                                     trust \n\
    # TYPE  DATABASE        USER            ADDRESS                 METHOD \n\
    # "local" is for Unix domain socket connections only \n\
    local   all             all                                     trust \n\
    # IPv4 local connections: \n\
    host    all             all             127.0.0.1/32            trust \n\
    # IPv6 local connections: \n\
    host    all             all             ::1/128                 trust \n\
    # IPv4 all connections: \n\
    host    all             all             all                     trust \n\
' > /etc/postgresql/$PG_MAJOR/main/pg_hba.conf

RUN echo "data_directory = '/var/lib/postgresql/data'\n\
" >> /etc/postgresql/15/main/postgresql.conf

### install Python3 extension
RUN apt-get install postgresql-plpython3-$PG_MAJOR -y

### configure virtual environment for madlib
RUN apt install python3-pip python3.10-venv -y
RUN alias python=python3
RUN python3 -m venv madlib 
# pip install for madlib
RUN echo "pyyaml==6.0.1 \n\
    pyxb-x==1.2.6.1 \n\
    numpy==1.25.2 \n\
    dill==0.3.7 \n\
    grpcio==1.57.0 \n\
    protobuf==3.19.4 \n\
    hyperopt==0.2.5 \n\
    tensorflow==2.10 \n\
    scikit-learn==1.3.0 \n\
    pandas==2.0.3 \n\
    xgboost==1.7.6 \n\
    scipy==1.11.2 \n\
    pgsanity \n\
" > requirements.txt
# pip install for TPCx-AI (note the >>)
RUN echo "librosa \n\
" >> requirements.txt

RUN source madlib/bin/activate ; pip install -r requirements.txt

### tell PostgreSQL where to find Python packages
RUN echo "PYTHONPATH='/madlib/lib/python3.10/site-packages/'\n" >> /etc/postgresql/$PG_MAJOR/main/environment



##########################
######### MADLib #########
##########################

RUN apt-get install m4 -y

### download and compile MADLib
RUN wget https://dist.apache.org/repos/dist/release/madlib/2.1.0/apache-madlib-2.1.0-src.tar.gz \
    && tar -xf apache-madlib-2.1.0-src.tar.gz \
    && cd apache-madlib-2.1.0-src \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make -i -j$(nproc) \
    && make -j$(nproc) install
#    && make -j$(nproc) prefix=/usr/local install

### make sure all users can access all components
### TODO: Reduce to minimum requirements
RUN chmod -R 777 /apache-madlib-2.1.0-src

### install MADLib into PostgreSQL
#RUN su postgres -c "/etc/init.d/postgresql start; PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin; /apache-madlib-2.1.0-src/build/src/bin/madpack -s madlib -p postgres -c postgres/postgres@localhost:5432/postgres install"

### reset lib paths to default - this is necessary for Citus (preloaded shared libs)
#RUN su postgres -c "/etc/init.d/postgresql start; PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin; psql -h localhost -c 'ALTER SYSTEM SET dynamic_library_path = \"/usr/lib/postgresql/15/lib\"'"
#RUN su postgres -c "/etc/init.d/postgresql start; PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin; psql -h localhost -c 'select pg_reload_conf()'"

# MADLib changes DLL path to own subfolder (?)
# copy files to stay conform to PostgreSQL paths
#RUN cp /usr/lib/postgresql/15/lib/ /apache-madlib-2.1.0-src/build/src/../src/ports/postgres/15/ -r
#RUN cp /apache-madlib-2.1.0-src/build/src/../src/ports/postgres/15/ /usr/lib/postgresql/ -r
#RUN cp /apache-madlib-2.1.0-src/build/src/../src/ports/postgres/15/lib /usr/lib/postgresql/15/ -r
#RUN cp /apache-madlib-2.1.0-src/build/src/ports/postgres/15/extension/ /usr/share/postgresql/15/ -r



######################################
######### PostgreSQL Service #########
######################################

### mimick official scripts from https://github.com/docker-library/postgres/tree/master/$PG_MAJOR/bullseye

STOPSIGNAL SIGINT

### grab gosu for easy step-down from root
### https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.17
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates wget; \
    rm -rf /var/lib/apt/lists/*; \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
    apt-mark auto '.*' > /dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    chmod +x /usr/local/bin/gosu; \
    gosu --version; \
    gosu nobody true

RUN mkdir /docker-entrypoint-initdb.d
### TODO: is this still necessary?
#RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 1777 "$PGDATA"


#######################
### optionally pgvector
#######################
RUN cd /tmp ; git clone --branch v0.6.1 https://github.com/pgvector/pgvector.git ; cd pgvector ; make ; make install


##########################
### optionally TimescaleDB
##########################
# https://docs.timescale.com/self-hosted/latest/install/installation-linux/
RUN echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list
RUN wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg
RUN apt-get update -y
RUN apt-get install timescaledb-2-postgresql-$PG_MAJOR -y
# include TimescaleDB - if not included in Citus section
#RUN echo "shared_preload_libraries = '/usr/lib/postgresql/$PG_MAJOR/lib/timescaledb'" >> /etc/postgresql/$PG_MAJOR/main/postgresql.conf
#RUN echo "shared_preload_libraries = '/usr/lib/postgresql/$PG_MAJOR/lib/timescaledb'" >> /var/lib/postgresql/$PG_MAJOR/main/postgresql.conf


###################
### optionally PL/R
###################
# https://github.com/postgres-plr/plr/blob/master/install.md
### install R
# RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
RUN apt install r-base -y
### install extension
RUN apt-get install postgresql-$PG_MAJOR-plr
### tell PostgreSQL where to find R
RUN echo "R_HOME='/usr/lib/R' \n\
" >> /etc/postgresql/$PG_MAJOR/main/environment


######################
### optionally PostGIS
######################
# https://trac.osgeo.org/postgis/wiki/UsersWikiPostGIS3UbuntuPGSQLApt
RUN apt install postgresql-$PG_MAJOR-postgis-3 -y
RUN apt install postgis -y


####################
### optionally Citus
####################
# https://github.com/citusdata/citus?tab=readme-ov-file#getting-started
RUN curl https://install.citusdata.com/community/deb.sh | bash
RUN apt-get -y install postgresql-$PG_MAJOR-citus-12.1
# automatically change DLL includes
RUN pg_conftool /etc/postgresql/$PG_MAJOR/main/postgresql.conf set shared_preload_libraries citus,timescaledb
RUN pg_conftool /etc/postgresql/$PG_MAJOR/main/postgresql.conf set dynamic_library_path /usr/lib/postgresql/15/lib
# does not exist yet
#RUN pg_conftool /var/lib/postgresql/$PG_MAJOR/main/postgresql.conf set shared_preload_libraries citus

### copy config from /etc to /var/lib
#RUN cp /etc/postgresql/$PG_MAJOR/main/postgresql.conf /var/lib/postgresql/$PG_MAJOR/main/postgresql.conf
#RUN cp -r /etc/postgresql/$PG_MAJOR/main/conf.d /var/lib/postgresql/$PG_MAJOR/main/conf.d
#RUN cp /etc/postgresql/$PG_MAJOR/main/pg_hba.conf /var/lib/postgresql/$PG_MAJOR/main/pg_hba.conf

### official PostgreSQL scripts for Docker images
COPY docker-entrypoint.sh /usr/local/bin/
COPY docker-ensure-initdb.sh /usr/local/bin/
COPY docker-entrypoint-madlib.sh /usr/local/bin/

# Allow everything inside Docker container
RUN chmod -R 777 /usr/local/bin/docker-ensure-initdb.sh
RUN chmod -R 777 /usr/local/bin/docker-entrypoint.sh
RUN chmod -R 777 /usr/local/bin/docker-entrypoint-madlib.sh

WORKDIR /usr/local/bin/

### TODO: is this still necessary?
#RUN ln -sT docker-ensure-initdb.sh /usr/local/bin/docker-enforce-initdb.sh

# RUN apt-get remove postgresql-16 postgresql-16-postgis-3 postgresql-16-postgis-3-scripts -y

### container runs PostgreSQL as service
#ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-madlib.sh"]
CMD ["postgres"]

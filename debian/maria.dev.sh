#!/usr/bin/env bash

DBVER=${DBVER:-10.6}

apt-get install software-properties-common dirmngr
apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'

tee /etc/apt/sources.list.d/mariadb.list <<EOF
deb [arch=amd64] http://mirror.mephi.ru/mariadb/repo/$DBVER/debian $(lsb_release -cs) main
deb-src http://mirror.mephi.ru/mariadb/repo/$DBVER/debian $(lsb_release -cs) main
EOF

cat <<EOF > /root/.my.cnf
[client]
  host     = localhost
  user     = root
  password = localroot
EOF

cp /root/.my.cnf /home/$USER/
chown $USER:$USER /home/$USER/.my.cnf
apt-get install -yq --no-install-recommends  mariadb-server=1:$DBVER* mariadb-client=1:$DBVER* libmariadb-dev=1:$DBVER*

mysql --user=root <<_EOF_
    DELETE FROM mysql.user WHERE User='';
    DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    SET password = PASSWORD('localroot');
    FLUSH PRIVILEGES;
_EOF_

cat <<EOF > /etc/mysql/mariadb.conf.d/72-my.cnf
    [mysqld]
    max_connections = 20

    aria_pagecache_buffer_size = 1M
    key_buffer_size = 1M

    innodb_buffer_pool_size = 80M
    innodb_log_file_size    = 20M
EOF

service mysql restart
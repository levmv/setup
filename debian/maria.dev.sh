#!/usr/bin/env bash

DBVER=${DBVER:-10.6}

curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="mariadb-$DBVER" --skip-maxscale
apt update

cat <<EOF > /root/.my.cnf
[client]
  host     = localhost
  user     = root
  password = localroot
EOF

cp /root/.my.cnf /home/$MAIN_USER/
chown $MAIN_USER:$MAIN_USER /home/$MAIN_USER/.my.cnf
apt-get install -y mariadb-server=1:$DBVER* mariadb-client=1:$DBVER* libmariadb-dev=1:$DBVER*

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
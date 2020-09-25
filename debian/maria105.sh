#!/usr/bin/env bash

export DEBIAN_FRONTEND="noninteractive"

MYSQLROOTPASS=`openssl rand -base64 32 | tr -d /=+`
MYSQLBACKUPPASS=`openssl rand -base64 32 | tr -d /=+`

cat <<EOF > /root/.my.cnf
[client]
host     = localhost
user     = root
password = $MYSQLROOTPASS

[mysqldump]
user=backupuser
password=$MYSQLBACKUPPASS
EOF


apt-get install software-properties-common dirmngr
apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'


echo "deb http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" \

tee /etc/apt/sources.list.d/mariadb.list <<EOF
deb [arch=amd64] http://mirror.mephi.ru/mariadb/repo/10.5/debian $(lsb_release -cs) main
deb-src http://mirror.mephi.ru/mariadb/repo/10.5/debian $(lsb_release -cs) main
EOF

apt-get update

apt-get install -y mariadb-server=1:10.5* mariadb-client=1:10.5* libmariadb-dev=1:10.5*

mysql --user=root <<_EOF_
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  SET password = PASSWORD('$MYSQLROOTPASS');
  GRANT LOCK TABLES, SELECT ON *.* TO 'backupuser'@'127.0.0.1' IDENTIFIED BY '$MYSQLBACKUPPASS';

  FLUSH PRIVILEGES;
_EOF_

cat <<EOF > /etc/mysql/mariadb.conf.d/72-my.cnf
[mysqld]
max_connections = 20

aria_pagecache_buffer_size = 1M
key_buffer_size = 1M

innodb_buffer_pool_size = 100M
innodb_log_file_size    = 25M
EOF

service mysql restart

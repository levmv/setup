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

add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://ams2.mirrors.digitalocean.com/mariadb/repo/10.6/debian bullseye main'

apt-get update

apt-get install -y mariadb-server=1:10.6* mariadb-client=1:10.6* libmariadb-dev=1:10.6*

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

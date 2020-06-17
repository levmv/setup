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


apt-get install software-properties-common mariadb-devel
add-apt-repository 'deb [arch=amd64] http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.4/debian buster main'

apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8

apt update

debconf-set-selections <<< "mariadb-server-10.4 mysql-server/root_password password ${MYSQLROOTPASS}"
debconf-set-selections <<< "mariadb-server-10.4 mysql-server/root_password_again password ${MYSQLROOTPASS}"

apt-get install -y mariadb-server mariadb-client

mysql --user=root -p$MYSQLROOTPASS <<_EOF_
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

  GRANT LOCK TABLES, SELECT ON *.* TO 'backupuser'@'127.0.0.1' IDENTIFIED BY '$MYSQLBACKUPPASS';

  FLUSH PRIVILEGES;
_EOF_

cat <<EOF > /etc/mysql/conf.d/my.cnf
[mysqld]
max_connections = 30

aria_pagecache_buffer_size = 1M
key_buffer_size = 1M

innodb_buffer_pool_size = 512M
innodb_buffer_pool_instances = 1
innodb_log_file_size    = 60M
EOF

service mysql restart

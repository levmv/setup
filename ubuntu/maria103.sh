#!/usr/bin/env bash

export DEBIAN_FRONTEND="noninteractive"

curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

sudo apt-get install software-properties-common
sudo add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.3/ubuntu bionic main'

sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8

sudo apt update

debconf-set-selections <<< "mysql-server mysql-server/root_password password ${MYSQLROOTPASS}"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${MYSQLROOTPASS}"

sudo apt-get install mariadb-server mariadb-client

mysql --user=root -p$MYSQLROOTPASS <<_EOF_
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  FLUSH PRIVILEGES;
_EOF_


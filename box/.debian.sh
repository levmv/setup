
# We use vagrant name for compatible with old configs written for vagrant
BOXUSER="vagrant"

useradd $BOXUSER -d /home/$BOXUSER -m -s /bin/bash
echo $BOXUSER:$BOXUSER | chpasswd

groupmod -g 1001 vagrant

#mkdir /home/$BOXUSER/.ssh/
#cp id_rsa /home/$BOXUSER/.ssh/
#cp id_rsa.pub /home/$BOXUSER/.ssh/
#cp id_rsa.pub /home/$BOXUSER/.ssh/authorized_keys

#chmod 700 /home/$BOXUSER/.ssh
#chmod 600 /home/$BOXUSER/.ssh/id_rsa
#chmod 644 /home/$BOXUSER/.ssh/id_rsa.pub
#chown -R $BOXUSER.$BOXUSER /home/$BOXUSER/.ssh



apt-get update
apt-get install -y software-properties-common build-essential apt-transport-https \
                   debconf-utils gnupg2 ca-certificates lsb-release \
                   git zip unzip curl wget vim nano sudo tmux figlet procps htop apt-file \
                   openssh-server iproute2 iputils-ping dnsutils

usermod -aG sudo $BOXUSER

ln -s /media/dev /home/$BOXUSER/dev

#rm .set.sh id_rsa id_rsa.pub

export DEBIAN_FRONTEND="noninteractive"

localectl set-locale LANG=ru_RU.UTF-8 LC_MESSAGES=en_US.UTF-8
timedatectl set-timezone Europe/Moscow

sed -i -e '/#SystemMaxUse=/s/#SystemMaxUse=/SystemMaxUse=200M/g' /etc/systemd/journald.conf
systemctl restart systemd-journald

# Apt sources:
# nginx
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" \
    | sudo tee /etc/apt/sources.list.d/nginx.list

echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | sudo tee /etc/apt/preferences.d/99nginx

# php
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php8.0.list

# mariadb
curl -LsSO https://mariadb.org/mariadb_release_signing_key.asc
chmod -c 644 mariadb_release_signing_key.asc
mv -vi mariadb_release_signing_key.asc /etc/apt/trusted.gpg.d/ # FIXME

add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://ams2.mirrors.digitalocean.com/mariadb/repo/10.6/debian bullseye main'

#node
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -

# yarn
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | tee /etc/apt/sources.list.d/yarn.list


apt-get update

apt-get install -y nginx

mkdir -p /etc/nginx/sites

cat <<EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    server_tokens off;
    charset utf-8;

    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    access_log  /var/log/nginx/access.log;

    sendfile on;
    tcp_nopush on;

    keepalive_timeout   100;
    keepalive_requests  200;

    client_body_timeout 35s;
    client_header_timeout 15s;

    reset_timedout_connection on;

    gzip on;
    gzip_min_length 500;
    gzip_proxied any;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript image/svg+xml;
    gzip_comp_level 2;

    include /etc/nginx/sites/*;
}
EOF

service nginx restart

apt install -y php8.0-{fpm,dev,gd,curl,apcu,intl,xml,zip,mbstring,mysql} php-pear

php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '756890a4488ce9024fc62c56153228907f1545c228516cbf63f885e036d37e9a59d27d63f46af1d4d07ee0f76181c7d3') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"

mv composer.phar /usr/local/bin/composer


cat <<EOF > /etc/php/8.0/fpm/conf.d/30-xcvb.ini
memory_limit = 128M
upload_max_filesize = 15M
post_max_size = 15M
realpath_cache_size = 128k
realpath_cache_ttl =  3600
expose_php = Off
session.use_strict_mode = 1
opcache.interned_strings_buffer=4
zend.assertions = 1

date.timezone = 'Europe/Moscow'
mysqlnd.collect_statistics = Off
session.cookie_samesite = Lax
EOF

cat <<EOF > /etc/php/8.0/cli/conf.d/30-xcvb.ini
date.timezone = 'Europe/Moscow'
EOF

exit

cat <<EOF > /root/.my.cnf
[client]
host     = localhost
user     = root
password = localroot
EOF
cp /root/.my.cnf /home/$BOXUSER/
chown $BOXUSER:$BOXUSER /home/$BOXUSER/.my.cnf
apt-get install -y mariadb-server=1:10.6* mariadb-client=1:10.6* libmariadb-dev=1:10.6*

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

innodb_buffer_pool_size = 1GB
innodb_log_file_size    = 96M
EOF

service mysql restart


apt install -y nodejs yarn

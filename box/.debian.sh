
# We use vagrant name for compatible with old configs written for vagrant
BOXUSER="vagrant"

useradd $BOXUSER -d /home/$BOXUSER -m -s /bin/bash
echo $BOXUSER:$BOXUSER | chpasswd

mkdir /home/$BOXUSER/.ssh/
cp id_rsa /home/$BOXUSER/.ssh/
cp id_rsa.pub /home/$BOXUSER/.ssh/
cp id_rsa.pub /home/$BOXUSER/.ssh/authorized_keys

chmod 700 /home/$BOXUSER/.ssh
chmod 600 /home/$BOXUSER/.ssh/id_rsa
chmod 644 /home/$BOXUSER/.ssh/id_rsa.pub
chown -R $BOXUSER.$BOXUSER /home/$BOXUSER/.ssh


apt-get update
apt-get install -y software-properties-common build-essential apt-transport-https \
                   debconf-utils gnupg2 ca-certificates lsb-release \
                   git zip unzip curl wget vim nano sudo tmux figlet procps htop apt-file \
                   openssh-server iproute2 iputils-ping dnsutils

usermod -aG sudo $BOXUSER

ln -s /media/dev /home/$BOXUSER/dev

rm .set.sh id_rsa id_rsa.pub

export DEBIAN_FRONTEND="noninteractive"

sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i -e 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
echo 'LANG="ru_RU.UTF-8"' | tee /etc/default/locale > /dev/null
dpkg-reconfigure --frontend=noninteractive locales
update-locale LANG=ru_RU.UTF-8
echo 'Europe/Moscow' | tee /etc/timezone > /dev/null
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

sed -i 's/#FallbackNTP/FallbackNTP/' /etc/systemd/timesyncd.conf
systemctl enable systemd-timesyncd.service && systemctl start systemd-timesyncd.service

sed -i -e '/#SystemMaxUse=/s/#SystemMaxUse=/SystemMaxUse=200M/g' /etc/systemd/journald.conf


# Apt sources:
# nginx
echo "deb http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" \
    | tee /etc/apt/sources.list.d/nginx.list
curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -

# php
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php7.3.list

# mariadb
add-apt-repository 'deb [arch=amd64] http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.4/debian buster main'
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8

# yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

apt-get update


apt-get install -y nginx

mkdir /etc/nginx/sites

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

apt-get install -y php7.3 php7.3-fpm php7.3-dev php7.3-gd php7.3-curl php-pear \
                php-apcu php7.3-intl php7.3-xml php7.3-zip php7.3-mbstring php7.3-mysql

EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('SHA384', 'composer-setup.php');")"

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]
then
    >&2 echo 'ERROR: Invalid installer signature'
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet
mv composer.phar /usr/local/bin/composer
rm composer-setup.php

sed -i 's/memory_limit = .*/memory_limit = '128M'/' /etc/php/7.3/fpm/php.ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = '15M'/' /etc/php/7.3/fpm/php.ini
sed -i 's/post_max_size = .*/post_max_size = '15M'/' /etc/php/7.3/fpm/php.ini
sed -i 's/;realpath_cache_size\s=.*/realpath_cache_size = '128k'/' /etc/php/7.3/fpm/php.ini
sed -i -E 's/;?expose_php = .*/expose_php = Off/' /etc/php/7.3/fpm/php.ini
sed -i -E 's/;?session.use_strict_mode\s=.*/session.use_strict_mode = 1/' /etc/php/7.3/fpm/php.ini
sed -i -E 's/;?date.timezone =/date.timezone = 'Europe\\/Moscow'/' /etc/php/7.3/fpm/php.ini
sed -i -E 's/;?date.timezone =/date.timezone = 'Europe\\/Moscow'/' /etc/php/7.3/cli/php.ini


cat <<EOF > /root/.my.cnf
[client]
host     = localhost
user     = root
password = localroot
EOF
cp /root/.my.cnf /home/$BOXUSER/
chown $BOXUSER:$BOXUSER /home/$BOXUSER/.my.cnf

#debconf-set-selections <<< "mariadb-server-10.4 mysql-server/root_password password localroot"
#debconf-set-selections <<< "mariadb-server-10.4 mysql-server/root_password_again password localroot"

apt-get install -y mariadb-server mariadb-client

mysql --user=root <<_EOF_

  UPDATE mysql.global_priv SET priv=json_set(priv, '$.plugin', 'mysql_native_password', '$.authentication_string', PASSWORD('localroot')) WHERE User='root';

  DELETE FROM mysql.global_priv WHERE User='';
  DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

  FLUSH PRIVILEGES;
_EOF_

cat <<EOF > /etc/mysql/conf.d/my.cnf
[mysqld]
max_connections = 30

key_buffer_size = 1M

innodb_buffer_pool_size = 1G
innodb_buffer_pool_instances = 1
innodb_log_file_size    = 96M
EOF

service mysql restart

curl -sL https://deb.nodesource.com/setup_12.x | bash -
apt-get install -y nodejs yarn

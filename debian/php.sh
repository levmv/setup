#!/usr/bin/env bash

wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php8.0.list

apt update
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
opcache.memory_consumption = 42
opcache.validate_timestamps = 0
opcache.enable_file_override = 1
opcache.save_comments = 0
opcache.interned_strings_buffer=4

date.timezone = 'Europe/Moscow'
mysqlnd.collect_statistics = Off
session.cookie_samesite = Lax
EOF

cat <<EOF > /etc/php/8.0/cli/conf.d/30-xcvb.ini
date.timezone = 'Europe/Moscow'
EOF

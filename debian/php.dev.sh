#!/usr/bin/env bash

wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php8.1.list

apt update
apt install -y php8.1-{fpm,dev,gd,curl,apcu,intl,xml,zip,mbstring,mysql} php-pear

EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]
then
    >&2 echo 'ERROR: Invalid installer checksum'
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet
rm composer-setup.php

mv composer.phar /usr/local/bin/composer

cat <<EOF > /etc/php/8.1/fpm/conf.d/30-xcvb.ini
memory_limit = 128M
upload_max_filesize = 25M
post_max_size = 25M
realpath_cache_size = 256k
realpath_cache_ttl =  3600
expose_php = Off
session.use_strict_mode = 1
zend.assertions = 1
date.timezone = 'Europe/Moscow'
session.cookie_samesite = Lax
EOF

cat <<EOF > /etc/php/8.1/cli/conf.d/30-xcvb.ini
date.timezone = 'Europe/Moscow'
EOF

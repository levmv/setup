#!/usr/bin/env bash

VER="8.2"
sudo apt install -yq --no-install-recommends php$VER-{fpm,dev,gd,curl,apcu,intl,xml,zip,mbstring,mysql} libffi-dev

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

cat <<EOF > /etc/php/$VER/fpm/conf.d/30-xcvb.ini
memory_limit = 128M
upload_max_filesize = 25M
post_max_size = 25M
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

cat <<EOF > /etc/php/$VER/cli/conf.d/30-xcvb.ini
date.timezone = 'Europe/Moscow'
EOF

echo "ffi.enable = true" >> /etc/php/$VER/cli/conf.d/20-ffi.ini
echo "ffi.enable = true" >> /etc/php/$VER/fpm/conf.d/20-ffi.ini
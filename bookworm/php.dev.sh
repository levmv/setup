#!/usr/bin/env bash
set -euxo pipefail

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
error_reporting = E_ALL
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

cat <<EOF > /etc/php/$VER/cli/conf.d/30-xcvb.ini
date.timezone = 'Europe/Moscow'
EOF

echo "ffi.enable = true" >> /etc/php/$VER/cli/conf.d/20-ffi.ini
echo "ffi.enable = true" >> /etc/php/$VER/fpm/conf.d/20-ffi.ini

service php$VER-fpm reload

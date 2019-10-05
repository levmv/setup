#!/usr/bin/env bash

apt -y install lsb-release apt-transport-https ca-certificates
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php7.3.list

apt install -y php7.3 php7.3-fpm php7.3-dev php7.3-gd php7.3-curl php-pear \
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
sed -i 's/upload_max_filesize = .*/upload_max_filesize = '10M'/' /etc/php/7.3/fpm/php.ini
sed -i 's/post_max_size = .*/post_max_size = '10M'/' /etc/php/7.3/fpm/php.ini
sed -i 's/;realpath_cache_size\s=.*/realpath_cache_size = '128k'/' /etc/php/7.3/fpm/php.ini
sed -i 's/;realpath_cache_ttl\s=.*/realpath_cache_ttl = '3600'/' /etc/php/7.3/fpm/php.ini
sed -i -E 's/;?expose_php = .*/expose_php = Off/' /etc/php/7.3/fpm/php.ini
sed -i -E 's/;?session.use_strict_mode\s=.*/session.use_strict_mode = 1/' /etc/php/7.3/fpm/php.ini
sed -i -E 's/;?opcache.memory_consumption\s=.*/opcache.memory_consumption = 64/' /etc/php/7.3/fpm/php.ini
sed -i -E 's/;?opcache.validate_timestamps\s=.*/opcache.validate_timestamps = 0/' /etc/php/7.3/fpm/php.ini
sed -i -E 's/;?opcache.save_comments\s*=.*/opcache.save_comments = 0/' /etc/php/7.3/fpm/php.ini
sed -i -E 's/;?date.timezone =/date.timezone = 'Europe\\/Moscow'/' /etc/php/7.3/fpm/php.ini
sed -i -E 's/;?date.timezone =/date.timezone = 'Europe\\/Moscow'/' /etc/php/7.3/cli/php.ini

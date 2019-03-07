#!/usr/bin/env bash

sudo add-apt-repository ppa:ondrej/php
sudo apt-get update
sudo apt-get install -y php7.3 php7.3-fpm php7.3-dev php7.3-gd php7.3-curl php-pear \
                php-apcu php7.3-intl php7.3-xml php7.3-zip php7.3-mbstring php7.3-mysql

# some tuning:

sudo sed -i 's/memory_limit = .*/memory_limit = '128M'/' /etc/php/7.3/fpm/php.ini
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = '50M'/' /etc/php/7.3/fpm/php.ini
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = '50M'/' /etc/php/7.3/fpm/php.ini
sudo sed -i 's/;realpath_cache_size\s=.*/realpath_cache_size = '512k'/' /etc/php/7.3/fpm/php.ini
sudo sed -i 's/;date.timezone =/date.timezone = 'Europe\\/Moscow'/' /etc/php/7.3/fpm/php.ini
sudo sed -i 's/;date.timezone =/date.timezone = 'Europe\\/Moscow'/' /etc/php/7.3/cli/php.ini

# Composer

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
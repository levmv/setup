#!/usr/bin/env bash

TMPDEPS="libglib2.0-dev libwebp-dev libjpeg62-turbo-dev libexpat1-dev libexif-dev libpng-dev \
                                liblcms2-dev libmagickcore-dev libtiff5-dev libpoppler-glib-dev libopenslide-dev \
                                libpango1.0-dev liborc-0.4-dev libheif-dev"

sudo apt-get install -y automake build-essential php8.1-dev  php-pear $TMPDEPS

wget -qO- https://github.com/libvips/libvips/releases/download/v8.13.0/vips-8.13.0.tar.gz | tar zxv
cd ./vips-*


FLAGS="-O2 -march=native -ffast-math -ftree-vectorize"
CFLAGS="$FLAGS" CXXFLAGS="$FLAGS -D_GLIBCXX_USE_CXX11_ABI=0" ./configure --disable-debug --disable-static \
                                                  --disable-introspection --disable-dependency-tracking \
                                                  --without-rsvg
make
sudo make install
ldconfig

yes | sudo pecl install vips

for php_ini in $( sudo find /etc -type f -iname 'php*.ini' ); do
    php_conf="$( dirname "$php_ini" )/conf.d"
    echo "extension=vips.so" | sudo tee "$php_conf/20-vips.ini" >/dev/null
done

sudo apt remove $TMPDEPS
#!/usr/bin/env bash

VER="8.13.2"

sudo apt-get install -y automake build-essential php-pear php8.1-dev  libglib2.0-dev  libwebp-dev libjpeg62-turbo-dev \
                        libexpat1-dev libexif-dev libpng-dev liblcms2-dev libmagickcore-dev libtiff5-dev \
                        libpoppler-glib-dev libopenslide-dev libpango1.0-dev liborc-0.4-dev libheif-dev

wget -qO- https://github.com/libvips/libvips/releases/download/v$VER/vips-$VER.tar.gz | tar zxv

pushd ./vips-$VER

FLAGS="-O2 -march=native -ffast-math -ftree-vectorize"
CFLAGS="$FLAGS" CXXFLAGS="$FLAGS -D_GLIBCXX_USE_CXX11_ABI=0" ./configure --disable-debug --disable-static \
                                                  --disable-introspection --disable-dependency-tracking \
                                                  --without-rsvg
make
sudo make install
ldconfig

yes | sudo pecl install vips || true
for php_ini in $( sudo find /etc/php -type f -iname 'php*.ini' ); do
  php_conf="$( dirname "$php_ini" )/conf.d"
  echo "extension=vips.so" | sudo tee "$php_conf/20-vips.ini" >/dev/null
done

popd
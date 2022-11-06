#!/usr/bin/env bash

VER="8.13.3"

sudo apt-get install -y meson automake build-essential libglib2.0-dev libwebp-dev libjpeg62-turbo-dev \
                        libexpat1-dev libexif-dev libpng-dev liblcms2-dev libmagickcore-dev libtiff5-dev \
                        libpoppler-glib-dev libpango1.0-dev liborc-0.4-dev libheif-dev libffi-dev
# libopenslide-dev
#fftw3?
#libspng?
wget -qO- https://github.com/libvips/libvips/releases/download/v$VER/vips-$VER.tar.gz | tar zxv

pushd ./vips-$VER


#FLAGS="-O2 -march=native -ffast-math -ftree-vectorize -z,nodelete"
#CFLAGS="$FLAGS" CXXFLAGS="$FLAGS -D_GLIBCXX_USE_CXX11_ABI=0" ./configure --disable-debug --disable-static \
#                                                  --disable-introspection --disable-dependency-tracking \
#                                                  --without-rsvg

LDFLAGS='-Wl,-z,nodelete' meson setup build --prefix=/usr --buildtype=release -Ddeprecated=false -Dintrospection=false
meson compile -C build
meson test -C build
sudo meson install -C build

#make
#sudo make install
#ldconfig

#yes | sudo pecl install vips || true
#for php_ini in $( sudo find /etc/php -type f -iname 'php*.ini' ); do
#  php_conf="$( dirname "$php_ini" )/conf.d"
#  echo "extension=vips.so" | sudo tee "$php_conf/20-vips.ini" >/dev/null
#done

popd

rm -rf ./vips-$VER

sudo service 'php*-fpm' reload
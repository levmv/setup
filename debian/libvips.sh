#!/usr/bin/env bash

VER="8.13.3"

sudo apt-get install -y meson automake build-essential libglib2.0-dev libwebp-dev libjpeg62-turbo-dev \
                        libexpat1-dev libexif-dev libpng-dev liblcms2-dev libmagickcore-dev libtiff5-dev \
                        libpoppler-glib-dev libpango1.0-dev liborc-0.4-dev libheif-dev
# libopenslide-dev
#fftw3?
#libspng?
wget -qO- https://github.com/libvips/libvips/releases/download/v$VER/vips-$VER.tar.gz | tar zxv

pushd ./vips-$VER


meson setup build --prefix=/usr/local --buildtype=release -Ddeprecated=false -Dintrospection=false
meson compile -C build
#meson test -C build
sudo meson install -C build
sudo ldconfig

popd

rm -rf ./vips-$VER

sudo service 'php*-fpm' reload
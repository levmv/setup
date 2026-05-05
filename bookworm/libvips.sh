#!/usr/bin/env bash
set -euxo pipefail

VER="8.14.5"

sudo apt-get install -yq meson automake build-essential libglib2.0-dev libwebp-dev libjpeg62-turbo-dev \
                        libexpat1-dev libexif-dev libpng-dev liblcms2-dev libmagickcore-dev \
                        libpoppler-glib-dev libpango1.0-dev libheif-dev liborc-0.4-dev
# Vdm? libtiff5-dev
#libopenslide-dev
#fftw3?
#libspng?
wget -O- https://github.com/libvips/libvips/releases/download/v$VER/vips-$VER.tar.xz | tar xJv

pushd ./vips-$VER


meson setup build --prefix=/usr/local --buildtype=release -Ddeprecated=false -Dintrospection=false
meson compile -C build
#meson test -C build
sudo meson install -C build
sudo ldconfig

popd

rm -rf ./vips-$VER

sudo service 'php*-fpm' reload
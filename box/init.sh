#!/usr/bin/env bash

lxc launch debian10 box

. limits.sh

lxc file push ~/.ssh/id_rsa box/root/
lxc file push ~/.ssh/id_rsa.pub box/root/
lxc file push ./.debian.sh box/root/
lxc file push -r ../debian/ box/root/

lxc exec box -- bash ".debian.sh"






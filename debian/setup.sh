#!/usr/bin/env bash

wget https://raw.githubusercontent.com/levmorozov/devops/master/debian/debian10.sh
wget https://raw.githubusercontent.com/levmorozov/devops/master/debian/nginx.sh
wget https://raw.githubusercontent.com/levmorozov/devops/master/debian/maria104.sh
wget https://raw.githubusercontent.com/levmorozov/devops/master/debian/php.sh
wget https://raw.githubusercontent.com/levmorozov/devops/master/debian/yarn.sh
wget https://raw.githubusercontent.com/levmorozov/devops/master/acme.sh
wget https://raw.githubusercontent.com/levmorozov/devops/master/dbdump.sh
wget https://raw.githubusercontent.com/levmorozov/devops/master/dbdump.sh


chmod +x *

./debian10.sh
./nginx.sh
./maria104.sh
./yarn.sh
./acme.sh

rm debian10.sh nginx.sh maria104.sh php.sh yarn.sh acme.sh

rm /etc/update-motd.d/*
wget -O /etc/update-motd.d/10-hostname https://raw.githubusercontent.com/levmorozov/devops/master/motd/10-hostname
wget -O /etc/update-motd.d/20-sysinfo https://raw.githubusercontent.com/levmorozov/devops/master/motd/20-sysinfo
rm /etc/motd
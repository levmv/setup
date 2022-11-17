#!/usr/bin/env bash

wget https://repo.manticoresearch.com/manticore-repo.noarch.deb
sudo dpkg -i manticore-repo.noarch.deb
sudo apt update

sudo apt install -yq manticore

wget -qO- https://repo.manticoresearch.com/repository/morphology/ru.pak.tgz  | sudo tar zxv -C /usr/share/manticore/
wget -qO- https://repo.manticoresearch.com/repository/morphology/en.pak.tgz  | sudo tar zxv -C /usr/share/manticore/

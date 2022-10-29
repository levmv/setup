#!/usr/bin/env bash

curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - &&\
apt-get install -y nodejs

corepack enable
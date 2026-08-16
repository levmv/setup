#!/usr/bin/env bash
set -euo pipefail

openssl ecparam -genkey -name prime256v1 -out caca.key
openssl req -x509 -new -SHA384 -nodes -key caca.key -days 3650 -out caca.crt -subj "/C=UF/O=United Federation of Planets/CN=HD26965b CA"

sudo install -d -m 755 /usr/local/share/ca-certificates
sudo install -m 644 caca.crt /usr/local/share/ca-certificates/caca.crt
sudo update-ca-certificates

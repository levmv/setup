#!/usr/bin/env bash

sudo apt install -y curl gnupg2 ca-certificates lsb-release
echo "deb http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" \
    | sudo tee /etc/apt/sources.list.d/nginx.list

curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -

sudo apt update
sudo apt install -y nginx

mkdir /etc/nginx/certs
mkdir /etc/nginx/sites

chown acme.www-data /etc/nginx/certs
chmod 710 /etc/nginx/certs

cat <<EOF > /etc/nginx/sites/00-default
server {
    server_name _;
    listen       80  default_server;
    return       444;
}

server {
    listen 443 ssl default_server;
    server_name _;
    ssl_certificate /etc/nginx/certs/nginx.crt;
    ssl_certificate_key /etc/nginx/certs/nginx.key;
    return       444;
}
EOF


openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes -keyout /etc/nginx/certs/nginx.key -out /etc/nginx/certs/nginx.crt -subj /CN=_

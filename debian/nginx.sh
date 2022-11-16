#!/usr/bin/env bash

curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" \
    | sudo tee /etc/apt/sources.list.d/nginx.list

echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | sudo tee /etc/apt/preferences.d/99nginx

apt update
apt install -y nginx

mkdir -p /etc/nginx/certs
mkdir -p /etc/nginx/sites

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes -keyout /etc/nginx/certs/nginx.key -out /etc/nginx/certs/nginx.crt -subj /CN=_

cat <<\EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
worker_rlimit_nofile 4096;
pcre_jit on;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  2048;
}

http {
    server_tokens off;
    charset utf-8;

    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    access_log  /var/log/nginx/access.log;

    sendfile on;
    tcp_nopush on;

    keepalive_timeout   90;
    keepalive_requests  150;

    client_body_timeout 20s;
    client_header_timeout 15s;
    send_timeout 10s;
    reset_timedout_connection on;

    client_max_body_size  25m;

    gzip on;
    gzip_min_length 500;
    gzip_proxied any;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript image/svg+xml;
    gzip_comp_level 2;

    server {
        listen 80  default_server;
        listen 443 ssl default_server;
        server_name _;
        ssl_certificate /etc/nginx/certs/nginx.crt;
        ssl_certificate_key /etc/nginx/certs/nginx.key;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
        return 444;
    }

    server {
        listen 80;
        server_name localhost;

        location /status_page {
            stub_status on;
            allow 127.0.0.1;
            deny all;
        }
    }

    include /etc/nginx/sites/*;
}
EOF

systemctl enable --now nginx
